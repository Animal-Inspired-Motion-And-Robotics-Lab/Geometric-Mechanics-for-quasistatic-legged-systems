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

        int_time             % Integration time in the backward (1) and forward direction (2) from the middle_path

        int_cond             % checks if the pof is on the path, beginning, or at the end of the path

        deadband_dutycycle   % period of time spent swinging in the sub-gait (0 <= val <= 1)
                             % path psi in submanifold + path to return to starting point through the nullspace of the submanifold

        scale_path_method    % method to scale the path about the "point_of_interest"-- this prop then scales the time vector for the closed length path
                             % and changes the ordering based on final time. Some examples include, 'accln', 'vel'

        initial_condition    % this is the starting point of the path

        final_condition      % this is the ending point of the path

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

                si      (1, 1) double {mustBePositive, mustBeLessThanOrEqual(si, 6)}

                dirn    (1, 1) double {mustBeLessThanOrEqual(dirn, 1), mustBeGreaterThanOrEqual(dirn, -1)}

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
        
            % initialize the return container-- we shall return percentages (from -100% to 100% in steps of 10%) of the generated full open_trajectory
            num_scale = 20;
            thePath2.open_trajectory = cell(1,num_scale);
            thePath2.path_length = cell(1,num_scale);
            
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
            DQ = matlabFunction(DQ, 'Vars', eval(funcstr{3}));                   % configuration vector field

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
            
            % Here, we shall compute/interpolate and store the positive and negatively scaled gaits ------------------------------------------------------------

            % store the open configuration trajectory slice q(s)_ij for the full path
            thePath2.open_trajectory{20} = {tf(:)', qf(:,1)', qf(:,2)', qf(:,3)', qf(:,4)', qf(:,5)'}'; % +100% path
            thePath2.open_trajectory{1} = {tf(:)', fliplr((-qf(end,1) + qf(:,1))'), fliplr((-qf(end,2) + qf(:,2))'), fliplr((-qf(end,3) + qf(:,3))'),...
                fliplr(qf(:,4)'), fliplr(qf(:,5)')}'; % -100% path
            % {x, y, \theta, \alpha_i, \alpha_j}
            % store the initial and final conditions of the path
            thePath2.initial_condition{20} = [thePath2.open_trajectory{20}{5}(1) thePath2.open_trajectory{20}{6}(1)];
            thePath2.final_condition{20} = [thePath2.open_trajectory{20}{5}(end) thePath2.open_trajectory{20}{6}(end)];
            thePath2.initial_condition{1} = [thePath2.open_trajectory{1}{5}(1) thePath2.open_trajectory{1}{6}(1)];
            thePath2.final_condition{1} = [thePath2.open_trajectory{1}{5}(end) thePath2.open_trajectory{1}{6}(end)];
            % compute the net displacement
            thePath2.net_displacement(:,20) = [thePath2.open_trajectory{20}{2}(end), thePath2.open_trajectory{20}{3}(end), thePath2.open_trajectory{20}{4}(end)]';
            thePath2.net_displacement(:,1) = [thePath2.open_trajectory{1}{2}(end), thePath2.open_trajectory{1}{3}(end), thePath2.open_trajectory{1}{4}(end)]';
            % store the closed trajectory
            thePath2.closed_trajectory{20} = thePath2.close_trajectory(thePath2.open_trajectory{20}, thePath2.deadband_dutycycle);
            thePath2.closed_trajectory{1} = thePath2.close_trajectory(thePath2.open_trajectory{1}, thePath2.deadband_dutycycle);
            % since the gait-constraint vector field has unit magnitude, the path length is just the final time of the path
            thePath2.path_length{20} = thePath2.open_trajectory{20}{1}(end);
            thePath2.path_length{1} = thePath2.open_trajectory{1}{1}(end);
            
            % compute multiples of 10% paths to add to the "open_trajectory" and "path_length" props
            for i = 1:0.5*num_scale-1
                
                iP = 0.5*num_scale + i;     % indices for positively scaled paths
                iN = 0.5*num_scale - i + 1; % indices for negatively scaled paths
                
                % compute interpolated positively scaled paths
                thePath2.open_trajectory{iP} = thePath2.interpolated_open_trajectory(thePath2.open_trajectory{20}, i*0.1, cond, dnum); % compute the scaled path
                thePath2.net_displacement(:,iP) = [thePath2.open_trajectory{iP}{2}(end), thePath2.open_trajectory{iP}{3}(end), thePath2.open_trajectory{iP}{4}(end)]';
                thePath2.closed_trajectory{iP} = thePath2.close_trajectory(thePath2.open_trajectory{iP}, thePath2.deadband_dutycycle); % close it-- might not use this much
                thePath2.path_length{iP} = thePath2.open_trajectory{iP}{1}(end); % get the path length
                thePath2.initial_condition{iP} = [thePath2.open_trajectory{iP}{5}(1) thePath2.open_trajectory{iP}{6}(1)]; % path initial and final conditions
                thePath2.final_condition{iP} = [thePath2.open_trajectory{iP}{5}(end) thePath2.open_trajectory{iP}{6}(end)];
                
                % compute interpolated negatively scaled paths
                thePath2.open_trajectory{iN} = thePath2.interpolated_open_trajectory(thePath2.open_trajectory{1}, i*0.1, cond, dnum);
                thePath2.net_displacement(:,iN) = [thePath2.open_trajectory{iN}{2}(end), thePath2.open_trajectory{iN}{3}(end), thePath2.open_trajectory{iN}{4}(end)]';
                thePath2.closed_trajectory{iN} = thePath2.close_trajectory(thePath2.open_trajectory{iN}, thePath2.deadband_dutycycle);
                thePath2.path_length{iN} = thePath2.open_trajectory{iN}{1}(end);
                thePath2.initial_condition{iN} = [thePath2.open_trajectory{iN}{5}(1) thePath2.open_trajectory{iN}{6}(1)];
                thePath2.final_condition{iN} = [thePath2.open_trajectory{iN}{5}(end) thePath2.open_trajectory{iN}{6}(end)];
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
        
        % This function computes the no-slip shape var 2 trajectory given shape var 1 traj.
        function [rout, rout_dot] = compute_noslip_trajectory(in)
            
            % Unpack
            rinp = in{1}; % pure sine params
            t = in{2}; % time vector
            dpsi = in{3}; % 2x1 vector output
            rin0 = in{4}; % ic
            aa = in{5}; ll = in{6}; % robot params
            
            % Compute requirements to compute 'rout_dot'
            rin = genswing_t(t, rinp); rin_dot = genswingrate_t(t, rinp);

            % ODE intergrate to obtain 'rout'
            [~, rout] = ode45(   @(t,x) (  [0, 1]*dpsi( aa, ll, genswing_t(t, rinp), x )  ) ./...
                (  [1, 0]*dpsi( aa, ll, genswing_t(t, rinp), x) ) .* genswingrate_t(t, rinp),...
                t - t(1), rin0   ); % compute
            rout = rout(:)'; % row vector needed

            % vectorially compute 'rout_dot'
            rout_dot = (  [0, 1]*dpsi( aa, ll, rin, rout )  ) ./ (  [1, 0]*dpsi( aa, ll, rin, rout) ) .* rin_dot;

        end

        % given a contact and shape trajectory-- say from an experiment, obtain an estimate for the SE(2) body velocity and then integrate it to obtain the body
        % trajectory
        % % case 0: shape trajectories estimated from experiments
        % % case 1: pure sinusoidal swing with contact during backward swing
        % % case 2: case 1 but with phase offset to reduce slip between 
        function b_hat = estimate_SE2_trajectory(in, hamr_params)

            % Unpack
            J = hamr_params{1}; aa = hamr_params{2}; ll = hamr_params{3};
            bic = in{1}; t = in{2}; that = t - t(1);

            switch numel(in{3})
                case 2
                    if numel(in{3}{1}) ~= numel(in{3}{2})
                        error('ERROR! The length of r and r_dot must be equal.');
                    end
                    verifylength(in{3}{1});
                    verifylength(in{3}{2});
                    for idx = 1:numel(in{3}{1})
                        if numel(in{3}{1}{idx}) ~= numel(t)
                            error(['ERROR! The length of trajectory element r_'...
                                num2str(idx) ' and t must be equal.']);
                        end
                        if numel(in{3}{2}{idx}) ~= numel(t)
                            error(['ERROR! The length of trajectory element r_dot_'...
                                num2str(idx) ' and t must be equal.']);
                        end
                    end
                    r = in{3}{1}; r_dot = in{3}{2};
                case 1
                    % if it is not a pure sine fit, then return an error
                    % fit form: mul*yamp*cos(2*pi*f*(t - tau)) + y_dc
                    % params order: {mul, yamp, f, tau, y_dc}
                    for idx = 1:numel(in{3}{1})
                        if numel(in{3}{1}{idx}) ~= 5
                            error(['ERROR! This function only accepts time-series arrays {1x2}{8x1}[1xtn] or' ...
                                ' pure sine fits {1x1}{8x1}[5x1].']);
                        end
                    end
                    [r, r_dot] = genSine_r_rdot(in{3}{1}, t);
            end
            if numel(r) == 8
                r = r(1:2:end); r_dot = r_dot(1:2:end);
            end

            switch size(in{4}{1}, 1)
                case 1
                    c = in{4};
                case 3
                    if numel(hamr_params) ~= 4
                        error(['ERROR! For recreating contact trajectory from leg_z trajectory, a threshold' ...
                            'value is needed as the 4th input in the second argument.'])
                    end
                    c = expkin_contact_thresholding(in{4} ,hamr_params{4});
            end
            r = convert2case1convention(r); r_dot = convert2case1convention(r_dot); % conversion to case 1 format

            % Initial condition for body trajectory
            x0 = [-bic{2}; bic{1}; bic{3}];

             % Compute the body velocity using ode45
            warning("off"); % switch off interpolation warnings and switch it back on after integrating the ode
            [~, b_hat_temp] = ode45(  @(t,x) compute_SE2bodyvelocityfromfullJ( t, aa, ll, x, {c, J, r, r_dot, that}), that, x0  ); % pass the time vector for interp1
            warning("on");
            b_hat{1} = b_hat_temp(:, 2); b_hat{2} = -b_hat_temp(:, 1); b_hat{3} = b_hat_temp(:, 3); % convert it back to the HAMR Kinematics format
            b_hat{1} = b_hat{1}(:)'; b_hat{2} = b_hat{2}(:)'; b_hat{3} = b_hat{3}(:)'; b_hat = b_hat(:); % make them row time-series and stack the cell array

            % % % % % % % % % % % % % % % % % % % % % % % % % LEGACY APPROACH
            % % % % % Unpack the trajectory structure
            % % % % exp_traj = traj.exp;
            % % % % 
            % % % % % unpack your experimental/estimated trajectory
            % % % % J = hamr_params{1}; aa = hamr_params{2}; ll = hamr_params{3};
            % % % % that = exp_traj.t - exp_traj.t(1); % zero the first time-step
            % % % % if nargin < 3
            % % % %     flag = 0;
            % % % % end
            % % % % switch flag
            % % % %     case 0 % exp shapes
            % % % %         r = exp_traj.r(1:2:end); r_dot = exp_traj.r_dot(1:2:end);
            % % % %         if numel(hamr_params) == 3
            % % % %             c = exp_traj.C_i;
            % % % %         elseif numel(hamr_params) == 4
            % % % %             c = expkin_contact_thresholding(exp_traj.ht3_e__i ,hamr_params{4});
            % % % %         end
            % % % %     case 1 % pure sinusoidal shapes with backswing contact
            % % % %         [r, r_dot] = genSine_r_rdot(traj.est.r1_params, exp_traj.t); 
            % % % %         r = r(1:2:end); r_dot = r_dot(1:2:end); 
            % % % %         c = genBackSwingContact(r_dot);
            % % % %     case 2 % pure sinusoidal shapes with backswing contact + phase between legs sharing a level-2 contact state
            % % % %         r = traj.est.r2(1:2:end); r_dot = traj.est.r2_dot(1:2:end);  % (['r2', ijchar]) % (['r2', ijchar, '_dot'])
            % % % %         c = genBackSwingContact(r_dot);
            % % % % end
            % % % % r = convert2case1convention(r); r_dot = convert2case1convention(r_dot); % conversion to the right format
            % % % % 
            % % % % % Initial condition for body trajectory
            % % % % x0 = [-exp_traj.b{2}(1); exp_traj.b{1}(1); exp_traj.b{6}(1)]; % since it is an SE(2) slice, we only need x (-y when moving from HAMR's SE(3) to our 
            % % % %                                                               % SE(2) convention), y (x), and yaw values.
            % % % % 
            % % % % % Compute the body velocity using ode45
            % % % % warning("off"); % switch off interpolation warnings and switch it back on after integrating the ode
            % % % % [~, b_hat_temp] = ode45(  @(t,x) compute_SE2bodyvelocityfromfullJ( t, aa, ll, x, {c, J, r, r_dot, that}), that, x0  ); % pass the time vector for interp1
            % % % % warning("on");
            % % % % b_hat{1} = b_hat_temp(:, 2); b_hat{2} = -b_hat_temp(:, 1); b_hat{3} = b_hat_temp(:, 3); % convert it to the HAMR Kinematics format
            % % % % b_hat{1} = b_hat{1}(:)'; b_hat{2} = b_hat{2}(:)'; b_hat{3} = b_hat{3}(:)'; b_hat = b_hat(:); % make them row time-series and stack the cell array
            
        end
        
        
    end
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
end