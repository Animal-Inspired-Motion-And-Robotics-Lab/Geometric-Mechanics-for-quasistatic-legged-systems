% This is a "Path2" class for defining paths on level-2 no-slip contact
% submanifolds for a rigid quadrupedal robot. It takes the initial 
% condition for the shape-space slice (2 dim), gait constraint vector field
% (2 dim), and integration time for the path to construct a Path2 object. 
% A subclass of "Gait2" is passed as a property.

classdef Path2 < RigidGeomQuad

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties (SetAccess = private)

        dz                   % Gait constraint based stratified panel dzij-- [A]*\Vec{d\phi}_{ij}

        dphi                 % Gait constraint vector field dphi_ij-- \Vec{dphi}_{ij}

        point_of_interest    % starting point to compute the path

        int_time             % Integration time in the backward and forward direction from the middle_path

        int_cond             % checks if the pof is on the path, beginning, or at the end of the path

        deadband_dutycycle   % period of time spent swining (0 <= val <= 1)

        scale_path_method    % method to scale the path about the "point_of_interest"--

        open_trajectory      % configuration trajectory for the active path

        closed_trajectory    % configuration trajectory for the whole path

        path_length          % length of the gait

    end

    methods
        
        % Constructor
        function [thisPath2] = Path2(ank, a, l, dzij, dphiij, strpt, t, dc)

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

            end

            % Get the arguments for a superclass constuctor
            if nargin == 8
                quadArgs = [ank, a, l];
            elseif nargin == 6
                quadArgs = ank;
            elseif nargin == 5
                quadArgs = [];
            else
                error('Error: Need 8, 6, or 5 arguments to create an object.');
            end

            % call the RigidGeometricQuadruped class' constructor
            thisPath2 = thisPath2@RigidGeomQuad(quadArgs);

            % assign the props
            thisPath2.dz = dzij;
            thisPath2.dphi = dphiij;
            thisPath2.point_of_interest = strpt;
            thisPath2.int_time = t;
            thisPath2.deadband_dutycycle = dc;

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
        function compute_open_trajectory(thePath2, funcstr)

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

            % get the functions needed to integrate-- 'symbolic' datatype to 'matlabFunction' format
            eval(funcstr{1})
            DPHI = matlabFunction(thePath2.dphi, 'Vars', eval(funcstr{2}));
            DZg = simplify([cos(theta), -sin(theta),  0;
                            sin(theta), cos(theta),   0; ...
                            0,          0,            1]*thePath2.dz); % stratified panel in global coordinates
            DQ = matlabFunction([DZg; DPHI], 'Vars', eval(funcstr{3})); % concatenate to obtain the configuration vector field

            % integrate
            switch cond

                case -1 % just backward path

                    t = linspace(0, thePath2.int_time(1), 201); % backward-- get the start point of path
                    [~,qb] = ode45( @(t,y) -DPHI(t, aa, ll, y(1), y(2)), t, [ai0; aj0] );
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); qb(end,1); qb(end,2)] ); % forward to POF
                
                case 0 % both paths

                    t = linspace(0, thePath2.int_time(1), 201); % backward-- get the start point of path
                    [~,qb] = ode45( @(t,y) -DPHI(t, aa, ll, y(1), y(2)), t, [ai0; aj0] );
                    t = linspace(0, sum(thePath2.int_time), 201); % forward-- integrate the configuration
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); qb(end,1); qb(end,2)] );

                case 1 % just forward path
                    
                    t = linspace(0, thePath2.int_time(2), 201); % just go forward from POF
                    [tf,qf] = ode45( @(t,y) DQ(t, aa, ll, y(1), y(2), y(3), y(4), y(5)), t, [zeros(3,1); ai0; aj0] );

            end

            % return the open configuration trajectory slice q(s)_ij
            thePath2.open_trajectory{10} = {tf(:)', qf(:,1)', qf(:,2)', qf(:,3)', qf(:,4)', qf(:,5)'}';
            % {x, y, \theta, \alpha_i, \alpha_j}
            % since the gait-constraint vector field has unit magnitude, the path length is just the final time of the path
            thePath2.path_length{10} = tf(end);

            % compute multiples of 10% paths to add to the "open_trajectory" and "path_length" props ()()()()()( CHANGE )()()()()() ----------------------------
            for i = (1:numel(thePath2.open_trajectory)-1)*0.1
                thePath2.open_trajectory{i*10} = interpolated_open_trajectory(thePath2.open_trajectory{10}, i);
                thePath2.path_length{i*10} = thePath2.open_trajectory{i*10}{1}(end);               %%()()()()()( CHANGE )()()()()() ----------------------------
            end

        end

        % compute the closed_trajectory
        function compute_closed_trajectory(thePath2)
            
            for i = 1:numel(thePath2.open_trajectory)
                
                % Compute the closed trajectory for each case.
                thePath2.closed_trajectory{i} = close_trajectory(thePath2.open_trajectory{i}, thePath2.deadband_dutycycle);

            end
            
        end
        
        % This function computes different percentages of the open-trajectory by keeping "path_start" prop constant, and using interp1 with the spline method.
        function q_interp = interpolated_open_trajectory(fullPath2, p)
            
            % unpack your open_trajectory
            t = fullPath2{1};
            x = fullPath2{2};
            y = fullPath2{3};
            theta = fullPath2{4};
            ai = fullPath2{5};
            aj = fullPath2{6};

            % get the limitng points
            midpt = ceil(numel(t)/2);
            leftpt = midpt - p*(midpt-1); rightpt = midpt + p*(midpt-1);

            % get the modified trajectory
            t_temp = t(leftpt:rightpt); t_temp = t_temp - t_temp(1);
            x_temp = x(leftpt:rightpt); x_temp = x_temp - x_temp(1);
            y_temp = y(leftpt:rightpt); y_temp = y_temp - y_temp(1);
            theta_temp = theta(leftpt:rightpt); theta_temp = theta_temp - theta_temp(1);
            ai_temp = ai(leftpt:rightpt);
            aj_temp = aj(leftpt:rightpt);

            % interpolate to a desired discretization
            T = linspace(t_temp(1), t_temp(end), 201);
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
