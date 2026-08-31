function [feature_values, bin_edges] = extract_binned_mav(...
    data, times, bin_duration_ms, epoch_end_ms)
%EXTRACT_BINNED_MAV Extract non-overlapping bin means from rectified EMG.
%   DATA is channels X samples X trials. FEATURE_VALUES is trials X
%   channels X bins. The first bin is the pre-stimulus interval ending at
%   0 ms. All intervals are left-inclusive and right-exclusive, except the
%   final post-stimulus bin, which includes the final endpoint.

n_post_bins = epoch_end_ms / bin_duration_ms;
if abs(n_post_bins - round(n_post_bins)) > 1e-10
    error('extract_binned_mav:IncompleteBin', ...
        'The post-stimulus epoch duration must be a multiple of the bin duration.');
end

n_post_bins = round(n_post_bins);
bin_edges = [-bin_duration_ms, 0:bin_duration_ms:epoch_end_ms];
n_bins = n_post_bins + 1;

n_trials = size(data, 3);
n_channels = size(data, 1);
feature_values = nan(n_trials, n_channels, n_bins);

for b = 1:n_bins
    if b < n_bins
        sample_idx = times >= bin_edges(b) & times < bin_edges(b + 1);
    else
        sample_idx = times >= bin_edges(b) & times <= bin_edges(b + 1);
    end

    if ~any(sample_idx)
        error('extract_binned_mav:EmptyBin', ...
            'Bin %d contains no samples.', b);
    end

    bin_mean = mean(data(:, sample_idx, :), 2);
    feature_values(:, :, b) = reshape(...
        permute(bin_mean, [3, 1, 2]), n_trials, n_channels);
end

end
