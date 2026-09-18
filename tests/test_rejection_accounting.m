function tests = test_rejection_accounting
% Execute production Stage 2 sections with synthetic epochs and EEGLAB doubles.
% Real tables/CSV I/O and feature calculations; no GUI, EEGLAB, or raw files.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
source = fileread(fullfile(project_dir, 'EMG_02_preprocessing_feature_extraction.m'));
testCase.TestData.prepare = source_between(source, ...
    '%% 2.3 - Prepare output variables', '%% 2.4 - Main loop');
start_idx = strfind(source, '%% 2.4.8 - Artefact detection');
assert(isscalar(start_idx));
% Remove only the outer participant loop's final end; the runner supplies it.
testCase.TestData.process = regexprep(source(start_idx:end), '\r?\nend\s*$', '');
end

function testAllRejectionModesAndIndependentRowToggle(testCase)
% Auto: trials 1 and 2. Manual: trial 3. Combined: union of all three.
modes = [1 0; 0 1; 1 1; 0 0];
expected_rejected = {[1 2], 3, [1 2 3], []};
for mode = 1:4
    for restore_rows = 0:double(any(modes(mode, :)))
        result = run_fixture(testCase.TestData, modes(mode, :), ...
            true, restore_rows, '', false);
        verifyEmpty(testCase, result.error);
        rejected = expected_rejected{mode};
        for si = 1:2
            observation = result.observations{si};
            % Saving the SET occurs before rejection; features use retained trials.
            verifyEqual(testCase, size(observation.saved.data, 3), 5);
            verifyEqual(testCase, [observation.saved.event.trial_number], 1:5);
            verifyEqual(testCase, [observation.retained.event.trial_number], ...
                setdiff(1:5, rejected));
            features = observation.features;
            if restore_rows
                verifyEqual(testCase, height(features), 10);
                verifyEqual(testCase, isnan(features.CS_MAV_raw), ...
                    ismember(features.trial_number, rejected));
                verifyEqual(testCase, isnan(features.CS_MAV_z_muscle), ...
                    ismember(features.trial_number, rejected));
            else
                verifyEqual(testCase, height(features), 2 * (5 - numel(rejected)));
                verifyFalse(testCase, any(ismember(features.trial_number, rejected)));
            end
            retained_rows = ~ismember(features.trial_number, rejected);
            expected_mav = 5 * features.trial_number(retained_rows) - 1 ...
                - 2.5 * (features.bin(retained_rows) == 1);
            verifyEqual(testCase, features.CS_MAV_raw(retained_rows), expected_mav);
            reference = 5 * setdiff(1:5, rejected) - 1;
            verifyEqual(testCase, features.CS_MAV_z_muscle(retained_rows), ...
                (expected_mav - mean(reference)) / std(reference, 0), 'AbsTol', 1e-12);
            if any(modes(mode, :))
                verifyEqual(testCase, find(observation.saved.reject.rejglobal), rejected);
                stats = observation.stats;
                verifyClass(testCase, stats.subject_ID, 'string');
                verifyEqual(testCase, stats.subject_ID, result.ids(1:si));
                verifyEqual(testCase, stats.Properties.VariableNames, ...
                    {'subject_ID', 'n_rejected_total', 'n_rejected_z', ...
                    'n_rejected_absent', 'n_rejected_a', 'perc_rejected_total', ...
                    'perc_rejected_z', 'perc_rejected_absent', 'perc_rejected_a'});
                verifyEqual(testCase, stats.n_rejected_total, repmat(numel(rejected), si, 1));
                verifyEqual(testCase, stats.perc_rejected_total, ...
                    repmat(numel(rejected)/5, si, 1), 'AbsTol', 1e-12);
                verifyEqual(testCase, stats.perc_rejected_z, ...
                    repmat(numel(rejected)/3, si, 1), 'AbsTol', 1e-12);
                verifyTrue(testCase, all(isnan(stats.n_rejected_absent)));
                verifyTrue(testCase, all(isnan(stats.perc_rejected_absent)));
                verifyEqual(testCase, stats.n_rejected_a, zeros(si, 1));
                verifyEqual(testCase, stats.perc_rejected_a, zeros(si, 1));
                verifyEqual(testCase, height(observation.stats_csv), si);
                verifyEqual(testCase, observation.stats_csv.subject_ID, result.ids(1:si));
                verifyTrue(testCase, all(isnan(observation.stats_csv.n_rejected_absent)));
                verifyTrue(testCase, all(isnan(observation.stats_csv.perc_rejected_absent)));
            else
                verifyFalse(testCase, observation.stats_exists);
            end
        end
        verifyEqual(testCase, unique(result.feature_csv.subject_ID), sort(result.ids));
    end
end
end

function testDisabledStatisticsDoesNotWriteOrOverwrite(testCase)
for mode = {[1 0], [0 1], [1 1], [0 0]}
    result = run_fixture(testCase.TestData, mode{1}, false, false, '', false);
    verifyEmpty(testCase, result.error);
    verifyFalse(testCase, result.observations{2}.stats_exists);
    result = run_fixture(testCase.TestData, mode{1}, false, false, 'existing_csv', false);
    verifyEmpty(testCase, result.error);
    verifyEqual(testCase, result.final_csv_text, 'existing checkpoint');
end
% Detection disabled also suppresses writes when the stats toggle is enabled.
result = run_fixture(testCase.TestData, [0 0], true, false, 'existing_csv', false);
verifyEmpty(testCase, result.error);
verifyEqual(testCase, result.final_csv_text, 'existing checkpoint');
% Restoring missing feature rows does not turn statistics saving back on.
result = run_fixture(testCase.TestData, [1 1], false, true, '', false);
verifyEmpty(testCase, result.error);
verifyFalse(testCase, result.stats_exists);
verifyEqual(testCase, height(result.feature_csv), 20);
end

function testStatisticsSavedAtEndOfDetectionSection(testCase)
result = run_fixture(testCase.TestData, [1 1], true, false, 'rejection_only', false);
verifyEmpty(testCase, result.error);
verifyEqual(testCase, result.final_stats.subject_ID, "001");
verifyEqual(testCase, result.final_stats.n_rejected_total, 3);
verifyEmpty(testCase, result.rejection_tables{2});
verifyFalse(testCase, result.feature_exists);
end

function testLaterProcessingFailureKeepsCurrentRejectionRow(testCase)
result = run_fixture(testCase.TestData, [1 1], true, false, 'standardization', false);
verifyEqual(testCase, result.error.identifier, 'standardize_mav_features:InvalidReference');
verifyEqual(testCase, result.final_stats.subject_ID, result.ids);
verifyEqual(testCase, result.final_stats.n_rejected_total, [3; 3]);
verifyEqual(testCase, result.final_stats(1, :), result.observations{1}.stats_csv);
verifyEqual(testCase, result.rejection_tables{2}.subject_ID, "P007");
verifyEqual(testCase, result.feature_csv.subject_ID, ...
    repmat("001", height(result.feature_csv), 1));
end

function testFeatureSaveFailureKeepsCurrentRejectionRow(testCase)
result = run_fixture(testCase.TestData, [1 0], true, false, 'feature_save', false);
verifyNotEmpty(testCase, result.error);
verifyEqual(testCase, result.final_stats.subject_ID, result.ids);
verifyEqual(testCase, result.final_stats.n_rejected_total, [2; 2]);
verifyEqual(testCase, result.final_stats(1, :), result.observations{1}.stats_csv);
verifyEqual(testCase, result.rejection_tables{2}.subject_ID, "P007");
verifyEqual(testCase, unique(result.feature_csv.subject_ID), "001");
end

function testFirstParticipantFeatureFailureKeepsRejectionRow(testCase)
result = run_fixture(testCase.TestData, [1 0], true, false, 'first_participant', false);
verifyEqual(testCase, result.error.identifier, 'standardize_mav_features:InvalidReference');
verifyEqual(testCase, result.final_stats.subject_ID, "001");
verifyEqual(testCase, result.final_stats.n_rejected_total, 2);
verifyEmpty(testCase, result.rejection_tables{2});
verifyFalse(testCase, result.feature_exists);
end

function testSectionExecutionMatchesContinuousExecution(testCase)
continuous = run_fixture(testCase.TestData, [1 1], true, true, '', false);
sections = run_fixture(testCase.TestData, [1 1], true, true, '', true);
verifyEmpty(testCase, continuous.error);
verifyEmpty(testCase, sections.error);
verifyEqual(testCase, sections.final_csv_text, continuous.final_csv_text);
verifyEqual(testCase, sections.feature_csv, continuous.feature_csv);
end

function testStatisticsWithFeatureSavingDisabled(testCase)
result = run_fixture(testCase.TestData, [0 1], true, false, 'no_feature_save', false);
verifyEmpty(testCase, result.error);
verifyFalse(testCase, result.feature_exists);
verifyEqual(testCase, height(result.observations{2}.stats_csv), 2);
end

function result = run_fixture(code, mode, save_stats, restore_rows, scenario, by_section)
output_dir = tempname;
mkdir(output_dir);
cleanup = onCleanup(@() rmdir(output_dir, 's')); %#ok<NASGU>
sets.condition_names = {'z', 'absent', 'a'}; % Intentionally not alphabetical.
sets.emg_channel_names = {'CS'};
sets.epoch_length = [-1 1];
sets.do_artefact_detection_automatic = mode(1);
sets.do_artefact_detection_manual = mode(2);
sets.artefact_threshold_baseline = 3;
sets.artefact_threshold_trial = 3;
sets.do_baseline_correction = false;
sets.do_save_preprocessed_data = true;
sets.fname_preprocessed_data = '_preprocessed';
sets.feature_extraction_bin_dur = 1000;
sets.do_standardization_muscle = true;
sets.do_standardization_subject = false;
sets.do_trial_averaging = false;
sets.do_save_rejected_trial_rows = restore_rows;
sets.do_save_features_amplitudes = ~strcmp(scenario, 'no_feature_save');
sets.do_save_trial_rejection_stats = save_stats;
sets.processed_dir = output_dir;
sets.amplitudes_dir = output_dir;
sets.fname_feature_amplitudes = 'features.csv';
sets.fname_trial_rejection_stats = 'rejections.csv';
stats_path = fullfile(output_dir, sets.fname_trial_rejection_stats);
feature_path = fullfile(output_dir, sets.fname_feature_amplitudes);
if strcmp(scenario, 'existing_csv')
    fid = fopen(stats_path, 'w');
    fprintf(fid, 'existing checkpoint');
    fclose(fid);
end
file = {'001_raw.set', 'P007_raw.set'}; %#ok<NASGU>
result.ids = ["001"; "P007"];
result.observations = cell(2, 1);
result.error = [];
eval(code.prepare);
for si = 1:2
    subj_ID = char(result.ids(si));
    EMG.subject = subj_ID;
    EMG.data = reshape(1:25, [1 5 5]);
    EMG.times = [-1000 -500 0 500 1000];
    EMG.chanlocs = struct('labels', 'CS');
    EMG.event = struct('type', {'z', 'z', 'z', 'a', 'a'}, ...
        'trial_number', num2cell(1:5));
    EMG.epoch = repmat(struct('event', 1), 1, 5);
    EMG.reject = struct();
    if (si == 2 && strcmp(scenario, 'standardization')) || ...
            strcmp(scenario, 'first_participant')
        EMG.data(:) = 1; % Real production validation fails AFTER stats construction.
    end
    if si == 2 && strcmp(scenario, 'feature_save')
        sets.amplitudes_dir = fullfile(output_dir, 'nonexistent_directory');
    end
    try
        if strcmp(scenario, 'rejection_only')
            eval(source_between(code.process, '%% 2.4.8 - Artefact detection', ...
                '%% 2.4.9 - Baseline correction'));
            break % Inspect the checkpoint before any feature processing begins.
        elseif by_section
            sections = regexp(code.process, '(?m)(?=^\s*%% 2\.4\.)', 'split');
            for section = 1:numel(sections)
                eval(sections{section});
            end
        else
            eval(code.process);
        end
    catch exception
        result.error = exception;
        break
    end
    observation.saved = saved_dataset;
    observation.retained = EMG;
    observation.features = participant_features_table;
    observation.stats_exists = isfile(stats_path);
    if save_stats && any(mode)
        observation.stats = reject_info_table;
        observation.stats_csv = read_csv(stats_path);
        observation.csv_text = fileread(stats_path);
    end
    result.observations{si} = observation;
end
result.stats_exists = isfile(stats_path);
result.final_csv_text = '';
if result.stats_exists
    result.final_csv_text = fileread(stats_path);
    if save_stats && any(mode)
        result.final_stats = read_csv(stats_path);
    end
end
if any(mode)
    result.rejection_tables = participant_rejection_tables;
end
result.feature_exists = isfile(feature_path);
if result.feature_exists
    result.feature_csv = read_csv(feature_path);
end
end

function data = read_csv(path)
options = detectImportOptions(path, 'TextType', 'string');
options = setvartype(options, 'subject_ID', 'string');
% All-missing CSV columns cannot reliably convey their numeric type alone.
numeric_stats = startsWith(options.VariableNames, 'n_rejected_') | ...
    startsWith(options.VariableNames, 'perc_rejected_');
if any(numeric_stats)
    options = setvartype(options, options.VariableNames(numeric_stats), 'double');
end
data = readtable(path, options);
end

function EMG = pop_epoch(EMG, ~, window, varargin)
% Existing epochs are the fixture; only mark which automatic pass is called.
assert(isequal(varargin, {'epochinfo', 'yes'}));
EMG.test_baseline = window(1) < 0;
end

function EMG = pop_jointprob(EMG, varargin)
assert(varargin{3} == 3 && varargin{4} == 3, 'Threshold arguments changed.');
assert(varargin{6} == 0, 'Automatic detection must flag without removing trials.');
EMG.reject.rejjp = false(1, 5);
EMG.reject.rejjp(2 - double(EMG.test_baseline)) = true;
end

function pop_rejmenu(EEG, ~)
% Simulate a reviewer flagging trial 3, retaining any automatic marks.
EEG.reject.rejmanual = [false false true false false];
assignin('caller', 'EEG', EEG);
end

function eeglab(varargin) %#ok<INUSD>
% No GUI during tests.
end

function uiwait
end

function close(varargin) %#ok<INUSD>
% Do not close the researcher's real figures when production calls close all.
end

function EMG = eeg_rejsuperpose(EMG, varargin)
assert(isequal([varargin{:}], ones(1, 8)));
EMG.reject.rejglobal = false(1, 5);
for field = {'rejjp', 'rejmanual'}
    if isfield(EMG.reject, field{1})
        EMG.reject.rejglobal = EMG.reject.rejglobal | EMG.reject.(field{1});
    end
end
end

function EMG = pop_saveset(EMG, varargin)
assert(isequal(varargin, {'filename', EMG.filename, 'filepath', EMG.filepath}));
assignin('caller', 'saved_dataset', EMG);
end

function EMG = pop_rejepoch(EMG, rejected, ~)
EMG.data = EMG.data(:, :, ~rejected);
EMG.event = EMG.event(~rejected);
EMG.epoch = EMG.epoch(~rejected);
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test boundaries.');
code = source(start_idx:stop_idx - 1);
end
