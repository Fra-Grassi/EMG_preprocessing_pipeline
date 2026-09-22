function tests = test_channel_selection
% Execute Stage 2 Section 2.4.3 verbatim with synthetic continuous and
% epoched data. This tests the explicit single/bipolar contract (CD-19)
% without requiring EEGLAB or participant data.
% MATLAB R2024b, from the repository root:
% results = runtests('tests/test_channel_selection.m');
% assertSuccess(results);
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
source = fileread(fullfile(project_dir, ...
    'EMG_02_preprocessing_feature_extraction.m'));
testCase.TestData.code = source_between(source, ...
    '%% 2.4.3 - Channel selection and re-referencing', ...
    '%% 2.4.4 - Filtering');
end

function testSingleRowVectorSelectsOrderAndMetadata(testCase)
original = recording_fixture();
sets = channel_settings('single', [4 2], {'CS', 'OO'});

out = run_section(testCase.TestData.code, original, sets);

verifyEqual(testCase, out.data, original.data([4 2], :, :));
verifyEqual(testCase, out.nbchan, 2);
expected_chanlocs = original.chanlocs([4 2]);
expected_chanlocs(1).labels = 'CS';
expected_chanlocs(2).labels = 'OO';
verifyEqual(testCase, out.chanlocs, expected_chanlocs);
verify_unrelated_fields(testCase, out, original);
end

function testSingleColumnVectorPreservesOrderAndDimensions(testCase)
original = recording_fixture();
sets = channel_settings('single', [3; 1], {'ZM', 'CS'});

out = run_section(testCase.TestData.code, original, sets);

verifyEqual(testCase, out.data, original.data([3 1], :, :));
verifyEqual(testCase, size(out.data), [2 3 2]);
verifyEqual(testCase, out.nbchan, 2);
verifyEqual(testCase, {out.chanlocs.labels}, {'ZM', 'CS'});
verifyEqual(testCase, [out.chanlocs.X], [30 10]);
verify_unrelated_fields(testCase, out, original);
end

function testMultiMuscleBipolarUsesFirstMinusSecond(testCase)
original = recording_fixture();
sets = channel_settings('bipolar', [4 1; 3 2], {'CS', 'OO'});

out = run_section(testCase.TestData.code, original, sets);

expected = original.data([4 3], :, :) - original.data([1 2], :, :);
verifyEqual(testCase, out.data, expected);
verifyEqual(testCase, size(out.data), [2 3 2]);
verifyEqual(testCase, out.nbchan, 2);
verifyEqual(testCase, {out.chanlocs.labels}, {'CS', 'OO'});
verifyEqual(testCase, fieldnames(out.chanlocs), {'labels'});
verify_unrelated_fields(testCase, out, original);
end

function testOneMuscleBipolarPairIsSupported(testCase)
original = recording_fixture();
sets = channel_settings('bipolar', [3 4], {'ZM'});

out = run_section(testCase.TestData.code, original, sets);

verifyEqual(testCase, out.data, ...
    original.data(3, :, :) - original.data(4, :, :));
verifyEqual(testCase, size(out.data), [1 3 2]);
verifyEqual(testCase, out.nbchan, 1);
verifyEqual(testCase, out.chanlocs, struct('labels', 'ZM'));
verify_unrelated_fields(testCase, out, original);
end

function testEmptyChannelLocationsStillProduceLabels(testCase)
original = recording_fixture();
original.chanlocs = struct([]);
sets = channel_settings('single', [4 2], {'CS', 'OO'});

out = run_section(testCase.TestData.code, original, sets);

verifyEqual(testCase, out.data, original.data([4 2], :, :));
verifyEqual(testCase, out.nbchan, 2);
verifyEqual(testCase, {out.chanlocs.labels}, {'CS', 'OO'});
verifyEqual(testCase, fieldnames(out.chanlocs), {'labels'});
end

function testOutOfRangeDataIndexFailsBeforeMutation(testCase)
original = recording_fixture();
sets = channel_settings('single', [2 5], {'CS', 'OO'});

[out, exception] = run_section_capturing_error( ...
    testCase.TestData.code, original, sets);

verifyEqual(testCase, exception.identifier, ...
    'EMG_pipeline:ChannelIndexOutOfRange');
verifyTrue(testCase, contains(exception.message, '4 recorded channels'));
verifyEqual(testCase, out, original);
end

function testInsufficientNonemptyChannelLocationsFailsBeforeMutation(testCase)
original = recording_fixture();
original.chanlocs = original.chanlocs(1:3);
sets = channel_settings('single', 4, {'CS'});

[out, exception] = run_section_capturing_error( ...
    testCase.TestData.code, original, sets);

verifyEqual(testCase, exception.identifier, ...
    'EMG_pipeline:InsufficientChannelLocations');
verifyTrue(testCase, contains(exception.message, 'requires channel 4'));
verifyEqual(testCase, out, original);
end

function EMG = run_section(code, EMG, sets) %#ok<INUSD>
% The production section reads sets through eval.
eval(code);
end

function [EMG, exception] = run_section_capturing_error(code, EMG, sets) %#ok<INUSD>
% Return the function-workspace EMG after failure to prove preflight errors
% occur before any dataset field is changed.
exception = [];
try
    eval(code);
catch exception
end
assert(~isempty(exception), 'Expected the production section to fail.');
end

function verify_unrelated_fields(testCase, out, original)
changed_fields = {'data', 'nbchan', 'chanlocs'};
verifyEqual(testCase, rmfield(out, changed_fields), ...
    rmfield(original, changed_fields));
end

function sets = channel_settings(mode, numbers, names)
sets.emg_reference_mode = mode;
sets.emg_channel_numbers = numbers;
sets.emg_channel_names = names;
end

function EMG = recording_fixture()
EMG.data = reshape(single(1:24), [4 3 2]);
EMG.nbchan = 4;
location_template = struct('labels', '', 'X', 0, 'Y', 0, ...
    'type', '', 'custom', struct());
EMG.chanlocs = repmat(location_template, 1, 4);
for channel = 1:4
    EMG.chanlocs(channel).labels = sprintf('source_%d', channel);
    EMG.chanlocs(channel).X = channel * 10;
    EMG.chanlocs(channel).Y = -channel;
    EMG.chanlocs(channel).type = sprintf('type_%d', channel);
    EMG.chanlocs(channel).custom = struct('source', channel, ...
        'values', [channel NaN]);
end
EMG.subject = 'P007';
EMG.srate = 512;
EMG.times = [-1 0 1];
EMG.event = struct('type', '121', 'latency', 2);
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test extraction boundaries.');
code = source(start_idx:stop_idx - 1);
end
