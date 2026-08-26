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
% - Conversion of events from string to numeric.
% - Channel location information is added based on the specified layout.
% - Converting dataset to SET file.
% - Optional trigger shifting to correct event timings:
%   - 'variable' mode: Uses photodiode signals to align triggers accurately.
%   - Fixed delay mode: Applies a constant time shift to all triggers.
%
% Usage:
% 1. Run the script to select raw files for processing.
% 2. Converted SET files will be saved in the respective output directory.
%
% Requirements:
% - MATLAB
% - EEGLab Toolbox
% - BDF plugin (for trigger input cleaning)
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

    % Load BDF file using 'pop_readbdf()' (BDF plugin)
    % to read the trigger input as an additional channel
    % This is then removed after removing the hyperscanning input

    EMG = pop_readbdf(fullfile(sets.rawBDF_dir, file{si}));

    EMG_bkp = EMG;  % temporary, for debugging
    
    %% 1.3.2 - Inspect events and convert to numeric
    
    % NOTE: at the moment, for consistency with the rest of the pipeline, all experimental events (e.g., condition
    % markers) must be numbers, either in numeric or string form (e.g. 20, or '20').
    % Other events can be of different type.
    % If your data requires to work with non-numeric events, please contact francesco.grassi@uni-goettingen.de

    % Use custom function to check events and convert them to numeric if possible
    % Please pay attention to any warning or message displayed in the Command Window
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
        EMG = shift_triggers(EMG, ...
            sets.shift_markers, ...
            sets.shift_method, ...
            sets.shift_window, ...
            sets.shift_threshold);
    end
    
    pause(5); close all
    
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
