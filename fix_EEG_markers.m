function EEG = fix_EEG_markers(EEG)
% fix_EEG_markers() - Convert event types to MATLAB character vectors.
%   Numeric event types are converted to their character representation,
%   string event types are converted to character vectors, and existing
%   character event types are left unchanged.
%
%   Example:
%     EEG = fix_EEG_markers(EEG);
%
% Author: Francesco Grassi, francesco.grassi@uni-goettingen.de

    for i = 1:numel(EEG.event)
        current_type = EEG.event(i).type;

        if isnumeric(current_type)
            EEG.event(i).type = num2str(current_type);
        elseif isstring(current_type)
            EEG.event(i).type = char(current_type);
        end
    end
end
