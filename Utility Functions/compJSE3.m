% This function computes the jacobian in the right format and returns it to the upper function.
function out = compJSE3(J_b__i, J_ib__i, i, idx)

    
    % Make sure the jacobians are the right size.
    if sum(size(J_b__i) == [6, 6]) ~= 2
    
        if nargin < 4
            error('ERROR! The body jacobian must be a 4x4 SE(3) transform.');
        else
            error(['ERROR! The' num2str(idx) ' body jacobian must be a 4x4 SE(3) transform.']);
        end
    
    elseif sum(size(J_ib__i) == [6, 2]) ~= 2
    
        if nargin < 4
            error('ERROR! The hip jacobian must be a 4x4 SE(3) transform.');
        else
            error(['ERROR! The' num2str(idx) ' hip jacobian must be a 4x4 SE(3) transform.']);
        end
    
    else
        
        out = [ J_b__i, [ zeros(6, 2*(i-1)), J_ib__i, zeros(6, 2*(4-i)) ] ]; % compute the full Jacobian
    
    end


end