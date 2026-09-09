% ---------------------------------------------------------------------------------------------------------------------
% EMG Preprocessing Pipeline
% Version: 2
% author: Francesco Grassi
% date: August 2026
%
% For questions or issues, contact:
% francesco.grassi@uni-goettingen.de
%
% ---------------------------------------------------------------------------------------------------------------------
%
% ++++ EMG_01_raw2set_shift_triggers ++++
%
% This script converts raw data files from the format used by EEG/EMG acquisition systems
% to the SET format (compatible with EEGLab). 
% It also optionally shifts event triggers to compensate for delays between trigger timestamps and 
% the actual event timing (e.g., stimulus onset).
%
% Features:
% - Batch conversion of selected raw files to SET format.
% - Conversion of numeric and string event types to character vectors without changing their encoded values.
% - Channel location information is added based on the specified layout.
% - Converting dataset to SET file.
% - Optional trigger shifting to correct event timings:
%   - 'variable' mode: Per-target photodiode delay with recording-median fallback.
%   - 'median' mode: Recording median of valid photodiode delays for all targets.
%   - Fixed delay mode: Applies a constant time shift to all triggers.
%
% Usage:
% 1. Run the script to select raw files for processing.
% 2. Converted SET files will be saved in the respective output directory.
%
% Requirements:
% - MATLAB
% - EEGLab Toolbox
% - BIOSIG plugin (for BDF import and event extraction)
% - Custom functions: shift_triggers(), fix_EEG_markers()
%
% Output:
% - Converted SET files in the respective output directories.
% - Log messages indicating the progress of each file's conversion.
%
%% 1.1 - Toolboxes and functions

clearvars

% Load preprocessing parameters
project_dir = fileparts(matlab.desktop.editor.getActiveFilename);
settings_file = fullfile(project_dir, 'resources', 'preprocessing_settings.mat');
load(settings_file, 'sets');

addpath(sets.eeglab_dir)  % EEGLab

eeglab; close all;  % start EEGLab and close popup windows

%% 1.2 - Select raw files

% Show gui to select files based on specified format
[file, thissubjectpath] = uigetfile(fullfile(sets.rawBDF_dir, '*.bdf'), 'MultiSelect', 'on');

% Ensure the file names are stored as a cell array even when only one file is selected
if ischar(file)
    file = {file};
end

%% 1.3 - Convert files, fix and shift triggers

% Loop through selected files
for si = 1:length(file)
    
    %% 1.3.1 - Load raw file

    % Load BDF data and events using the BIOSIG plugin.

    EMG = pop_biosig(fullfile(sets.rawBDF_dir, file{si}));

    EMG_bkp = EMG;  % temporary, for debugging
    
    %% 1.3.2 - Convert event types to character vectors
    
    % Convert numeric and string event types to character vectors without changing
    % the experimenter-defined trigger codes. Existing character event types remain unchanged.
    EMG = fix_EEG_markers(EMG);

    %% 1.3.3 - Add channel location info
    
    % Check the recording layout and add corresponding channel location info
    if strcmp(sets.recording_layout, 'EMG')
    % No need for channel location info if EMG only 
    elseif strcmp(sets.recording_layout, 'EEG_64')
        EMG = pop_chanedit(EMG, 'lookup', fullfile(sets.utilities_dir, 'chanloc_biosemi_64.elp'));
    elseif strcmp(sets.recording_layout, 'EEG_128')
        EMG = pop_chanedit(EMG, 'lookup', fullfile(sets.utilities_dir, 'chanloc_biosemi_128.ced'));
    else
        % Raise an error if the value is not valid
        error('Invalid value for the recording layout. It must be ''EMG'', ''EEG_64'', or ''EEG_128''.');
    end
    
    %% 1.3.4 - Shift triggers
    
    % Check if trigger shift is on
    if sets.do_shift_triggers
        shift_markers = sets.shift_markers;
        if isempty(shift_markers)
            shift_markers = sets.condition_triggers;
        end
        [EMG, trigger_shift_diagnostics] = shift_triggers(EMG, ...
            shift_markers, ...
            sets.shift_method, ...
            sets.shift_window, ...
            sets.shift_threshold, sets.shift_minimum_duration_ms);
        % Separate participant-level audit; no new EEG event fields.
        [~, input_stem] = fileparts(file{si});
        save(fullfile(sets.rawSET_dir, [input_stem '_trigger_shift_diagnostics.mat']), ...
            'trigger_shift_diagnostics');
    end
    
    % Keep trigger-shifting diagnostics open for inspection.
    
    %% 1.3.5 - Add file info
    
    % Extract subject number from file name
    sub_id = erase(file{si}, '_raw.bdf');

    EMG.subject = sub_id;
    EMG.setname = [sub_id, sets.fname_raw_data];
    EMG.filename = [EMG.setname, '.set'];
    EMG.filepath = sets.rawSET_dir;
    
    %% 1.3.6 - Save SET file
    
    EMG = pop_saveset(EMG, 'filename', EMG.filename, 'filepath', EMG.filepath);
    
    fprintf(['\nSubject ', sub_id, ' conversion COMPLETE\n\n']);
    
end
