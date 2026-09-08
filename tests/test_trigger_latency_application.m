function tests = test_trigger_latency_application
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.original_path = path;
addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testFixedPositiveNegativeAndZero(testCase)
events = fixture();
for delay = [10, -10, 0]
    [out, audit] = apply_trigger_delays_reference(events, {'121'}, delay, 500);
    verifyEqual(testCase, [out.latency], ...
        [100.25 + delay / 2, 200.75, 300.125, 400.5, 500.25 + delay / 2, 600.75]);
    verifyEqual(testCase, audit.event_index, [1; 5]);
    verifyEqual(testCase, audit.delay_ms, [delay; delay]);
end
end

function testFractionalOffsetsAndHalfTies(testCase)
events = fixture();
% At 500 Hz these become +/-0.5, +/-1.5 and +/-0.49 samples.
[out, audit] = apply_trigger_delays_reference(events, ...
    {'121', 'S 121', 'S121', 'boundary', '00121'}, ...
    [1, -1, 3, -3, 0.98, -0.98], 500, 1:6);
verifyEqual(testCase, audit.sample_offset, [1; -1; 2; -2; 0; 0]);
verifyEqual(testCase, [out.latency], ...
    [101.25, 199.75, 302.125, 398.5, 500.25, 600.75]);
end

function testExactCharacterContent(testCase)
events = fixture();
codes = {'121', 'S 121', 'S121', '00121'};
indices = {[1, 5], 2, 3, 6};
for k = 1:numel(codes)
    [out, audit] = apply_trigger_delays_reference(events, codes(k), 2, 1000);
    expected = [events.latency];
    expected(indices{k}) = expected(indices{k}) + 2;
    verifyEqual(testCase, [out.latency], expected);
    verifyEqual(testCase, audit.event_index, indices{k}(:));
    verifyEqual(testCase, {out.type}, {events.type});
end
end

function testExplicitMappingControlsDistinctDelays(testCase)
events = fixture();
original = events;
% Deliberately neither chronological nor grouped by event type.
mapping = [5, 2, 1, 3];
[out, audit] = apply_trigger_delays_reference(events, ...
    {'121', 'S 121', 'S121'}, [30, -10, 0, 6], 500, mapping);
verifyEqual(testCase, [out.latency], ...
    [100.25, 195.75, 303.125, 400.5, 515.25, 600.75]);
verifyEqual(testCase, audit.event_index, mapping');
verifyEqual(testCase, audit.original_latency, [500.25; 200.75; 100.25; 300.125]);
verifyEqual(testCase, audit.corrected_latency, [515.25; 195.75; 100.25; 303.125]);
verifyEqual(testCase, audit.sample_offset, [15; -5; 0; 3]);
verifyEqual(testCase, audit.event_type, {'121'; 'S 121'; '121'; 'S121'});
verifyEqual(testCase, audit.corrected_latency, ...
    reshape([out(mapping).latency], [], 1));
verifyEqual(testCase, audit.corrected_latency - audit.original_latency, audit.sample_offset);
verifyEqual(testCase, out([4, 6]), events([4, 6]));
verifyEqual(testCase, rmfield(out, 'latency'), rmfield(events, 'latency'));
verifyEqual(testCase, fieldnames(out), fieldnames(events));
verifyEqual(testCase, events, original);
end

function testNoSortingWhenLatenciesCross(testCase)
events = fixture();
events = events(:);
out = apply_trigger_delays_reference(events, {'121'}, [500, -450], 1000, [1, 5]);
verifySize(testCase, out, size(events));
verifyEqual(testCase, [out.latency], [600.25, 200.75, 300.125, 400.5, 50.25, 600.75]);
verifyEqual(testCase, rmfield(out, 'latency'), rmfield(events, 'latency'));
end

function testMappingCountsFailBeforeReturningChanges(testCase)
events = fixture();
original = events;
for delays = {[1, 2, 3], 1}
    verifyError(testCase, @() apply_trigger_delays_reference( ...
        events, {'121'}, delays{1}, 1000, [1, 5]), ...
        'apply_trigger_delays_reference:CountMismatch');
end
verifyError(testCase, @() apply_trigger_delays_reference( ...
    events, {'121'}, [1, 2], 1000), ...
    'apply_trigger_delays_reference:MappingRequired');
verifyEqual(testCase, events, original);
end

function testCountEqualityDoesNotAllowWrongTargets(testCase)
events = fixture();
verifyError(testCase, @() apply_trigger_delays_reference( ...
    events, {'121'}, [1, 2], 1000, [1, 4]), ...
    'apply_trigger_delays_reference:TargetMappingMismatch');
verifyError(testCase, @() apply_trigger_delays_reference( ...
    events, {'121'}, 1, 1000, 1), ...
    'apply_trigger_delays_reference:TargetMappingMismatch');
for mapping = {[1, 1], [1, 7], [1, 1.5]}
    verifyError(testCase, @() apply_trigger_delays_reference( ...
        events, {'121'}, [1, 2], 1000, mapping{1}), ...
        'apply_trigger_delays_reference:InvalidMapping');
end
end

function testNoMatchingTargets(testCase)
events = fixture();
[out, audit] = apply_trigger_delays_reference(events, {'absent'}, 10, 500);
verifyEqual(testCase, out, events);
verifyEqual(testCase, height(audit), 0);
end

function events = fixture()
types = {'121', 'S 121', 'S121', 'boundary', '121', '00121'};
latencies = [100.25, 200.75, 300.125, 400.5, 500.25, 600.75];
events = struct('type', types, 'latency', num2cell(latencies), ...
    'duration', num2cell(1:6), 'urevent', num2cell(11:16));
end
