function [standardized_features, reference_mean, reference_sd] = ...
    standardize_mav_features(feature_values, bin_edges, mode)
%STANDARDIZE_MAV_FEATURES Standardize features from post-stimulus bins.
%   FEATURE_VALUES is trials X muscles X bins. MODE is 'muscle' or
%   'subject'. Reference parameters use only bins starting at or after
%   0 ms, but the resulting transform is applied to every bin.

mode = char(mode);
post_bin_idx = bin_edges(1:end-1) >= 0;
standardized_features = nan(size(feature_values));

if strcmp(mode, 'muscle')
    n_muscles = size(feature_values, 2);
    reference_mean = nan(1, n_muscles);
    reference_sd = nan(1, n_muscles);

    for ch = 1:n_muscles
        reference_values = reshape(feature_values(:, ch, post_bin_idx), [], 1);
        reference_values = reference_values(isfinite(reference_values));
        validate_reference(reference_values, sprintf('muscle %d', ch));

        reference_mean(ch) = mean(reference_values);
        reference_sd(ch) = std(reference_values, 0);
        validate_sd(reference_sd(ch), sprintf('muscle %d', ch));

        standardized_features(:, ch, :) = ...
            (feature_values(:, ch, :) - reference_mean(ch)) ./ reference_sd(ch);
    end

elseif strcmp(mode, 'subject')
    reference_values = reshape(feature_values(:, :, post_bin_idx), [], 1);
    reference_values = reference_values(isfinite(reference_values));
    validate_reference(reference_values, 'subject');

    reference_mean = mean(reference_values);
    reference_sd = std(reference_values, 0);
    validate_sd(reference_sd, 'subject');

    standardized_features = (feature_values - reference_mean) ./ reference_sd;

else
    error('standardize_mav_features:InvalidMode', ...
        'Mode must be ''muscle'' or ''subject''.');
end

end

function validate_reference(reference_values, label)
if numel(reference_values) < 2
    error('standardize_mav_features:InvalidReference', ...
        'The %s standardization reference has fewer than two finite observations.', label);
end
end

function validate_sd(reference_sd, label)
if ~isfinite(reference_sd) || reference_sd == 0
    error('standardize_mav_features:InvalidReference', ...
        'The %s standardization reference has zero or nonfinite SD.', label);
end
end
