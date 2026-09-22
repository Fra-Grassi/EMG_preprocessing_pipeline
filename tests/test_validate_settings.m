function tests = test_validate_settings
% Portable, synthetic contract tests; no EEGLAB or participant data required.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.oldPath = path;
addpath(project);
root = tempname;
mkdir(root);
testCase.TestData.root = root;
for name = {'raw', 'processed', 'amplitudes', 'resources', 'bdf', 'eeglab'}
    mkdir(fullfile(root, name{1}));
end
testCase.TestData.settings = fixture(root);
end

function teardownOnce(testCase)
path(testCase.TestData.oldPath);
rmdir(testCase.TestData.root, 's');
end

function testValidAndReadOnly(testCase)
s = testCase.TestData.settings;
before = s;
files_before = dir(fullfile(testCase.TestData.root, '**', '*'));
for stage = {'stage0', 'stage1', 'stage2'}
    validate_settings(s, stage{1});
end
verifyEqual(testCase, s, before);
verifyEqual(testCase, dir(fullfile(testCase.TestData.root, '**', '*')), files_before);
% Exact character codes, including trailing spaces and leading zeros, survive.
verifyEqual(testCase, s.condition_triggers, {'S 001 ', '002'});
end

function testCombinationChecks(testCase)
s = testCase.TestData.settings;
s.do_rectifying = false;
reject(testCase, s, 'do_rectifying');
s = testCase.TestData.settings;
s.do_standardization_subject = true;
reject(testCase, s, 'do_standardization_subject');
s = testCase.TestData.settings;
s.do_trial_averaging = true;
reject(testCase, s, 'do_trial_averaging');
s = testCase.TestData.settings;
s.do_artefact_detection_automatic = false;
reject(testCase, s, 'do_save_rejected_trial_rows');
end

function testMalformedSettings(testCase)
s = rmfield(testCase.TestData.settings, 'epoch_length');
reject(testCase, s, 'epoch_length');
s = testCase.TestData.settings;
s.do_downsampling = [0 1];
reject(testCase, s, 'do_downsampling');
s.do_downsampling = NaN;
reject(testCase, s, 'do_downsampling');
s.do_downsampling = '1';
reject(testCase, s, 'do_downsampling');
s = testCase.TestData.settings;
s.filter_type_main = 'not-supported';
reject(testCase, s, 'filter_type_main');
s = testCase.TestData.settings;
s.rectify_method = {'abs', 'abs'};
reject(testCase, s, 'rectify_method');
s = testCase.TestData.settings;
s.feature_extraction_method = 'rms';
reject(testCase, s, 'feature_extraction_method');
end

function testLabelsAndChannelContract(testCase)
s = testCase.TestData.settings;
s.condition_names = {'one'};
reject(testCase, s, 'condition_names');
s = testCase.TestData.settings;
s.condition_triggers = {121, '002'};
reject(testCase, s, 'condition_triggers');
s.condition_triggers = {"S 001 ", '002'};
reject(testCase, s, 'condition_triggers');
s = testCase.TestData.settings;
s.emg_reference_mode = 'single';
s.emg_channel_numbers = [1 2];
s.emg_channel_names = {'one', 'two'};
validate_settings(s, 'stage2');
s.emg_channel_numbers = [1; 2];
validate_settings(s, 'stage2');
s.emg_channel_numbers = [1 2; 3 4];
reject(testCase, s, 'emg_channel_numbers');
s.emg_channel_numbers = [1 2];
s.emg_channel_names = {'one'};
reject(testCase, s, 'emg_channel_names');
s = testCase.TestData.settings;
s.emg_reference_mode = 'bipolar';
s.emg_channel_numbers = [1 2];
s.emg_channel_names = {'one'};
validate_settings(s, 'stage2'); % one-muscle bipolar pair
s.emg_channel_numbers = [1; 2];
reject(testCase, s, 'emg_channel_numbers');
s.emg_channel_numbers = [1 2 3; 4 5 6];
reject(testCase, s, 'emg_channel_numbers');
s.emg_channel_numbers = [1 2; 3 4];
s.emg_channel_names = {'one'};
reject(testCase, s, 'emg_channel_names');
s.emg_channel_numbers = [0 2];
reject(testCase, s, 'emg_channel_numbers');
s = testCase.TestData.settings;
s.emg_reference_mode = 'average';
reject(testCase, s, 'emg_reference_mode');
s.emg_reference_mode = "single";
reject(testCase, s, 'emg_reference_mode');
s = rmfield(testCase.TestData.settings, 'emg_reference_mode');
reject(testCase, s, 'emg_reference_mode');
end

function testWindowsAndUnits(testCase)
s = testCase.TestData.settings;
s.epoch_length = [1 -1];
reject(testCase, s, 'epoch_length');
s = testCase.TestData.settings;
s.feature_extraction_bin_dur = 0;
reject(testCase, s, 'feature_extraction_bin_dur');
s.feature_extraction_bin_dur = 3000;
reject(testCase, s, 'feature_extraction_bin_dur');
s = testCase.TestData.settings;
s.epoch_length = [-0.002 0.005]; % accidental milliseconds-to-seconds mismatch
reject(testCase, s, 'epoch_length');
s = testCase.TestData.settings;
s.baseline_correction_window = [-3000 -1000];
reject(testCase, s, 'baseline_correction_window');
s.baseline_correction_window = [-1000 100];
reject(testCase, s, 'baseline_correction_window');
s = testCase.TestData.settings;
s.feature_extraction_bin_dur = 700;
reject(testCase, s, 'feature_extraction_bin_dur');
s = testCase.TestData.settings;
s.epoch_length = [-2 0.3];
s.feature_extraction_bin_dur = 100;
validate_settings(s, 'stage2'); % decimal arithmetic must not require exact equality
s.epoch_length(2) = 0.30001;
reject(testCase, s, 'feature_extraction_bin_dur');
end

function testActiveNumericParameters(testCase)
s = testCase.TestData.settings;
s.filter_type_main = 'bandpass';
s.filter_cutoff_main = [20 100];
validate_settings(s, 'stage2');
s.filter_cutoff_main = [100 20];
reject(testCase, s, 'filter_cutoff_main');
s.filter_type_main = 'lowpass';
s.filter_cutoff_main = [20 100];
reject(testCase, s, 'filter_cutoff_main');
s = testCase.TestData.settings;
s.do_filtering_notch = true;
s.filter_cutoff_notch = 2;
reject(testCase, s, 'filter_cutoff_notch');
s = testCase.TestData.settings;
s.downsample_rate = Inf;
reject(testCase, s, 'downsample_rate');
s = testCase.TestData.settings;
s.artefact_threshold_trial = -1;
reject(testCase, s, 'artefact_threshold_trial');
end

function testShiftingModesAndArgumentAccess(testCase)
s = testCase.TestData.settings;
s.do_shift_triggers = true;
s.shift_method = -20;
s.shift_window = 'unused';
s.shift_threshold = -1;
s.shift_minimum_duration_ms = NaN;
validate_settings(s, 'stage0');
s.shift_method = Inf;
reject(testCase, s, 'shift_method', 'stage1');
s.shift_method = -20;
s = rmfield(s, 'shift_window'); % Stage 1 passes even unused arguments
reject(testCase, s, 'shift_window', 'stage1');
s = testCase.TestData.settings;
s.do_shift_triggers = true;
for method = {'variable', 'median'}
    s.shift_method = method{1};
    validate_settings(s, 'stage1');
end
s.shift_window = [-0.02 0.1];
reject(testCase, s, 'shift_window', 'stage1');
s.shift_window = [-0.03 0];
reject(testCase, s, 'shift_window', 'stage1');
s.shift_window = [-0.03 0.1];
s.shift_minimum_duration_ms = 0;
reject(testCase, s, 'shift_minimum_duration_ms', 'stage1');
s.shift_minimum_duration_ms = 20;
s.shift_threshold = -4;
reject(testCase, s, 'shift_threshold', 'stage1');
end

function testInactiveValuesAndFields(testCase)
s = testCase.TestData.settings;
s.do_filtering_main = false;
s.filter_type_main = [];
s.filter_cutoff_main = 'unused';
s.filter_cutoff_notch = NaN;
s.do_downsampling = false;
s.downsample_rate = [];
s.do_baseline_correction = false;
s.baseline_correction_method = 'unused';
s.baseline_correction_window = [2 1];
s.do_artefact_detection_automatic = false;
s.do_save_rejected_trial_rows = false;
s.artefact_threshold_baseline = [];
s.artefact_threshold_trial = -10;
s.shift_method = 'unused';
s.shift_window = NaN;
s.shift_markers = 99;
s.shift_threshold = [];
s.shift_minimum_duration_ms = 0;
validate_settings(s, 'stage0');
s = rmfield(s, 'downsample_rate');
validate_settings(s, 'stage2'); % unused and never accessed by this stage
reject(testCase, s, 'downsample_rate', 'stage0'); % complete current schema required
end

function testStageSpecificPathsAndResources(testCase)
s = testCase.TestData.settings;
s.rawBDF_dir = fullfile(testCase.TestData.root, 'absent-bdf');
validate_settings(s, 'stage2');
reject(testCase, s, 'rawBDF_dir', 'stage1');
verifyFalse(testCase, isfolder(s.rawBDF_dir));
s = rmfield(s, {'rawBDF_dir', 'recording_layout', 'utilities_dir', 'shift_method', 'do_shift_triggers'});
validate_settings(s, 'stage2');
s = testCase.TestData.settings;
s = rmfield(s, {'epoch_length', 'emg_channel_numbers', 'condition_names'});
validate_settings(s, 'stage1');
s = testCase.TestData.settings;
% EMG-only needs no channel-location file; enabled EEG layout does.
validate_settings(s, 'stage0');
s.recording_layout = 'EEG_64';
reject(testCase, s, 'chanloc_biosemi_64.elp', 'stage1', '0.1');
resource = fullfile(s.utilities_dir, 'chanloc_biosemi_64.elp');
fid = fopen(resource, 'w'); fclose(fid);
cleanup = onCleanup(@() delete(resource)); %#ok<NASGU>
validate_settings(s, 'stage1');
s.recording_layout = 'EEG_128';
reject(testCase, s, 'chanloc_biosemi_128.ced', 'stage1', '0.1');
s = testCase.TestData.settings;
s.do_save_preprocessed_data = false;
s.do_save_trial_rejection_stats = false;
s.do_save_features_amplitudes = false;
s.processed_dir = fullfile(testCase.TestData.root, 'absent-output');
s.amplitudes_dir = s.processed_dir;
validate_settings(s, 'stage2');
s.do_save_features_amplitudes = true;
reject(testCase, s, 'amplitudes_dir', 'stage2', '0.1');
verifyFalse(testCase, isfolder(s.amplitudes_dir));
end

function reject(testCase, s, fragment, stage, section)
if nargin < 4, stage = 'stage2'; end
if nargin < 5, section = '0.2'; end
before = s;
try
    validate_settings(s, stage);
catch exception
    verifyEqual(testCase, exception.identifier, 'validate_settings:InvalidSetting');
    verifyTrue(testCase, contains(exception.message, fragment), exception.message);
    verifyTrue(testCase, contains(exception.message, ['Stage 0, Section ', section]), exception.message);
    verifyTrue(testCase, isequaln(s, before));
    return
end
verifyFail(testCase, ['Expected an actionable error for ', fragment]);
end

function s = fixture(root)
s.project_dir = root;
s.rawSET_dir = fullfile(root, 'raw');
s.processed_dir = fullfile(root, 'processed');
s.amplitudes_dir = fullfile(root, 'amplitudes');
s.utilities_dir = fullfile(root, 'resources');
s.study_name = 'synthetic';
s.rawBDF_dir = fullfile(root, 'bdf');
s.eeglab_dir = fullfile(root, 'eeglab');
s.recording_layout = 'EMG';
s.condition_triggers = {'S 001 ', '002'};
s.condition_names = {'first', 'second'};
s.emg_reference_mode = 'bipolar';
s.emg_channel_numbers = [1 2; 3 4];
s.emg_channel_names = {'CS', 'OO'};
s.do_shift_triggers = false;
s.shift_method = 20;
s.shift_markers = [];
s.shift_window = [-0.06 0.1];
s.shift_threshold = 4;
s.shift_minimum_duration_ms = 20;
s.do_filtering_main = true;
s.filter_type_main = 'highpass';
s.filter_cutoff_main = 20;
s.do_filtering_notch = false;
s.filter_cutoff_notch = 50;
s.do_downsampling = 1;
s.downsample_rate = 512;
s.do_rectifying = 1;
s.rectify_method = 'abs';
s.epoch_length = [-2 5];
s.do_artefact_detection_automatic = true;
s.artefact_threshold_baseline = 3;
s.artefact_threshold_trial = 3;
s.do_artefact_detection_manual = false;
s.do_baseline_correction = true;
s.baseline_correction_window = [-2000 -1000];
s.baseline_correction_method = 'division';
s.do_standardization_muscle = true;
s.do_standardization_subject = false;
s.feature_extraction_method = 'mav';
s.feature_extraction_bin_dur = 1000;
s.do_trial_averaging = false;
s.fname_raw_data = '_raw';
s.do_save_trial_rejection_stats = true;
s.fname_trial_rejection_stats = 'rejected.csv';
s.do_save_preprocessed_data = true;
s.fname_preprocessed_data = '_processed';
s.do_save_features_amplitudes = true;
s.do_save_rejected_trial_rows = true;
s.fname_feature_amplitudes = 'features.csv';
end
