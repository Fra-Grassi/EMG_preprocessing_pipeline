function tests = test_condition_label_creation
% Execute Stage 2 Section 2.4.2 verbatim with synthetic character events.
% The narrow eeg_checkset double does not sort or validate EEGLAB events.
% This covers orchestration, not real EEGLAB preprocessing. Under CD-11/12,
% each fixture runs the section once; repeated execution is not a contract.
% MATLAB R2024b, from the repository root:
% results = runtests('tests/test_condition_label_creation.m');
% assertSuccess(results);
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
source = fileread(fullfile(project_dir, ...
    'EMG_02_preprocessing_feature_extraction.m'));
testCase.TestData.code = source_between(source, ...
    '%% 2.4.2 - Add events with condition names', ...
    '%% 2.4.3 - Channel selection and re-referencing');
end

function testOneCopyPerMatchingOriginalWithAllMetadata(testCase)
EMG = event_fixture({'121', 'boundary', '122', '121', 'unmatched'});
sets.condition_triggers = {'122', '121'};
sets.condition_names = {'condition_b', 'condition_a'};

out = run_section(testCase.TestData.code, EMG, sets);

verify_copies(testCase, out, EMG, [1 3 4], ...
    {'condition_a', 'condition_b', 'condition_a'});
end

function testSpacesPrefixesAndLeadingZerosMatchExactly(testCase)
types = {'121', 'S 121', 'S121', '00121', '121 ', ' 121', ...
    'S  121', 's121', '0121', 'boundary'};
EMG = event_fixture(types);
% Each spelling must select only its exact original, with no trimming,
% prefix removal, numeric conversion, or case folding.
for selected = 1:6
    sets.condition_triggers = types(selected);
    sets.condition_names = {'condition_exact'};
    out = run_section(testCase.TestData.code, EMG, sets);
    verify_copies(testCase, out, EMG, selected, {'condition_exact'});
end
end

function testNoMatchingOriginalLeavesAllEventsUnchanged(testCase)
EMG = event_fixture({'S 121', 'S121', '00121', '121 ', ' 121', 'boundary'});
sets.condition_triggers = {'121'};
sets.condition_names = {'condition_a'};

out = run_section(testCase.TestData.code, EMG, sets);

verify_copies(testCase, out, EMG, [], {});
end

function testNewCopiesAreNotTreatedAsOriginalEvents(testCase)
% A label may itself spell another configured trigger. Only the initial
% event list is visited; this still runs the section just once (CD-12).
EMG = event_fixture({'121', '122', 'boundary'});
sets.condition_triggers = {'121', '122'};
sets.condition_names = {'122', 'condition_b'};

out = run_section(testCase.TestData.code, EMG, sets);

verify_copies(testCase, out, EMG, [1 2], {'122', 'condition_b'});
end

function verify_copies(testCase, out, original, source_indices, labels)
n_original = numel(original.event);
assertEqual(testCase, numel(out.event), n_original + numel(source_indices));
verifyEqual(testCase, out.event(1:n_original), original.event);
verifyEqual(testCase, fieldnames(out.event), fieldnames(original.event));
for k = 1:numel(source_indices)
    copy = out.event(n_original + k);
    source = original.event(source_indices(k));
    verifyEqual(testCase, copy.type, labels{k});
    verifyEqual(testCase, rmfield(copy, 'type'), rmfield(source, 'type'));
end
verifyEqual(testCase, out.condition_check_count, 1);
verifyEqual(testCase, rmfield(out, {'event', 'condition_check_count'}), ...
    rmfield(original, 'event'));
end

function EMG = run_section(code, EMG, sets) %#ok<INUSD>
% The production section reads sets through eval.
% Function-handle substitution is local to this evaluation workspace.
eeg_checkset = @checkset_double; %#ok<NASGU>
eval(code);
end

function EMG = checkset_double(EMG, option)
assert(strcmp(option, 'eventconsistency'), ...
    'Stage 2 must request event consistency after adding labels.');
assert(~isfield(EMG, 'condition_check_count'), ...
    'Expected one consistency call for this fresh fixture.');
% A test-only dataset field proves that the returned dataset is retained.
EMG.condition_check_count = 1;
end

function EMG = event_fixture(types)
template = struct('type', '', 'latency', 0, 'duration', 0, ...
    'urevent', 0, 'custom_label', '', 'custom_metadata', []);
events = repmat(template, 1, numel(types));
for k = 1:numel(types)
    events(k).type = types{k};
    events(k).latency = (numel(types) - k + 1) * 101.25;
    events(k).duration = k - 1;
    events(k).urevent = k + 20;
    events(k).custom_label = sprintf('source_%d', k);
    events(k).custom_metadata = struct('values', [k NaN], 'tag', {types(k)});
end
EMG = struct('event', events, 'subject', 'P007', 'data', [1 2 3]);
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test extraction boundaries.');
code = source(start_idx:stop_idx - 1);
end
