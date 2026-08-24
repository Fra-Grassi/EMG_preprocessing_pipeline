function EEG = fix_EEG_markers(EEG)
% fix_EEG_markers() - Checks and fixes event markers for compatibility with a numeric-based pipeline.
%   EEG = fix_EEG_markers(EEG) loops over EEG.event and:
%     - Leaves numeric markers as is.
%     - Leaves string markers that are purely numeric as is (e.g., '2').
%     - If a marker matches the Brain Vision style, e.g. letters + optional space + digits
%       (e.g. 'S20', 'S 15', etc.), it extracts the numeric part and overwrites the marker
%       with that numeric string.
%     - Leaves purely textual markers (e.g., 'condition_a') as is but reports them to the user.
%     - Warns if *no* marker is numeric/salvageable at all.
%
%   Example:
%     EEG = fix_EEG_markers(EEG);
%
% Author: Francesco Grassi, francesco.grassi@uni-goettingen.de

    % Flags to track what we find
    foundNumericOrSalvaged = false;  % True if at least one event is numeric or was salvaged
    foundPureChar          = false;  % True if we encountered at least one purely char event
    atLeastOneChange       = false;  % True if at least one change to the events was made

    % Define a regex pattern for Brain Vision style (letters + optional space + digits)
    %   ^[A-Za-z]+\s*(\d+)$
    %   ^           start of string
    %   [A-Za-z]+   one or more letters
    %   \s*         zero or more spaces
    %   (\d+)       one or more digits (captured in a group)
    %   $           end of string
    pattern_bv = '^[A-Za-z]+\s*(\d+)$';

    % Save a copy of the original event markers
    original_events = {EEG.event.type};

    % Loop through all events
    for i = 1:length(EEG.event)
        currentType = EEG.event(i).type;

        % 1) If already numeric, do nothing
        if isnumeric(currentType)
            foundNumericOrSalvaged = true;
            continue;
        end

        % 2) If it's a char/string
        if ischar(currentType)
            % a) Check if it is purely numeric, e.g. '2', '15', '001'
            if ~isnan(str2double(currentType))
                % It's a numeric string, so do nothing
                foundNumericOrSalvaged = true;
            else
                % b) Check if it matches the Brain Vision style:
                %    One or more letters, optional whitespace, then digits.
                %    E.g. 'S 20', 'S20', 'M  003', etc.
                tokens = regexp(currentType, pattern_bv, 'tokens');
                if ~isempty(tokens)
                    % salvage the numeric substring
                    numericPart = tokens{1}{1};  % This should be e.g. '20'
                    % Overwrite the event type with the numeric substring
                    EEG.event(i).type = numericPart;
                    foundNumericOrSalvaged = true;
                    % Flag that at least one change to events was made
                    atLeastOneChange = true;
                else
                    % c) It's purely textual, e.g. 'condition_a'
                    foundPureChar = true;
                end
            end
        else
            % If it's neither numeric nor char (unlikely but possible), treat as purely textual
            foundPureChar = true;
        end
    end

    % If changes were made, save the original event markers for backup
    if atLeastOneChange
        EEG = pop_editeventfield(EEG, 'original_events', original_events);
    end

    % Post-processing messages
    if foundPureChar
        disp(['[fix_EEG_markers] NOTE: Some events are purely textual (e.g. ''condition_a'') and ', ...
              'were left as is. Please ensure the rest of the pipeline can handle them.']);
    end
    if atLeastOneChange
        disp(['[fix_EEG_markers] NOTE: Some events were changed into numerical. ', ...
            'A copy of the original events was stored in EEG.event.original_event']);
    end
    if ~foundNumericOrSalvaged
        warning(['[fix_EEG_markers] None of the events was numeric or salvageable into a numeric ', ...
                 'format. Current pipeline may not support these event markers.']);
    end
end