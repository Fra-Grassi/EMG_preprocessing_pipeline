function tests = test_shift_triggers_production
% Executes production shift_triggers, with five EEGLAB operations stubbed.
% Validates integration arithmetic/mapping; NOT actual EEG preprocessing.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.path = path;
tests_dir = fileparts(mfilename('fullpath'));
addpath(fileparts(tests_dir));
addpath(fullfile(tests_dir, 'mocks', 'trigger_shift'), '-begin');
testCase.TestData.warning = warning('query', 'shift_triggers:MedianFallback');
warning('off', 'shift_triggers:MedianFallback');
end

function teardownOnce(testCase)
path(testCase.TestData.path);
warning(testCase.TestData.warning);
clear global TRIGGER_SHIFT_TEST
end

function setup(~)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST = struct('times', [-40 -20 0 10 20 30 40 50], ...
    'data', [0 0 0 8 8 8 0 0; 0 0 0 0 0 9 9 9], 'accepted', [1 2]);
end

function testFixedSignedRoundingAndExactCodes(testCase)
EEG = fixture();
for delay = [1, -1, 0, .4]
    [out, audit] = shift_triggers(EEG, {'121'}, delay);
    expected_offset = round(delay*.5);
    verifyEqual(testCase, out.event(2).latency, 200.25 + expected_offset);
    verifyEqual(testCase, out.event([1 3 4 5]), EEG.event([1 3 4 5]));
    verifyEqual(testCase, rmfield(out.event, 'latency'), rmfield(EEG.event, 'latency'));
    verifyEqual(testCase, audit.events.sample_offset, expected_offset);
end
end

function testVariableDistinctIdentityAndPairedData(testCase)
global TRIGGER_SHIFT_TEST
EEG = fixture();
[out, d] = shift_triggers(EEG, {'121', 'S121'}, 'variable', [-.06 .1], 4, 4, false);
% Input event 1 occurs AFTER event 2. Accepted candidate 1 is original event 2.
verifyEqual(testCase, d.events.event_index, [1;2]);
verifyEqual(testCase, d.events.measured_delay_ms, [30;10]);
verifyEqual(testCase, [out.event(1:2).latency], [815.75 205.25]);
verifyEqual(testCase, d.paired.event_index, [2;1]);
verifyEqual(testCase, d.paired.after_times_ms, TRIGGER_SHIFT_TEST.times' - [10 30]);
verifyEqual(testCase, d.paired.data, TRIGGER_SHIFT_TEST.data');
verifyEmpty(testCase, TRIGGER_SHIFT_TEST.requested_types);
verifyEqual(testCase, d.events.corrected_latency, [815.75;205.25]);
end

function testMedianBeforeOffsetRounding(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.times = [-40 -20 0 1 2 3 4];
TRIGGER_SHIFT_TEST.data = [0 0 8 8 0 0 0;0 0 0 8 8 0 0];
[out,d] = shift_triggers(fixture(), {'121','S121'}, 'median', [-.06 .1], 4, 2, false);
verifyEqual(testCase, d.median_delay_ms, .5);
verifyEqual(testCase, d.events.applied_delay_ms, [.5;.5]);
verifyEqual(testCase, d.events.sample_offset, [0;0]);
verifyEqual(testCase, [out.event(1:2).latency], [800.75 200.25]);
end

function testFallbackForMissingCrossingAndFlat(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.accepted = [1 2 3];
TRIGGER_SHIFT_TEST.data = [0 0 0 8 8 8 0 0; zeros(1,8); 0 0 0 8 0 0 0 0];
[~,d] = shift_triggers(fixture(), {'121','S121','S 121'}, 'variable', [-.06 .1], 4, 4, false);
verifyEqual(testCase, d.successful_count, 1);
verifyEqual(testCase, d.events.applied_delay_ms, [10;10;10]);
verifyEqual(testCase, d.events.status, ["no_crossing";"detected";"zero_range"]);
verifyTrue(testCase, isnan(d.events.measured_delay_ms(1)));
end

function testOmittedAcceptedPositionsAndWarning(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.accepted = 2;
TRIGGER_SHIFT_TEST.data = [0 0 0 8 8 8 0 0];
warning('on', 'shift_triggers:MedianFallback');
cleanup = onCleanup(@() warning('off', 'shift_triggers:MedianFallback'));
verifyWarning(testCase, @() shift_triggers(fixture(), {'121','S121'}, ...
    'variable', [-.06 .1], 4, 4, false), 'shift_triggers:MedianFallback');
[~,d] = shift_triggers(fixture(), {'121','S121'}, 'variable', [-.06 .1], 4, 4, false);
verifyEqual(testCase, d.events.status, ["detected";"omitted_epoch"]);
verifyEqual(testCase, d.paired.event_index, 1);
end

function testDurationAcrossRates(testCase)
global TRIGGER_SHIFT_TEST
for rate = [500 512 1000]
    EEG = fixture(); EEG.srate = rate;
    TRIGGER_SHIFT_TEST.times = (-20:30)*1000/rate;
    TRIGGER_SHIFT_TEST.data = [zeros(1,21) ones(1,10) zeros(1,20); ...
        zeros(1,22) ones(1,20) zeros(1,9)];
    [~,d] = shift_triggers(EEG, {'121','S121'}, 'variable', [-.06 .1], 4, 20, false);
    verifyEqual(testCase, d.minimum_run_samples, ceil(.02*rate));
    verifyEqual(testCase, d.successful_count, 1 + double(rate == 500));
end
end

function testZeroAnchorPositiveTieAndNearestNegative(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.times = [-40 -20 -.5 .5 1.5 2.5];
TRIGGER_SHIFT_TEST.data = [0 0 8 8 8 0;0 0 8 8 8 0];
[~,d] = shift_triggers(fixture(), {'121','S121'}, 'variable', [-.06 .1], 4, 2, false);
verifyEqual(testCase, d.zero_anchor_index, 4);
verifyEqual(testCase, d.events.measured_delay_ms, [.5;.5]);
TRIGGER_SHIFT_TEST.times(3) = -.25;
[~,d] = shift_triggers(fixture(), {'121','S121'}, 'variable', [-.06 .1], 4, 2, false);
verifyEqual(testCase, d.zero_anchor_index, 3);
verifyEqual(testCase, d.events.measured_delay_ms, [-.25;-.25]);
end

function testBoundaryPreflightMapping(testCase)
global TRIGGER_SHIFT_TEST
EEG = fixture(); EEG.event(2).latency = 2;
TRIGGER_SHIFT_TEST.accepted = 1;
TRIGGER_SHIFT_TEST.data = [0 0 0 8 8 8 0 0];
[~,d] = shift_triggers(EEG, {'121','S121'}, 'variable', [-.06 .1], 4, 4, false);
verifyEqual(testCase, d.events.status, ["detected";"recording_boundary"]);
EEG = fixture(); EEG.event(4).type = 'boundary'; EEG.event(4).latency = 210;
[~,d] = shift_triggers(EEG, {'121','S121'}, 'variable', [-.06 .1], 4, 4, false);
verifyEqual(testCase, d.events.status, ["detected";"discontinuity"]);
end

function testMissingChannelAndNoValidDetection(testCase)
global TRIGGER_SHIFT_TEST
EEG = fixture(); EEG.chanlocs.labels = 'EMG';
verifyError(testCase, @() shift_triggers(EEG, {'121'}, 'variable', [-.06 .1]), 'shift_triggers:MissingChannel');
TRIGGER_SHIFT_TEST.data(:) = 0;
verifyError(testCase, @() shift_triggers(fixture(), {'121','S121'}, 'median', [-.06 .1]), 'shift_triggers:NoDetections');
EEG = fixture(); EEG.event(2).latency = 2;
verifyError(testCase, @() shift_triggers(EEG, {'121'}, 'variable', [-.06 .1]), 'shift_triggers:NoDetections');
end

function testOutOfBoundsNoClipping(testCase)
EEG = fixture();
verifyError(testCase, @() shift_triggers(EEG, {'121'}, -1000), 'shift_triggers:OutOfBounds');
verifyError(testCase, @() shift_triggers(EEG, {'121'}, 3000), 'shift_triggers:OutOfBounds');
end

function testInvalidAcceptedMapping(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.accepted = [1 1];
verifyError(testCase, @() shift_triggers(fixture(), {'121','S121'}, ...
    'variable', [-.06 .1], 4, 4, false), 'shift_triggers:EpochMapping');
end

function testDefaultDurationAndConfigurableDivisor(testCase)
global TRIGGER_SHIFT_TEST
TRIGGER_SHIFT_TEST.times = (-20:30)*2;
TRIGGER_SHIFT_TEST.data = [zeros(1,21) ones(1,10)*2 ones(1,10)*8 zeros(1,10); ...
    zeros(1,21) ones(1,10)*2 ones(1,10)*8 zeros(1,10)];
[~,d] = shift_triggers(fixture(), {'121','S121'}, 'variable', [-.06 .1], [], [], false);
verifyEqual(testCase, d.minimum_run_samples, 10);
verifyEqual(testCase, d.events.measured_delay_ms, [2;2]);
[~,d] = shift_triggers(fixture(), {'121','S121'}, 'variable', [-.06 .1], 2, [], false);
verifyEqual(testCase, d.events.measured_delay_ms, [22;22]);
end

function EEG = fixture()
EEG = struct('srate',500,'pnts',1000,'trials',1,'data',zeros(1,1000), ...
    'chanlocs',struct('labels','photodiode'));
EEG.event = struct('type', {'S121','121','S 121','121 ','00121'}, ...
    'latency', {800.75,200.25,500.5,600.5,700.25}, 'duration', {1,2,3,4,5});
end
