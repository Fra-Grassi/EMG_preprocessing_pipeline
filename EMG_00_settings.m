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
%   6. Feature extraction by bins
%   7. Baseline correction
%   8. Within-muscle and within-subject standardization
%   9. Trial averaging
%
% Usage:
% 1. Edit only Section 0.2: external paths, processing toggles (1/0), and parameters.
% 2. Section 0.1 automatically sets up internal paths and creates missing output folders.
% 3. Section 0.3 automatically validates settings; Section 0.4 adds metadata and saves them.
% 4. Run the whole script, or Sections 0.1--0.4 once in order, before later stages.
%    Keep this script active in the MATLAB Editor. Rerun after changing settings.
%
% Output:
% - 'preprocessing_settings.mat' containing the 'sets' struct for later stages.
% - 'preprocessing_settings.txt' listing the parameters for quick reference.
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
addpath(sets.project_dir)  % shared functions remain available during section execution

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

% The resources folder must already exist because it contains required files.
if ~isfolder(sets.utilities_dir)
    error('utilities_dir: Resources folder not found: %s. Check Stage 0, Section 0.1.', sets.utilities_dir);
end

%% 0.2 - Parameters

% ---- Study Name ----
% Specify study name as string (e.g., 'my_fancy_study');
sets.study_name = 'hyper_lol_2';

% ---- External folder paths ----
% Specify the external paths to the raw BDF data and EEGLab as strings.
sets.rawBDF_dir = 'N:\ANAP\01_data\HyperLOL2\Raw Data\EMG\merged\';  % path to raw BDF data folder
sets.eeglab_dir = 'N:\ANAP\02_home\Francesco\Matlab plugins\eeglab2025.1.0\';  % path to EEGLab toolbox 

% ---- Channel layout ----
% String defining the channel layout used during the recording.
% Possible values:
%   - 'EMG':        EMG only recording (no EEG channels were recorded)
%   - 'EEG_64':     EEG recording from 64 channels (with or without EMG channels)
%   - 'EEG_128':    EEG recording from 128 channels (with or without EMG channels)
sets.recording_layout = 'EMG';

% ---- Conditions and Triggers ----
% Cell array of character vectors specifying condition triggers (e.g., {'41', '42', '43'}).
% Stage 1 converts all EEG.event.type values to character vectors, consistent with
% character-based event handling in relevant EEGLAB functions.
% Enter the exact experimenter-defined code, preserving prefixes, spaces, and leading zeros.
% IMPORTANT: these are assumed to also be the time-locking epoch event (the 0ms time of the epoch)
% Here specify the condition trigger as the punchline trigger
sets.condition_triggers = {'121', '221'};

% Cell array of strings specifying condition names (e.g., {'condition_1', 'condition_2'}).
% IMPORTANT: condition names must be in same order as condition triggers
sets.condition_names = {'unconstrained', 'suppressed'};

% ---- EMG channels ----
% Specify how recorded channels become output muscle channels:
% - 'single':  select one recorded channel per muscle without subtraction.
% - 'bipolar': calculate one muscle per row as first channel - second channel.
sets.emg_reference_mode = 'bipolar';

% Specify the recorded channel numbers in the same muscle order as
% sets.emg_channel_names.
% - 'single':  row or column vector with one source channel per muscle.
% - 'bipolar': n_muscles-by-2 matrix; a 1-by-2 pair is one bipolar muscle.
sets.emg_channel_numbers = [3, 4;...  % CS
    5, 6;...  % OO
    7, 8];  % ZM

% Cell array of character vectors specifying EMG channel names (e.g., {'OO', 'ZM'}).
% IMPORTANT: names must be in same order as 'emg_channel_numbers'
sets.emg_channel_names = {'CS', 'OO', 'ZM'};

% ---- Trigger shift ----
% Shift triggers according to specified method
% CD-13: add round(delay_ms * srate / 1000) to each selected event latency.
sets.do_shift_triggers = 0;

% Specify method to shift triggers.
% Possible values:
%   - 'variable':       Per-target photodiode delay, recording-median fallback.
%   - 'median':         Recording median of valid delays for all targets.
%   - Numeric value:    Constant delay in milliseconds to shift all specified triggers.
% See 'help shift_triggers' for details.
sets.shift_method = 20;

% Epoch triggers
% Empty uses condition_triggers in Stage 1. Otherwise supply exact character
% codes, e.g. {'121', 'S 121'}, preserving spaces, prefixes and leading zeros.
% See 'help shift_triggers' for details.
sets.shift_markers = [];

% Epoch length
% Numeric vector specifying epoch start and end in seconds, around triggers to shift.
% Pre-stimulus baseline timepoints are negative (e.g., [-0.5, 3]).
% Required for 'variable' and 'median'; must include the [-29,0] ms baseline.
% (This can be quite short, as it needs to contain just the quick photodiode signal).
sets.shift_window = [-0.06, 0.1];

% Photodiode signal threshold
% Numeric value indicating the proportion of the photodiode signal range to consider as actual response. 
% E.g., a value of 4, means that signal above 1/4th of the total signal range is considered actual photodiode response.
% Used for 'variable' and 'median': processed signal >= range(signal)/divisor.
sets.shift_threshold = 4;

% Sustained crossing duration in ms (sample-count duration, CD-14).
% ceil(duration_ms*srate/1000) consecutive samples: 20 ms needs 11 at 512 Hz.
sets.shift_minimum_duration_ms = 20;

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
% The script extracts bins spanning the post-stimulus epoch,
% together with one additional bin of the same length immediately before time zero.
% NOTE 1: the post-stimulus epoch duration must be an integer multiple of bin duration.
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
% Specify whether to save the EMG struct after baseline correction, before flagged trials are removed.
% The saved checkpoint retains rejection marks and original trial numbers.
sets.do_save_preprocessed_data = 1;

% Specify name suffix for preprocessed SET file as string.
% Final name will be made of participant ID and suffix.
% E.g., if set to '_preprocessed', SET files will be named '01_preprocessed.set', '02_preprocessed.set', etc.
sets.fname_preprocessed_data = '_preprocessed';

% Feature amplitudes
% Specify whether to save table with feature amplitudes per muscle and condition.
sets.do_save_features_amplitudes = 1;

% Keep rejected trial indexes
% Specify whether to include rejected trials with their row identifiers and missing feature values in the output table
% NOTE: this option is only available if trial averaging is DISABLED and at least one rejection method is enabled!
sets.do_save_rejected_trial_rows = 1;

% Specify file name for feature amplitudes, as string, with extension (e.g., 'feature-amplitudes.csv').
sets.fname_feature_amplitudes = 'feature-amplitudes.csv';

%% 0.3 - Validate settings (automatic)

validate_settings(sets, 'stage0');

%% 0.4 - Save settings

% Capture the environment automatically; Section 0.2 contains only user parameters.
sets.timestamp = char(datetime('now', 'TimeZone', 'local', ...
    'Format', 'yyyy-MM-dd''T''HH:mm:ssXXX'));
sets.operating_system = char(system_dependent('getos'));
sets.matlab_version = char(version);

% Read declared versions from the configured EEGLAB installation, without
% executing EEGLAB/plugin code or changing the MATLAB path. Multiple matching
% files are ambiguous: keep 'unavailable' rather than guess the active version.
version_files = {'eeg_getversion.m', 'eegplugin_biosig.m', ...
    'eegplugin_cleanline.m', 'eegplugin_firfilt.m'};
local_versions = repmat({'unavailable'}, size(version_files));
for version_idx = 1:numel(version_files)
    try
        version_matches = dir(fullfile(sets.eeglab_dir, '**', version_files{version_idx}));
        if isscalar(version_matches) && ~version_matches.isdir
            version_source = fileread(fullfile(version_matches.folder, version_matches.name));
            version_token = regexp(version_source, ...
                "(?m)^[ \t]*vers[ \t]*=[ \t]*'([^'\r\n]+)'", 'tokens', 'once');
            if ~isempty(version_token) && ~isempty(strtrim(version_token{1}))
                local_versions{version_idx} = strtrim(version_token{1});
            end
        end
    catch
        % Optional local version discovery must not prevent settings saving.
    end
end
sets.eeglab_version = local_versions{1};
sets.plugin_versions = struct('BIOSIG', local_versions{2}, ...
    'CleanLine', local_versions{3}, 'FIRfilt', local_versions{4});

sets.pipeline_git_commit = 'unavailable';
try
    if isfile(fullfile(sets.project_dir, '.git')) || isfolder(fullfile(sets.project_dir, '.git'))
        % Avoid shell interpolation of project paths; restore the caller's folder.
        provenance_original_dir = pwd;
        provenance_cleanup = onCleanup(@() cd(provenance_original_dir));
        cd(sets.project_dir);
        [git_status, git_commit] = system('git rev-parse --verify HEAD 2>&1');
        if git_status == 0 && ~isempty(regexp(strtrim(git_commit), '^[0-9a-fA-F]{40}$', 'once'))
            sets.pipeline_git_commit = strtrim(git_commit);
        end
    end
catch
    % Git and repository metadata are optional.
end
clear provenance_cleanup

% Save 'sets' in utilities folder:
save(fullfile(sets.utilities_dir, 'preprocessing_settings.mat'), 'sets');

% Save a copy of the parameters to TXT file:
writeSetsToTxt(sets, fullfile(sets.utilities_dir, 'preprocessing_settings.txt'));
