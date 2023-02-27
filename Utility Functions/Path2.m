% This is a "Path2" class for defining paths on level-2 no-slip contact
% submanifolds for a rigid quadrupedal robot. It takes the initial 
% condition for the shape-space slice (2 dim), gait constraint vector field
% (2 dim), and integration time for the path to construct a Path2 object. 
% A subclass of "Gait2" is passed as a property.

classdef Path2 < RigidGeomQuad

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties (SetAccess = private)

        active_state         % the contact state that this path belongs to; an integer in the range (1, 6)
                             % the contact state ordering is as follows {12, 23, 34, 41, 13, 24}

        dz                   % Gait constraint based stratified panel dzij-- [A]*\Vec{d\phi}_{ij}

        dphi                 % Gait constraint vector field dphi_ij-- \Vec{dphi}_{ij}

        point_of_interest    % starting point to compute the path

        int_dirn             % direction to integrate the path along: +phi or -phi with scaling

        int_time             % Integration time in the backward and forward direction from the middle_path

        int_cond             % checks if the pof is on the path, beginning, or at the end of the path

        deadband_dutycycle   % period of time spent swinging in the sub-gait (0 <= val <= 1)
                             % path psi in submanifold + path to return to starting point through the nullspace of the submanifold

        scale_path_method    % method to scale the path about the "point_of_interest"-- this prop then scales the time vector for the closed length path
                             % and changes the ordering based on final time. Some examples include, 'accln', 'vel'

        initial_condition    % this is the starting point of the path

        open_trajectory      % configuration trajectory for the active path

        net_displacement     % the net displacement generated by open/closed trajectories

        closed_trajectory    % configuration trajectory for the whole path

        path_length          % length of the path

        path_active_color    % color of the trajectory based on the gait constraint color map

        path_inactive_color  % color of the trajectory during the deadband

        path_discretization  % number of points in the active contact state

    end

    methods
        
        % Constructor
        function [thisPath2] = Path2( ank, a, l, dzij, dphiij, strpt, t, dc, c, si, dirn )

            % Setup the requirements for the arguments
            arguments
                
                ank     (1, 1) double {mustBeGreaterThan(ank,0.1)}

                a       (1, 1) double {mustBeGreaterThan(a,0.1)}

                l       (1, 1) double {mustBeGreaterThan(l,0.1)}

                dzij    (3, 1) sym    {mustBeA(dzij, 'sym')}

                dphiij  (2, 1) sym    {mustBeA(dphiij, 'sym')}

                strpt   (1, 2) double {mustBeNumeric}

                t       (1, 2) double {mustBeNonnegative}

                dc      (1, 1) double {mustBeNonnegative, mustBeLessThanOrEqual(dc, 1)}

                c       (2, 3) double {mustBeLessThanOrEqual(c, 1)}

                si      (1, 1) double  {mustBePositive, mustBeLessThanOrEqual(si, 6)}

                dirn    (1, 1) int8   {mustBeLessThanOrEqual(dirn, 1), mustBeGreaterThanOrEqual(dirn, -1)}

            end

            % Get the arguments for a superclass constuctor
            if nargin == 11
                quadArgs = [ank, a, l];
            elseif nargin == 9
                quadArgs = ank;
            elseif nargin == 8
                quadArgs = [];
            else
                error('Error: Need 10, 8, or 7 arguments to create an object.');
            end

            % call the RigidGeometricQuadruped class' constructor
            thisPath2 = thisPath2@RigidGeomQuad(quadArgs);

            % assign the props
            thisPath2.dz = dzij;
            thisPath2.dphi = dphiij;
            thisPath2.point_of_interest = strpt;
            thisPath2.int_time = t;
            thisPath2.deadband_dutycycle = dc;
            thisPath2.path_active_color = c(1,:);
            thisPath2.path_inactive_color = c(2,:);
            thisPath2.active_state = si;
            thisPath2.int_dirn = dirn;

            % increment the number of objects
            Path2.SetGet_static(1);

        end
        
        
    end

    methods (Static)
        
        % static function to icnrement the number of objects
        function out = SetGet_static(~)
            
            persistent var

            if isempty(var)
                var = 0;
            end

            if nargin == 1

                var = var + 1;

            else

                out = var;

            end

        end

        % Compute the open_trajectory
        function compute_trajectory( thePath2, funcstr, dnum )
        
            % initialize the return container-- we shall return percentages (from 10% to 100%) of the generated full open_trajectory
            thePath2.open_trajectory = cell(1,10);
            thePath2.path_length = cell(1,10);
            
            % RigidGeometricQuadruped 's inherited props
            aa = thePath2.get_a; 
            ll = thePath2.get_l;
            
            % check if we want the integration condition
            if numel(thePath2.int_time(thePath2.int_time == 0)) ~= 2                 % make sure some path is needed
                if isempty(thePath2.int_time(thePath2.int_time == 0))                % if both paths are needed
                    cond = 0;                                           
                elseif find(thePath2.int_time == 0) == 1                             % if only the forward path is needed
                    cond = 1;
                elseif find(thePath2.int_time == 0) == 2                             % if only the backward path is needed
                    cond = -1;
                end
            else                                                                     % error if the integration time for both fwd and backward paths are zero.
                error('ERROR: The intergration time in both directions can''t be zero.');
            end
            thePath2.int_cond = cond; % updated the integration property
            
            % integrate the gait constraint ode to obtain the open-trajectory for the system.
            ai0 = thePath2.point_of_interest(1);  % initial conditions
            aj0 = thePath2.point_of_interest(2);

            % unpack the integration direction
            dirn = thePath2.int_dirn;
            
            % get the functions needed to integrate-- 'symbolic' datatype to 'matlabFunction' format
            eval(funcstr{1})
            DPHI = matlabFunction(dirn*thePath2.dphi, 'Vars', eval(funcstr{2})); % dirn chooses whether it will be positive or negative
            DQ = [cos(theta), -sin(theta),  0, 0, 0;
                  sin(theta), cos(theta),   0, 0, 0;
                  0,          0,            1, 0, 0;
                  0,          0,            0, 1, 0;
                  0,          0,            0, 0, 1]*[thePath2.dz; thePath2.dphi]*dirn;
            DQ = matlabFunction(DQ, 'Vars', eval(funcstr{3}));                     % configuration vector field

            % integrate
            switch cond
            
                case -1 % just backward path
            
                    t = linspace(0, thePath2.int_time(1), dnum); % backward-- get the start point of path
                    [~,qb] = ode45( @(t,y) -DPHI(t, aa, ll, y(1), y(2)), t, [ai0; aj0] );
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); qb(end,1); qb(end,2)] ); % forward to POF
                
                case 0 % both paths
            
                    t = linspace(0, thePath2.int_time(1), dnum); % backward-- get the start point of path
                    [~,qb] = ode45( @(t,y) -DPHI(t, aa, ll, y(1), y(2)), t, [ai0; aj0] );
                    t = linspace(0, sum(thePath2.int_time), dnum); % forward-- integrate the configuration
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); qb(end,1); qb(end,2)] );
            
                case 1 % just forward path
                    
                    t = linspace(0, thePath2.int_time(2), dnum); % just go forward from POF
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); ai0; aj0] );
            
            end
            
            % store the open configuration trajectory slice q(s)_ij for the full path
            thePath2.open_trajectory{10} = {tf(:)', qf(:,1)', qf(:,2)', qf(:,3)', qf(:,4)', qf(:,5)'}';
            % {x, y, \theta, \alpha_i, \alpha_j}
            % store the initial condition of the path
            thePath2.initial_condition = [thePath2.open_trajectory{10}{4}(1) thePath2.open_trajectory{10}{5}(1)];
            % compute the net displacement
            thePath2.net_displacement(:,10) = [qf(end,1), qf(end,2), qf(end,3)]';
            % store the closed trajectory
            thePath2.closed_trajectory{10} = thePath2.close_trajectory(thePath2.open_trajectory{10}, thePath2.deadband_dutycycle);
            % since the gait-constraint vector field has unit magnitude, the path length is just the final time of the path
            thePath2.path_length{10} = thePath2.open_trajectory{10}{1}(end);
            
            % compute multiples of 10% paths to add to the "open_trajectory" and "path_length" props
            for i = 1:numel(thePath2.open_trajectory)-1
                thePath2.open_trajectory{i} = thePath2.interpolated_open_trajectory(thePath2.open_trajectory{10}, i*0.1, cond, dnum); % compute the scaled path
                thePath2.net_displacement(:,i) = [thePath2.open_trajectory{i}{2}(end), thePath2.open_trajectory{i}{3}(end), thePath2.open_trajectory{i}{4}(end)]';
                thePath2.closed_trajectory{i} = thePath2.close_trajectory(thePath2.open_trajectory{i}, thePath2.deadband_dutycycle); % close it-- might not use this much
                thePath2.path_length{i} = thePath2.open_trajectory{i}{1}(end); % get the path length
            end

            % store the path discretization
            thePath2.path_discretization = dnum;
        
        end
        
        % This function computes different percentages of the open-trajectory by keeping "path_start" prop constant, and using interp1 with the spline method.
        function q_interp = interpolated_open_trajectory(fullPath2, p, cond, dnum)
            
            % unpack your open_trajectory
            t = fullPath2{1};
            x = fullPath2{2};
            y = fullPath2{3};
            theta = fullPath2{4};
            ai = fullPath2{5};
            aj = fullPath2{6};

            % get the limitng points
            switch cond

                case -1
                    
                    leftpt = numel(t) - floor(p*numel(t)); rightpt = numel(t);

                case  0

                    midpt = ceil(numel(t)/2);
                    leftpt = midpt - p*(midpt-1); rightpt = midpt + p*(midpt-1);

                case  1

                    leftpt = 1; rightpt = ceil(p*numel(t));
                    
            end

            % get the modified trajectory
            t_temp = t(leftpt:rightpt); t_temp = t_temp - t_temp(1);
            x_temp = x(leftpt:rightpt); x_temp = x_temp - x_temp(1);
            y_temp = y(leftpt:rightpt); y_temp = y_temp - y_temp(1);
            theta_temp = theta(leftpt:rightpt); theta_temp = theta_temp - theta_temp(1);
            ai_temp = ai(leftpt:rightpt);
            aj_temp = aj(leftpt:rightpt);

            % interpolate to a desired discretization
            T = linspace(t_temp(1), t_temp(end), dnum);
            X = interp1(t_temp, x_temp, T, 'spline');
            Y = interp1(t_temp, y_temp, T, 'spline');
            THETA = interp1(t_temp, theta_temp, T, 'spline');
            AI = interp1(t_temp, ai_temp, T, 'spline');
            AJ = interp1(t_temp, aj_temp, T, 'spline');

            % return the solution
            q_interp = {T(:)', X(:)', Y(:)', THETA(:)', AI(:)', AJ(:)'}';

        end

        % given a trajectory close it in the null-space of the shape-space slice
        function closedTraj = close_trajectory(openTraj, dc)
            
            % unpack your open_trajectory
            t = openTraj{1};
            x = openTraj{2};
            y = openTraj{3};
            theta = openTraj{4};
            ai = openTraj{5};
            aj = openTraj{6};

            % get the length of the computed open trajectory
            dnum_active = numel(t);
            
            % get the number of points needed in the deadband
            dnum_dead = round(dc*dnum_active);

            % get the deadband configuration trajectories q_d
            t_d = [t, t(end) + t(end)/(dnum_active - 1)*(1:dnum_dead)];
            x_d = [x, x(end)*ones(1, dnum_dead)];
            y_d = [y, y(end)*ones(1, dnum_dead)];
            theta_d = [theta, theta(end)*ones(1, dnum_dead)];
            temp_i = linspace(ai(end), ai(1), dnum_dead + 2); temp_i = temp_i(2:end-1);
            ai_d = [ai, temp_i];
            temp_j = linspace(aj(end), aj(1), dnum_dead + 2); temp_j = temp_j(2:end-1);
            aj_d = [aj, temp_j];

            % create the closed configuration trajectory slice q(phi)_ij
            closedTraj = {[t, t_d]; [x, x_d]; [y, y_d]; [theta, theta_d]; [ai, ai_d]; [aj, aj_d]};

        end
        

    end

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end
