% This function vectorizes input cell arrays in coordinates and time into cell arrays in coordinates and double array in time.
function out = vecSE3traj(in)

    % check for input consistency
    if iscell(in)
        if size(in, 2) > 1
            out = cell(size(in, 1), 1);
            for j = 1:size(in, 1)
                temp = [];
                for i = 1:size(in, 2)
                    if i == 1
                        temp = in{j, i};
                    else
                        temp = [temp, in{j, i}];
                    end
                end
                out{j} = temp;
            end
        else
            error('ERROR! This should be like a shape trajectory generated by ')
        end
    else
        error('ERROR! Input should be a cell array.');
    end









end