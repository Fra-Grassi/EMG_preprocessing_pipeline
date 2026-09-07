function tests = test_photodiode_delay_detection
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
tests_dir = fileparts(mfilename('fullpath'));
helpers_dir = fullfile(tests_dir, 'helpers');
testCase.TestData.original_path = path;
addpath(helpers_dir);
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testDistinctTrialsProduceOrderedDetections(testCase)
times_ms = [-2, -1, 0, 1, 2, 3, 4, 5];
processed_trials = [ ...
    0, 0, 0, 8, 8, 0, 0, 0; ...
    0, 0, 0, 0, 0, 9, 9, 9; ...
    0, 0, 7, 7, 7, 0, 0, 0];
options = absolute_options(5, 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, delays_ms, [1; 3; 0]);
verifyEqual(testCase, status, ["detected"; "detected"; "detected"]);
verifyEqual(testCase, [diagnostics.trial_index]', (1:3)');
verifyEqual(testCase, [diagnostics.detected_sample_index]', [4; 6; 3]);
end

function testFirstQualifyingSampleHasNoOffByOneError(testCase)
times_ms = [-10, -5, 0, 5, 10];
processed_trials = [0, 0, 0, 7, 7];
options = absolute_options(7, 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "detected");
verifyEqual(testCase, delays_ms, 5);
verifyEqual(testCase, diagnostics.detected_sample_index, 4);
verifyEqual(testCase, diagnostics.detected_search_index, 2);
end

function testShortExcursionsAreRejected(testCase)
times_ms = -2:5;
processed_trials = [0, 0, 0, 8, 0, 0, 0, 0];
options = absolute_options(5, 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "no_crossing");
verifyTrue(testCase, isnan(delays_ms));
verifyTrue(testCase, isnan(diagnostics.detected_sample_index));
end

function testFirstSustainedRunIsDetectedAtItsStart(testCase)
times_ms = -2:7;
processed_trials = [0, 0, 0, 9, 0, 0, 8, 8, 8, 0];
options = absolute_options(5, 3, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "detected");
verifyEqual(testCase, delays_ms, 4);
verifyEqual(testCase, diagnostics.qualifying_run_length_samples, 3);
verifyEqual(testCase, diagnostics.qualifying_run_end_index, 9);
end

function testQualifyingRunEndingAtFinalSample(testCase)
times_ms = [-2, -1, 0, 1, 2, 3];
processed_trials = [0, 0, 0, 0, 6, 6];
options = absolute_options(5, 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "detected");
verifyEqual(testCase, delays_ms, 2);
verifyEqual(testCase, diagnostics.detected_sample_index, 5);
verifyEqual(testCase, diagnostics.qualifying_run_end_index, 6);
end

function testPreZeroSamplesAreExcludedByPostTriggerAnchor(testCase)
times_ms = [-3, -2, -1, 0, 1, 2, 3];
processed_trials = [9, 9, 9, 0, 0, 8, 8];
options = absolute_options(5, 2, 'first_nonnegative');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "detected");
verifyEqual(testCase, delays_ms, 2);
verifyEqual(testCase, diagnostics.search_start_index, 4);
end

function testExactAndMissingZeroAreExplicit(testCase)
exact_times_ms = [-1, 0, 1, 2];
processed_trials = [0, 0, 7, 7];
options = absolute_options(5, 2, 'require_exact');

[exact_delay, exact_status, exact_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, exact_times_ms, options);
verifyEqual(testCase, exact_status, "detected");
verifyEqual(testCase, exact_delay, 1);
verifyTrue(testCase, exact_diagnostics.exact_zero_present);

missing_zero_times_ms = [-1.5, -0.5, 0.5, 1.5];
[missing_delay, missing_status, missing_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, missing_zero_times_ms, options);
verifyEqual(testCase, missing_status, "no_exact_zero");
verifyTrue(testCase, isnan(missing_delay));
verifyFalse(testCase, missing_diagnostics.exact_zero_present);

options.zero_time_policy = 'first_nonnegative';
[nonnegative_delay, nonnegative_status, nonnegative_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, missing_zero_times_ms, options);
verifyEqual(testCase, nonnegative_status, "detected");
verifyEqual(testCase, nonnegative_delay, 0.5);
verifyEqual(testCase, nonnegative_diagnostics.search_start_index, 3);
end

function testNearestZeroTieDirectionIsExplicit(testCase)
times_ms = [-1.5, -0.5, 0.5, 1.5];
processed_trials = [0, 8, 8, 0];

earlier_options = absolute_options(5, 1, 'nearest_earlier');
[earlier_delay, earlier_status] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, earlier_options);
verifyEqual(testCase, earlier_status, "detected");
verifyEqual(testCase, earlier_delay, -0.5);

later_options = absolute_options(5, 1, 'nearest_later');
[later_delay, later_status] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, later_options);
verifyEqual(testCase, later_status, "detected");
verifyEqual(testCase, later_delay, 0.5);
end

function testMissingCrossingHasNeutralStatus(testCase)
times_ms = [-1, 0, 1, 2];
processed_trials = [0, 1, 2, 3];
options = absolute_options(10, 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifyEqual(testCase, status, "no_crossing");
verifyTrue(testCase, isnan(delays_ms));
verifyTrue(testCase, isnan(diagnostics.detected_time_ms));
end

function testOutputLengthAndOrderMatchInputTrials(testCase)
times_ms = [0, 1, 2, 3, 4];
processed_trials = [ ...
    0, 0, 0, 6, 6; ...
    7, 7, 0, 0, 0; ...
    0, 8, 8, 0, 0; ...
    0, 0, 0, 0, 0];
options = absolute_options([5; 5; 5; 5], 2, 'require_exact');

[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options);

verifySize(testCase, delays_ms, [4, 1]);
verifySize(testCase, status, [4, 1]);
verifySize(testCase, diagnostics, [4, 1]);
verifyEqual(testCase, delays_ms(1:3), [3; 0; 1]);
verifyTrue(testCase, isnan(delays_ms(4)));
verifyEqual(testCase, status, ...
    ["detected"; "detected"; "detected"; "no_crossing"]);
verifyEqual(testCase, [diagnostics.trial_index]', (1:4)');
end

function testThresholdDefinitionsAreExplicit(testCase)
times_ms = [0, 1, 2, 3];
processed_trials = [-2, 0, 2, 6];

unanchored_options = reference_options( ...
    'range_divisor_unanchored', 4, 1, 'require_exact');
[unanchored_delay, ~, unanchored_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, unanchored_options);
verifyEqual(testCase, unanchored_diagnostics.threshold_amplitude, 2);
verifyEqual(testCase, unanchored_delay, 2);

anchored_options = reference_options( ...
    'range_fraction_above_minimum', 0.25, 1, 'require_exact');
[anchored_delay, ~, anchored_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, anchored_options);
verifyEqual(testCase, anchored_diagnostics.threshold_amplitude, 0);
verifyEqual(testCase, anchored_delay, 1);
end

function testZeroRangeHasNeutralStatusForRangeThreshold(testCase)
times_ms = [0, 1, 2];
processed_trials = [0, 0, 0];
options = reference_options( ...
    'range_divisor_unanchored', 4, 2, 'require_exact');

[delay_ms, status, diagnostics] = detect_photodiode_delays_reference( ...
    processed_trials, times_ms, options);

verifyEqual(testCase, status, "zero_range");
verifyTrue(testCase, isnan(delay_ms));
verifyEqual(testCase, diagnostics.threshold_signal_range, 0);
verifyEqual(testCase, diagnostics.threshold_amplitude, 0);
end

function testThresholdScopeAndComparisonAreExplicit(testCase)
times_ms = [-2, -1, 0, 1, 2];
processed_trials = [-10, 10, 0, 4, 4];

search_options = reference_options( ...
    'range_divisor_unanchored', 2, 1, 'require_exact');
[search_delay, search_status, search_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, search_options);
verifyEqual(testCase, search_diagnostics.threshold_amplitude, 2);
verifyEqual(testCase, search_status, "detected");
verifyEqual(testCase, search_delay, 1);

full_options = search_options;
full_options.threshold_scope = 'full_trial';
[full_delay, full_status, full_diagnostics] = ...
    detect_photodiode_delays_reference( ...
    processed_trials, times_ms, full_options);
verifyEqual(testCase, full_diagnostics.threshold_amplitude, 10);
verifyEqual(testCase, full_status, "no_crossing");
verifyTrue(testCase, isnan(full_delay));

equal_options = absolute_options(4, 1, 'require_exact');
equal_options.threshold_comparison = 'greater_than';
[strict_delay, strict_status] = detect_photodiode_delays_reference( ...
    processed_trials, times_ms, equal_options);
verifyEqual(testCase, strict_status, "no_crossing");
verifyTrue(testCase, isnan(strict_delay));
end

function testInvalidDimensionsAndTimeVectorsFailClearly(testCase)
options = absolute_options(5, 2, 'require_exact');

verifyError(testCase, ...
    @() detect_photodiode_delays_reference(zeros(2, 3, 2), 1:3, options), ...
    'detect_photodiode_delays_reference:InvalidData');
verifyError(testCase, ...
    @() detect_photodiode_delays_reference(zeros(2, 3), 1:2, options), ...
    'detect_photodiode_delays_reference:TimeLengthMismatch');
verifyError(testCase, ...
    @() detect_photodiode_delays_reference(zeros(2, 3), [0, 2, 1], options), ...
    'detect_photodiode_delays_reference:InvalidTimes');
end

function testInvalidThresholdInputsFailClearly(testCase)
times_ms = [0, 1, 2];
processed_trials = zeros(2, 3);

options = absolute_options([1, 2, 3], 1, 'require_exact');
verifyError(testCase, ...
    @() detect_photodiode_delays_reference( ...
    processed_trials, times_ms, options), ...
    'detect_photodiode_delays_reference:InvalidThreshold');

options = reference_options( ...
    'range_divisor_unanchored', 0, 1, 'require_exact');
verifyError(testCase, ...
    @() detect_photodiode_delays_reference( ...
    processed_trials, times_ms, options), ...
    'detect_photodiode_delays_reference:InvalidThreshold');

options = reference_options( ...
    'range_fraction_above_minimum', 1.1, 1, 'require_exact');
verifyError(testCase, ...
    @() detect_photodiode_delays_reference( ...
    processed_trials, times_ms, options), ...
    'detect_photodiode_delays_reference:InvalidThreshold');
end

function testInvalidRunLengthInputsFailClearly(testCase)
times_ms = [0, 1, 2];
processed_trials = zeros(1, 3);

for invalid_run_length = [0, -1, 1.5, Inf]
    options = absolute_options(1, invalid_run_length, 'require_exact');
    verifyError(testCase, ...
        @() detect_photodiode_delays_reference( ...
        processed_trials, times_ms, options), ...
        'detect_photodiode_delays_reference:InvalidRunLength');
end
end

function testReferenceAcceptsArraysAndRejectsStructures(testCase)
options = absolute_options(1, 1, 'require_exact');

[delay_ms, status] = detect_photodiode_delays_reference( ...
    [0, 2], [0, 1], options);
verifyEqual(testCase, delay_ms, 1);
verifyEqual(testCase, status, "detected");

verifyError(testCase, ...
    @() detect_photodiode_delays_reference( ...
    struct('data', [0, 2]), [0, 1], options), ...
    'detect_photodiode_delays_reference:InvalidData');
end

function testReferenceContainsNoExternalDetectionCalls(testCase)
helper_file = which('detect_photodiode_delays_reference');
source_text = fileread(helper_file);

verifyEmpty(testCase, regexp( ...
    source_text, '\<(pop_[A-Za-z0-9_]*|eeg_[A-Za-z0-9_]*)\s*\(', 'once'));
verifyEmpty(testCase, regexp( ...
    source_text, '\<(bwareafilt|bwconncomp|bwlabel|regionprops)\s*\(', 'once'));
end

function options = absolute_options(threshold_value, minimum_run_samples, ...
        zero_time_policy)
options = reference_options( ...
    'absolute', threshold_value, minimum_run_samples, zero_time_policy);
end

function options = reference_options(threshold_mode, threshold_value, ...
        minimum_run_samples, zero_time_policy)
options = struct( ...
    'threshold_mode', threshold_mode, ...
    'threshold_value', threshold_value, ...
    'threshold_scope', 'search_window', ...
    'threshold_comparison', 'greater_than_or_equal', ...
    'minimum_run_samples', minimum_run_samples, ...
    'zero_time_policy', zero_time_policy);
end
