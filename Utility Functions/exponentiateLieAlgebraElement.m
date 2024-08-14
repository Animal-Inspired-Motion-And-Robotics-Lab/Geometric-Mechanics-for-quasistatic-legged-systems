function g = exponentiateLieAlgebraElement( gCirc )
%EXPONENTIATELIEALGEBRAELEMENT exponentiate the lie-algebra element
%provided
%   Given a lie-algebra element, we compute the exponential map-- we
%   explicity compute this result based on the irrotational case and the
%   rotational case

    % input checks
    errMsg = ['ERROR! The input velocity or the lie algebra element ' ...
            'provided should contain 3 columns of x, y, and theta velocity ' ...
            'numeric time series data (atlleast one timestep). Using that, ' ...
            'we shall then compute the group element or body frame ' ...
            'location. Refer to "se2_toyproblems_case_1_mobility.mlx" for ' ...
            'more details.'];
    if ~ismatrix(gCirc)
        error(errMsg);
    end
    if size(gCirc, 2) ~= 3
        if numel(gCirc) ~= 3
            error(errMsg);
        else
            gCirc = gCirc'; % convert to correct form
        end
    end
    if isempty(gCirc)
        error(errMsg);
    end
    if isa(gCirc, "sym") % if a symbol, error out
        error(errMsg);
    end
    nTimeSteps = size(gCirc, 1);
    % ... ideally you would need more information on what caused the error,
    % ... something to flesh out later

    % if you're here, no issues with the input, so initialize the group
    % position (SE(2) body location) and quickly return the theta position
    % as the theta-circ velocity
    g = nan(size(gCirc)); g(:, 3) = gCirc(:, 3);

    % compute the exponential map on the lie algebra elements
    % ... case 1: just one element
    % ... case 2: rows of elements
    % ... subcases within each case handle no rotation and rotation cases
    switch nTimeSteps
        case 1
            switch gCirc(3) == 0
                case 1
                    g(1:2) = gCirc(1:2);
                otherwise
                    g(1:2) = (... % transpose the result into row
                        computeTransVelPerturbMatrix...
                                (gCirc(3))*... % perturb translations
                                        gCirc(1:2)'... % transform them
                             )';
            end
        otherwise
            idxZero = (gCirc(:, 3) == 0); % indices without rotational vel
            if any(idxZero) % if at least one case is present
                g(idxZero, 1:2) = gCirc(idxZero, 1:2);
            end
            if any(~idxZero) % if at least one rotational case is present
                indNonZero = find(~idxZero); % get the index locations
                for i = indNonZero'
                    g(i, 1:2) = (...
                        computeTransVelPerturbMatrix...
                                (gCirc(i, 3))*...
                                        gCirc(i, 1:2)'...
                             )';
                end
            end
    end

end

%% AUXILIARY FUNCTIONS

% compute the arc-travel perturbation matrix to the translational
% velocities obtained using the rotation velocity
% ... the radius of this arc is the translational velocity divided by the
% ... rotational velocity
function M = computeTransVelPerturbMatrix(thDot)
    M = [sin(thDot),   cos(thDot)-1;
         1-cos(thDot), sin(thDot)  ]/thDot;
end