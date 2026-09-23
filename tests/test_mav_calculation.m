function tests = test_mav_calculation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.original_path = path;
addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testRawDifferenceAndRatioValues(testCase)
times = -1000:500:2000;
raw_data = reshape([-2, 2, -6, 8, -10, 12, -14], 1, [], 1);
rectified_data = abs(raw_data);
baseline_window = [-1000, 0];
bin_duration_ms = 1000;
epoch_end_ms = 2000;

raw_features = extract_binned_mav(...
    rectified_data, times, bin_duration_ms, epoch_end_ms);
verifyEqual(testCase, reshape(raw_features, 1, []), [2, 7, 12], 'AbsTol', 1e-12);

difference_data = apply_mav_baseline_correction(...
    rectified_data, times, baseline_window, 'subtraction');
difference_features = extract_binned_mav(...
    difference_data, times, bin_duration_ms, epoch_end_ms);
verifyEqual(testCase, reshape(difference_features, 1, []), [0, 5, 10], 'AbsTol', 1e-12);

ratio_data = apply_mav_baseline_correction(...
    rectified_data, times, baseline_window, 'division');
ratio_features = extract_binned_mav(...
    ratio_data, times, bin_duration_ms, epoch_end_ms);
verifyEqual(testCase, reshape(ratio_features, 1, []), [1, 3.5, 6], 'AbsTol', 1e-12);
verifyEqual(testCase, ratio_features(1, 1, 1), 1, 'AbsTol', 1e-12);
end

function testSubtractionDoesNotApplyAbsoluteValueAgain(testCase)
times = -1000:500:1000;
rectified_data = reshape([10, 10, 2, 4, 6], 1, [], 1);

difference_data = apply_mav_baseline_correction(...
    rectified_data, times, [-1000, 0], 'subtraction');
difference_features = extract_binned_mav(...
    difference_data, times, 1000, 1000);

verifyEqual(testCase, difference_features(1, 1, 2), -6, 'AbsTol', 1e-12);
end

function testIncompletePostStimulusBinIsRejected(testCase)
times = -1000:500:2000;
data = ones(1, length(times), 1);

verifyError(testCase, ...
    @() extract_binned_mav(data, times, 700, 2000), ...
    'extract_binned_mav:IncompleteBin');
end
