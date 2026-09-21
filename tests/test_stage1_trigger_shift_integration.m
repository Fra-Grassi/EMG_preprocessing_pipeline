function tests = test_stage1_trigger_shift_integration
% Execute Stage 1 Section 1.3.4 verbatim, production fixed-delay shifting,
% and real MAT serialization in disposable folders. Only eeg_checkset is
% replaced for enabled runs; no real EEGLAB preprocessing is validated.
% Contracts: exact character matching (CD-11), signed round offsets (CD-13),
% current settings (CD-16), and unchanged filename stems (CD-17).
% MATLAB R2024b, from the repository root:
% results = runtests('tests/test_stage1_trigger_shift_integration.m');
% assertSuccess(results);
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
source = fileread(fullfile(project_dir, 'EMG_01_raw2set_shift_triggers.m'));
testCase.TestData.code = source_between(source, ...
    '%% 1.3.4 - Shift triggers', '%% 1.3.5 - Add file info');

% The production helper resolves eeg_checkset on the path. Keep this narrow
% one-argument double private to this suite and restore paths on teardown.
mock_folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
mock_path = fullfile(mock_folder.Folder, 'eeg_checkset.m');
fid = fopen(mock_path, 'w');
assert(fid ~= -1, 'Could not create the disposable eeg_checkset double.');
close_file = onCleanup(@() fclose(fid));
fprintf(fid, 'function EEG = eeg_checkset(EEG)\nend\n');
clear close_file
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(project_dir));
testCase.applyFixture(matlab.unittest.fixtures.PathFixture(mock_folder.Folder));
assertEqual(testCase, which('shift_triggers'), fullfile(project_dir, 'shift_triggers.m'));
assertEqual(testCase, which('eeg_checkset'), mock_path);
end

function setup(testCase)
folder = testCase.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
testCase.TestData.output_dir = folder.Folder;
end

function testEmptyShiftMarkersFallBackToConditionTriggers(testCase)
EMG = recording_fixture();
sets = settings_fixture(testCase.TestData.output_dir);
sets.shift_markers = {};
% At 500 Hz, +3 ms rounds from +1.5 to +2 samples (not +3).
sets.shift_method = 3;
file = {'unused.bdf', '001.bdf'};

[out, diagnostics] = run_enabled(testCase.TestData.code, EMG, sets, file, 2);

verify_shift_and_save(testCase, out, EMG, diagnostics, sets, ...
    [1 3 4], 2, '001_trigger_shift_diagnostics.mat');
end

function testExplicitMarkersOverrideConditionTriggers(testCase)
EMG = recording_fixture();
sets = settings_fixture(testCase.TestData.output_dir);
sets.shift_markers = {'S 121', '00121'};
% At 500 Hz, -3 ms rounds from -1.5 to -2 samples (not -1).
sets.shift_method = -3;
file = {'unused.bdf', 'P007.session.bdf'};

[out, diagnostics] = run_enabled(testCase.TestData.code, EMG, sets, file, 2);

verify_shift_and_save(testCase, out, EMG, diagnostics, sets, ...
    [2 5], -2, 'P007.session_trigger_shift_diagnostics.mat');
end

function testDisabledDoesNotShiftOrWrite(testCase)
EMG = recording_fixture();
sets = settings_fixture(testCase.TestData.output_dir);
sets.do_shift_triggers = false;

[out, diagnostics] = run_disabled(testCase.TestData.code, EMG, sets);

verifyEqual(testCase, out, EMG);
verifyEqual(testCase, diagnostics, 'unchanged workspace diagnostics');
verifyEmpty(testCase, output_files(sets.rawSET_dir));
end

function testDisabledPreservesExistingDiagnosticsFile(testCase)
EMG = recording_fixture();
sets = settings_fixture(testCase.TestData.output_dir);
sets.do_shift_triggers = false;
diagnostics_path = fullfile(sets.rawSET_dir, '001_trigger_shift_diagnostics.mat');
trigger_shift_diagnostics = 'previous saved diagnostics';
save(diagnostics_path, 'trigger_shift_diagnostics');
bytes_before = read_bytes(diagnostics_path);

[out, diagnostics] = run_disabled(testCase.TestData.code, EMG, sets);

verifyEqual(testCase, out, EMG);
verifyEqual(testCase, diagnostics, 'unchanged workspace diagnostics');
verifyEqual(testCase, output_files(sets.rawSET_dir), {'001_trigger_shift_diagnostics.mat'});
verifyEqual(testCase, read_bytes(diagnostics_path), bytes_before);
end

function verify_shift_and_save(testCase, out, original, diagnostics, sets, indices, offset, filename)
expected = original;
for k = indices
    expected.event(k).latency = original.event(k).latency + offset;
end
expected.saved = 'no';
% Whole-dataset comparison proves Stage 1 retains the helper's return and
% preserves non-target events, event metadata, and the synthetic recording.
verifyEqual(testCase, out, expected);
verifyEqual(testCase, diagnostics.events.event_index, indices(:));
verifyEqual(testCase, diagnostics.events.event_type, {original.event(indices).type}');
verifyEqual(testCase, diagnostics.events.original_latency, [original.event(indices).latency]');
verifyEqual(testCase, diagnostics.events.corrected_latency, [out.event(indices).latency]');
verifyEqual(testCase, diagnostics.events.sample_offset, repmat(offset, numel(indices), 1));
verifyEqual(testCase, diagnostics.events.applied_delay_ms, ...
    repmat(sets.shift_method, numel(indices), 1));
verifyEqual(testCase, diagnostics.events.status, repmat("fixed", numel(indices), 1));
verifyEqual(testCase, diagnostics.method, sets.shift_method);
verifyEqual(testCase, diagnostics.srate, original.srate);
verifyEqual(testCase, diagnostics.divisor, sets.shift_threshold);
verifyEqual(testCase, diagnostics.minimum_duration_ms, sets.shift_minimum_duration_ms);

% Check the exact file name, directory, variable name, and serialized value.
assertEqual(testCase, output_files(sets.rawSET_dir), {filename});
saved = load(fullfile(sets.rawSET_dir, filename));
assertEqual(testCase, fieldnames(saved), {'trigger_shift_diagnostics'});
verifyEqual(testCase, saved.trigger_shift_diagnostics, diagnostics);
end

function [EMG, trigger_shift_diagnostics] = run_enabled(code, EMG, sets, file, si) %#ok<INUSD,STOUT>
% The production section reads inputs and assigns diagnostics through eval.
% No shift_triggers or save doubles: evaluate the untouched production code.
eval(code);
end

function [EMG, trigger_shift_diagnostics] = run_disabled(code, EMG, sets) %#ok<INUSD>
% The production section reads sets through eval.
file = {'unused.bdf', '001.bdf'}; %#ok<NASGU>
si = 2; %#ok<NASGU>
trigger_shift_diagnostics = 'unchanged workspace diagnostics';
% Fail even if an accidental call would return an unchanged dataset.
shift_triggers = @unexpected_shift; %#ok<NASGU>
eval(code);
end

function varargout = unexpected_shift(varargin) %#ok<STOUT>
error('test_stage1_trigger_shift_integration:UnexpectedShift', ...
    'Disabled Stage 1 shifting must not call shift_triggers.');
end

function sets = settings_fixture(output_dir)
sets.do_shift_triggers = true;
sets.shift_markers = {};
sets.condition_triggers = {'121', '122'};
sets.shift_method = 3;
sets.shift_window = [-.06 .1];
sets.shift_threshold = 7;
sets.shift_minimum_duration_ms = 12;
sets.rawSET_dir = output_dir;
end

function EMG = recording_fixture()
EMG = struct('srate', 500, 'pnts', 1000, 'trials', 1, ...
    'data', zeros(1, 1000), 'subject', 'synthetic', 'saved', 'yes');
EMG.event = struct('type', {'121', 'S 121', '122', '121', '00121', '121 ', 'S121'}, ...
    'latency', {100.25, 200.5, 300.75, 400.125, 500.25, 600.5, 700.75}, ...
    'duration', {0, 1, 2, 3, 4, 5, 6}, 'urevent', {11, 12, 13, 14, 15, 16, 17});
end

function names = output_files(folder)
entries = dir(folder);
names = sort({entries(~[entries.isdir]).name});
end

function bytes = read_bytes(filename)
fid = fopen(filename, 'rb');
assert(fid ~= -1, 'Could not read the disposable diagnostics file.');
close_file = onCleanup(@() fclose(fid));
bytes = fread(fid, Inf, '*uint8');
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test extraction boundaries.');
code = source(start_idx:stop_idx - 1);
end
