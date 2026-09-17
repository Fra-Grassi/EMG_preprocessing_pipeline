function tests = test_file_selection_identity
% Exercise production sections with in-memory dialog/import/load/save doubles.
% No EEGLAB, GUI, participant files, or output directories are used.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.stage1 = fileread(fullfile(project_dir, ...
    'EMG_01_raw2set_shift_triggers.m'));
testCase.TestData.stage2 = fileread(fullfile(project_dir, ...
    'EMG_02_preprocessing_feature_extraction.m'));
end

function testCancellationReturnsBeforeRemainingStage(testCase)
sources = {testCase.TestData.stage1, testCase.TestData.stage2};
starts = {'%% 1.2 - Select raw files', '%% 2.2 - Select input data'};
for stage = 1:2
    % Run the actual stage from its dialog through EOF. Cancellation must
    % return before any downstream preparation, participant load, or save.
    source = sources{stage};
    start_idx = strfind(source, starts{stage});
    [file, selected_dir, reached_end] = run_selection( ...
        source(start_idx:end), stage, 0, 0);
    verifyFalse(testCase, reached_end);
    verifyEqual(testCase, file, {});
    verifyEqual(testCase, selected_dir, 0);
    % The production loop's length(file) is also zero if a user later runs
    % the loop section after cancelling; it cannot reuse a prior selection.
    verifyEqual(testCase, length(file), 0);
end
end

function testSingleAndMultipleSelections(testCase)
sources = {testCase.TestData.stage1, testCase.TestData.stage2};
starts = {'%% 1.2 - Select raw files', '%% 2.2 - Select input data'};
stops = {'%% 1.3 - Convert files', '%% 2.3 - Prepare output variables'};
names = {{'001.bdf', '002.bdf'}, {'001_raw.set', '002_raw.set'}};
selected_dir = fullfile(tempdir, 'selected elsewhere');
for stage = 1:2
    code = source_between(sources{stage}, starts{stage}, stops{stage});
    for n_selected = 1:2
        selected_files = names{stage}(1:n_selected);
        if n_selected == 1
            dialog_files = selected_files{1};
        else
            dialog_files = selected_files;
        end
        [file, actual_dir, reached_end] = run_selection( ...
            code, stage, dialog_files, selected_dir);
        verifyTrue(testCase, reached_end);
        verifyEqual(testCase, file, selected_files);
        verifyEqual(testCase, actual_dir, selected_dir);
    end
end
end

function testStemAndSelectedDirectoriesThroughBothStages(testCase)
% Test the actual load/metadata/save statements and Stage 2 table key.
% The doubles validate loader arguments, but do not serialize EEGLAB SETs.
ids = {'001', '002', 'P007'};
suffixes = {'_raw', '_custom'};
for i = 1:numel(ids)
    for j = 1:numel(suffixes)
        result = run_identity_path(testCase.TestData.stage1, ...
            testCase.TestData.stage2, [ids{i} '.bdf'], suffixes{j});
        verifyClass(testCase, result.imported.subject, 'char');
        verifyEqual(testCase, result.imported.subject, ids{i});
        verifyEqual(testCase, result.imported.filename, ...
            [ids{i} suffixes{j} '.set']);
        verifyEqual(testCase, result.loaded.subject, ids{i});
        verifyEqual(testCase, result.subj_ID, ids{i});
        verifyClass(testCase, result.feature_ids, 'string');
        verifyEqual(testCase, result.feature_ids, repmat(string(ids{i}), 2, 1));
    end
end
end

function [file, thissubjectpath, reached_end] = run_selection(code, stage, selected_files, selected_dir)
sets.rawBDF_dir = fullfile(tempdir, 'configured BDF start');
sets.rawSET_dir = fullfile(tempdir, 'configured SET start');
if stage == 1
    expected_filter = fullfile(sets.rawBDF_dir, '*.bdf');
else
    expected_filter = fullfile(sets.rawSET_dir, '*_raw.set');
end
uigetfile = @(filter, varargin) dialog_double( ...
    filter, expected_filter, selected_files, selected_dir, varargin{:}); %#ok<NASGU>
file = {'stale_selection'};
thissubjectpath = 'stale_directory';
reached_end = false;
% Keep the completion marker inside the evaluated code so an early return
% cannot be mistaken for successful execution of the remaining statements.
eval([code newline 'reached_end = true;']);
end

function [file, selected_dir] = dialog_double(filter, expected_filter, file, selected_dir, varargin)
assert(strcmp(filter, expected_filter), 'The configured directory must remain the dialog start.');
assert(isequal(varargin, {'MultiSelect', 'on'}));
end

function result = run_identity_path(stage1, stage2, raw_filename, raw_suffix)
sets.rawBDF_dir = fullfile(tempdir, 'unused BDF start');
sets.rawSET_dir = fullfile(tempdir, 'configured SET output');
sets.fname_raw_data = raw_suffix;
file = {raw_filename};
si = 1;
thissubjectpath = fullfile(tempdir, 'selected BDF directory');
expected_bdf = fullfile(thissubjectpath, raw_filename);
pop_biosig = @(actual_path) import_double(actual_path, expected_bdf); %#ok<NASGU>
eval(source_between(stage1, '%% 1.3.1 - Load raw file', ...
    '%% 1.3.2 - Convert event types'));
eval(source_between(stage1, '%% 1.3.5 - Add file info', ...
    '%% 1.3.6 - Save SET file'));
pop_saveset = @(dataset, varargin) save_double(dataset, varargin{:}); %#ok<NASGU>
eval(source_between(stage1, '    EMG = pop_saveset(', ...
    '    fprintf(['));
result.imported = EMG;

% A renamed SET in another directory must still use the saved subject.
file = {'renamed_raw.set'};
thissubjectpath = fullfile(tempdir, 'selected SET directory');
pop_loadset = @(varargin) load_double(result.imported, ...
    file{1}, thissubjectpath, varargin{:}); %#ok<NASGU>
eval(source_between(stage2, '%% 2.4.1 - Load dataset', ...
    '%% 2.4.2 - Add events'));
result.loaded = EMG;
result.subj_ID = subj_ID;

% Minimal already-computed feature rows exercise the unchanged production
% table constructor without running preprocessing or numerical extraction.
participant_conditions = ["condition_a"; "condition_a"]; %#ok<NASGU>
participant_trials = [1; 1]; %#ok<NASGU>
participant_bins = [1; 2]; %#ok<NASGU>
eval(source_between(stage2, '    participant_features_table = table(', ...
    '    % Add adjacent unstandardized'));
result.feature_ids = participant_features_table.subject_ID;
end

function EMG = import_double(actual_path, expected_path)
assert(strcmp(actual_path, expected_path), 'Stage 1 must load from the selected directory.');
EMG = struct('subject', 'old metadata');
end

function EMG = save_double(EMG, varargin)
assert(isequal(varargin, {'filename', EMG.filename, 'filepath', EMG.filepath}));
end

function EMG = load_double(EMG, expected_filename, expected_dir, varargin)
assert(isequal(varargin, {'filename', expected_filename, 'filepath', expected_dir}), ...
    'Stage 2 must load from the selected directory.');
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test extraction boundaries.');
code = source(start_idx:stop_idx - 1);
end
