function tests = test_mav_standardization
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.original_path = path;
addpath(fullfile(fileparts(mfilename('fullpath')), 'helpers'));
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testMuscleStandardizationUsesPostStimulusBins(testCase)
[features, bin_edges] = standardization_fixture();

[z_features, reference_mean, reference_sd] = ...
    standardize_mav_features(features, bin_edges, 'muscle');

verifyEqual(testCase, reference_mean, [4, 16], 'AbsTol', 1e-12);
verifyEqual(testCase, reference_sd, [sqrt(20/3), sqrt(80/3)], 'AbsTol', 1e-12);

for ch = 1:2
    post_values = reshape(z_features(:, ch, 2:3), [], 1);
    verifyEqual(testCase, mean(post_values), 0, 'AbsTol', 1e-12);
    verifyEqual(testCase, std(post_values, 0), 1, 'AbsTol', 1e-12);
end

expected_pre = [2.3237900077, 2.7110883423; ...
    6.1967733539, 4.6475800154];
verifyEqual(testCase, z_features(:, :, 1), expected_pre, 'AbsTol', 1e-10);
end

function testSubjectStandardizationPoolsMuscles(testCase)
[features, bin_edges] = standardization_fixture();

[z_features, reference_mean, reference_sd] = ...
    standardize_mav_features(features, bin_edges, 'subject');

verifyEqual(testCase, reference_mean, 10, 'AbsTol', 1e-12);
verifyEqual(testCase, reference_sd, sqrt(388/7), 'AbsTol', 1e-12);

post_values = reshape(z_features(:, :, 2:3), [], 1);
verifyEqual(testCase, mean(post_values), 0, 'AbsTol', 1e-12);
verifyEqual(testCase, std(post_values, 0), 1, 'AbsTol', 1e-12);

expected_pre = [0, 1.3431767238, 2.6863534476, 4.0295301714]';
verifyEqual(testCase, reshape(z_features(:, :, 1), [], 1), expected_pre, 'AbsTol', 1e-10);
end

function testPreStimulusValuesDoNotAffectReference(testCase)
[features, bin_edges] = standardization_fixture();

[z_original, mean_original, sd_original] = ...
    standardize_mav_features(features, bin_edges, 'muscle');

features(:, :, 1) = 1e9;
[z_extreme, mean_extreme, sd_extreme] = ...
    standardize_mav_features(features, bin_edges, 'muscle');

verifyEqual(testCase, mean_extreme, mean_original, 'AbsTol', 1e-12);
verifyEqual(testCase, sd_extreme, sd_original, 'AbsTol', 1e-12);
verifyEqual(testCase, z_extreme(:, :, 2:3), z_original(:, :, 2:3), 'AbsTol', 1e-12);
end

function testStandardizationPrecedesTrialAveraging(testCase)
trial_by_bin = [0, 1, 2; ...
    0, 3, 4; ...
    0, 10, 12; ...
    0, 14, 16];
features = permute(trial_by_bin, [1, 3, 2]);
bin_edges = [-1000, 0, 1000, 2000];

z_before_averaging = standardize_mav_features(features, bin_edges, 'muscle');
condition_average_z = cat(1, ...
    mean(z_before_averaging(1:2, :, :), 1), ...
    mean(z_before_averaging(3:4, :, :), 1));

condition_average_raw = cat(1, ...
    mean(features(1:2, :, :), 1), ...
    mean(features(3:4, :, :), 1));
z_after_averaging = standardize_mav_features(condition_average_raw, bin_edges, 'muscle');

verifyGreaterThan(testCase, ...
    max(abs(condition_average_z(:) - z_after_averaging(:))), 1e-6);
end

function testInvalidStandardizationReferences(testCase)
single_reference = reshape([0, 5], 1, 1, 2);
bin_edges = [-1000, 0, 1000];
verifyError(testCase, ...
    @() standardize_mav_features(single_reference, bin_edges, 'muscle'), ...
    'standardize_mav_features:InvalidReference');

constant_reference = zeros(2, 1, 2);
constant_reference(:, 1, 2) = 5;
verifyError(testCase, ...
    @() standardize_mav_features(constant_reference, bin_edges, 'muscle'), ...
    'standardize_mav_features:InvalidReference');
end

function [features, bin_edges] = standardization_fixture()
features = zeros(2, 2, 3);
features(1, 1, :) = reshape([10, 1, 3], 1, 1, []);
features(2, 1, :) = reshape([20, 5, 7], 1, 1, []);
features(1, 2, :) = reshape([30, 10, 14], 1, 1, []);
features(2, 2, :) = reshape([40, 18, 22], 1, 1, []);
bin_edges = [-1000, 0, 1000, 2000];
end
