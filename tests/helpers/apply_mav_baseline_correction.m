function [corrected_data, baseline_amplitudes] = apply_mav_baseline_correction(...
    data, times, baseline_window, method)
%APPLY_MAV_BASELINE_CORRECTION Apply trial-wise correction to rectified EMG.
%   DATA is channels X samples X trials and TIMES is expressed in ms.
%   BASELINE_WINDOW follows a left-inclusive, right-exclusive convention.
%   METHOD must be 'none', 'subtraction', or 'division'.

method = char(method);

if strcmp(method, 'none')
    corrected_data = data;
    baseline_amplitudes = [];
    return
end

baseline_idx = times >= baseline_window(1) & times < baseline_window(2);
if ~any(baseline_idx)
    error('apply_mav_baseline_correction:EmptyBaseline', ...
        'The specified baseline window contains no samples.');
end

baseline_amplitudes = mean(data(:, baseline_idx, :), 2);

if strcmp(method, 'subtraction')
    corrected_data = data - baseline_amplitudes;
elseif strcmp(method, 'division')
    corrected_data = data ./ baseline_amplitudes;
else
    error('apply_mav_baseline_correction:InvalidMethod', ...
        'Method must be ''none'', ''subtraction'', or ''division''.');
end

end
