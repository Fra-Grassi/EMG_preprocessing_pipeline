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
% ++++ EMG_00_settings ++++
%
% Toggle steps for preprocessing and define corresponding parameters, including:
%   1. Filtering
%   2. Downsampling
%   3. Signal rectification
%   4. Epoch extraction
%   5. Artefact detection and rejection
%   6. Feature extraction (by bins, optionally)
%   7. Baseline correction
%   8. Within-muscle and within-subject standardization
%   9. Trial averaging
%
% Usage:
% 1. Do not modify Section 0.1 unless different output directory names are required
% 2. Toggle processing steps in Section 0.2 (1 = perform, 0 = skip).
% 3. Specify processing steps parameters in Section 0.2.
% 4. Run script to save parameters as MATLAB struct.
%
% Output:
% - A MATLAB struct 'preprocessing_settings.mat' to be used in following.
% preprocessing steps
% - A 'preprocessing_params.txt' log of the parameters for quick reference.
%
% Requirements:
% - MATLAB
% - EEGLab Toolbox
% - Custom function 'writeSetsToTxt()'
%
%% 0.1 - Setup project folders

clearvars

% ---- Data Folders ----
% The project folder is inferred from the active script in the MATLAB Editor.
% Project-internal paths are then defined relative to that folder.
sets.project_dir = fileparts(matlab.desktop.editor.getActiveFilename);

sets.rawSET_dir = fullfile(sets.project_dir, 'raw');  % path to raw SET data folder
sets.processed_dir = fullfile(sets.project_dir, 'preprocessed');  % path to processed data folder
sets.amplitudes_dir = fullfile(sets.project_dir, 'extracted_amplitudes');  % path to extracted feature amplitudes
sets.utilities_dir = fullfile(sets.project_dir, 'resources');  % path to utilities folder (electrode location, etc)

% Create output folders only when they do not already exist.
% Existing folders and their contents are never removed or replaced here.
output_dirs = {sets.rawSET_dir, sets.processed_dir, sets.amplitudes_dir};
for dir_idx = 1:length(output_dirs)
    if ~isfolder(output_dirs{dir_idx})
        mkdir(output_dirs{dir_idx});
    end
end

%% 0.2 - Parameters

% ---- Study Name ----
% Specify study name as string (e.g., 'my_fancy_study');
sets.study_name = 'hyper_lol_2';

% ---- External folder paths ----
% Specify the external paths to the raw BDF data and EEGLab as strings.
sets.rawBDF_dir = 'N:\ANAP\01_data\HyperLOL2\Raw Data\EMG\merged\';  % path to raw BDF data folder
sets.eeglab_dir = 'N:\ANAP\02_home\Francesco\Matlab plugins\eeglab2025.1.0\';  % path to EEGLab toolbox 

% The resources folder must already exist because it contains required files.
if ~isfolder(sets.utilities_dir)
    error('Resources folder not found: %s', sets.utilities_dir);
end

% ---- Channel layout ----
% String defining the channel layout used during the recording.
% Possible values:
%   - 'EMG':        EMG only recording (no EEG channels were recorded)
%   - 'EEG_64':     EEG recording from 64 channels (with or without EMG channels)
%   - 'EEG_128':    EEG recording from 128 channels (with or without EMG channels)
sets.recording_layout = 'EMG';

% ---- Conditions and Triggers ----
% Numeric vector specifying condition triggers (e.g., [41, 42, 43]).
% IMPORTANT: these are assumed to also be the time-locking epoch event (the 0ms time of the epoch)
% Here specift the condition trigger as the punchline trigger
sets.condition_triggers = [121, 221];

% Cell array of strings specifying condition names (e.g., {'conditiona_1', 'condition_2'}).
% IMPORTANT: condition names must be in same order as condition triggers
sets.condition_names = {'unconstrained', 'suppressed'};

% ---- EMG channels ----
% Specify channel numbers used for each muscle.
% Format depends on recording system: 
% - BioSemi (two channels per muscle):      matrix, one row per muscle, one column per channel.
%                                           (E.g., [channel_1, channel_2; channel_3, channel_4; ...], 
%                                           where 'channel_1' and 'channel_2' belong to one muscle, 
%                                           'channel_3' and 'channel_4' to another, etc.).
% - Brain Vision (one channel per muscle):  1-row array, one element per muscle
%                                           (E.g., [channel_1, channel_2, ...], 
%                                           where 'channel_1', 'channel_2', etc. belong to different muscles)
% NOTE: the difference here is that BioSemi data requires wihtin-muscle re-referencing (i.e., subtracting one muscle
% channel from the other).
sets.emg_channel_numbers = [3, 4;...  % CS
    5, 6;...  % OO
    7, 8];  % ZM

% Cell array of strings specifying ENG channel names (e.g., {'OO', 'ZM'}). 
% IMPORTANT: names must be in same order as 'emg_channel_numbers'
sets.emg_channel_names = {'CS', 'OO', 'ZM'};

% ---- Trigger shift ----
% Shift triggers according to specified method
sets.do_shift_triggers = 0;

% Specify method to shift triggers.
% Possible values:
%   - 'variable':       Uses a photodiode signal to determine the delay.
%   - Numeric value:    Constant delay in milliseconds to shift all specified triggers.
% See 'help shift_triggers' for details.
sets.shift_method = 20;

% Epoch triggers
% Assumed to be the same as condition triggers. If not:
% Numeric vector specifying triggers to shift (e.g., [11, 12, 13]).
% See 'help shift_triggers' for details.
sets.shift_markers = [];

% Epoch length
% Numeric vector specifying epoch start and end in seconds, around triggers to shift.
% Pre-stimulus baseline timepoints are negative (e.g., [-0.5, 3]).
% Only needed if 'trigger_shift' is set to 'variable'. See 'help shift_triggers' for details.
% (This can be quite short, as it needs to contain just the quick photodiode signal).
sets.shift_window = [-0.06, 0.1];

% Photodiode signal threshold
% Numeric value indicating the proportion of the photodiode signal range to consider as actual response. 
% E.g., a value of 4, means that signal above 1/4th of the total signal range is considered actual photodiode response.
% Only needed if 'trigger_shift' is set to 'variable'. See 'help shift_triggers' for details.
sets.shift_threshold = 4;

% ---- Filters ----

% Main filter
% Apply either a low-pass, high-pass, band-pass filter
sets.do_filtering_main = 1;

% Specify main filter type as string
% Possible values: 'lowpass', 'highpass', 'bandpass'.
sets.filter_type_main = 'highpass';

% Specify main filter cutoff(s) in Hz.
% - Single value for 'lowpass' and 'highpass' (e.g., 20)
% - Vector of two numeric for 'bandpass' (e.g., [20 500])
sets.filter_cutoff_main = 20;

% Notch filter
% Apply a notch filter at specific frequency
sets.do_filtering_notch = 0;

% Specify notch filter cutoff in Hz as single numeric value (e.g., 50).
sets.filter_cutoff_notch = 50;

% ---- Downsampling ----
% Downsample data at specified sampling rate
sets.do_downsampling = 1;

% Specify downsampling rate in Hz as single numeric value (e.g., 256).
sets.downsample_rate = 512;

% ---- Signal rectification ----
% Apply signal rectification according to specified method.
sets.do_rectifying = 1;

% Specify rectification method as string.
% Possible values:
% - 'abs':  full-wave rectification (calculating absolute value of the signal)
sets.rectify_method = 'abs';

% ---- Epoching ----
% Numeric vector specifying epoch start and end in seconds, around epoch trigger.
% Pre-stimulus baseline timepoints are negative (e.g., [-0.5, 3]).
sets.epoch_length = [-3 5];

% ---- Artifact detection and rejection ----

% Perform automatic artefact detection with specified thresholds.
sets.do_artefact_detection_automatic = 1;

% Specify detection thresholds as single numerical value in Standard Deviation
% above/below which a signal is considered artefact (e.g., 2).
% Different thresholds are specified for baseline and post-stimulus time-windows.
sets.artefact_threshold_baseline = 3;    % baseline
sets.artefact_threshold_trial = 3;       % post-stimulus

% Perform manual artefact detection
sets.do_artefact_detection_manual = 0;

% ---- Baseline correction ----
% Perform baseline correction according to specified method.
sets.do_baseline_correction = 1;

% Numeric vector specifying start and end in milliseconds of the pre-stimulus time used for baseline correction
% (The lowest value must be within the range specified in 'epoch_length').
sets.baseline_correction_window = [-3000, -2000];

% Specify baseline correction method as string.
% Possible values:
% - 'subtraction':  subtract mean baseline value from each time-point
% - 'division':     divide each time-point by mean baseline value
sets.baseline_correction_method = 'division';

% ---- Within-muscle standardization ----
% Standardize extracted features separately for each muscle within a participant.
% Parameters are estimated across all retained trials, conditions, and post-stimulus bins.
sets.do_standardization_muscle = 1;

% ---- Within-subject standardization ----
% Standardize extracted features across all muscles within a participant.
% Parameters are estimated across all retained trials, conditions, muscles, and post-stimulus bins.
sets.do_standardization_subject = 0;

% ---- Feature extraction ----
% Perform feature extraction according to specified method.
% Possible values, as string:
% - 'mav':  mean absolute value
sets.feature_extraction_method = 'mav';

% Single numerical value specifying bin duration in milliseconds.
% The script will extract as many bins of that length as possible from the epoch
% together with one additional bin of the same lenght from the baseline.
% NOTE 1: to ensure features are extracted from the entire epoch, this must be a multiple of bin duration.
% NOTE 2: an error will be produced if baseline is shorter than bin duration.
sets.feature_extraction_bin_dur = 1000;

% --- Trial averaging ----
% Average amplitudes across trials per condition
sets.do_trial_averaging = 0;

% ---- Data saving ----

% IMPORTANT! Existing files with the same name as defined below will be overwritten!

% Specify name suffix for raw SET files as string.
% Final name will be made of participant and suffix.
% E.g., if set to '_raw', SET files will be named 's-01_raw.set'.
sets.fname_raw_data = '_raw';

% Trial rejection info
% Specify whether to save table with number and percentage of rejected trials.
sets.do_save_trial_rejection_stats = 1;

% Specify file name for trial rejection info as string, with extension (e.g., 'rejected-trials.csv').
sets.fname_trial_rejection_stats = 'rejected-trials-info.csv';

% Preprocessed data
% Specify whether to save EMG struct after all preprocessing steps, including flagged trials, and trial number.
sets.do_save_preprocessed_data = 1;

% Specify name suffix for preprocessed SET file as string.
% Final name will be made of participant ID and suffix.
% E.g., if set to '_preprocessed', SET files will be named '01_preprocessed.set', '02_preprocessed.set', etc.
sets.fname_preprocessed_data = '_preprocessed';

% Feature amplitudes
% Specify whether to save table with feature amplitudes per muscle and condition.
sets.do_save_features_amplitudes = 1;

% Keep rejected trial indexes
% Specify whether to also include rejected trials as empty rows in the output feature amplitudes table
% NOTE: this option is only available if trial averaging is DISABLED and at least one rejection method is enabled!
sets.do_save_rejected_trial_rows = 1;

% Specify file name for feature amplitudes, as string, with extension (e.g., 'feature-amplitudes.csv').
sets.fname_feature_amplitudes = 'feature-amplitudes.csv';

%% 0.3 - Check invalid setting combinations

% Mean absolute value requires full-wave rectification before baseline correction
if strcmp(sets.feature_extraction_method, 'mav') && ...
        ~(sets.do_rectifying && strcmp(sets.rectify_method, 'abs'))
    error(['MAV extraction requires full-wave rectification. ', ...
        'Set do_rectifying to 1 and rectify_method to ''abs''.']);
end

% Within-muscle and within-subject standardization define alternative reference distributions
if sets.do_standardization_muscle && sets.do_standardization_subject
    error(['Within-muscle and within-subject standardization cannot both be enabled. ', ...
        'Select one reference distribution or disable both standardization options.']);
end

% Raise error if rejected trial info saving is requested while trial averaging is enabled
if sets.do_save_rejected_trial_rows && sets.do_trial_averaging
    error('Cannot retain rejected trial info if trial averaging is enabled!');
end

% Raise error if rejected trial info saving is requested but no artefact rejection method is enabled
if sets.do_save_rejected_trial_rows && ~(sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual)
    error('Cannot retain rejected trial info if no artefact rejection is performed!')
end


%% 0.4 - Save settings

% Save 'sets' in utilities folder:
save(fullfile(sets.utilities_dir, 'preprocessing_settings.mat'), 'sets');

% Save a copy of the parameters to TXT file:
writeSetsToTxt(sets, fullfile(sets.utilities_dir, 'preprocessing_settings.txt'));
