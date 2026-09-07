function [delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options)
%DETECT_PHOTODIODE_DELAYS_REFERENCE Detect sustained photodiode crossings.
%   This test-only numerical reference accepts PROCESSED_TRIALS arranged as
%   trials X samples and a vector TIMES_MS with one time value per sample.
%   Trial order is preserved in every output. DELAYS_MS is the detected
%   epoch time for each trial and is NaN when STATUS is not "detected".
%
%   OPTIONS is a scalar structure. Every field is required; there are no
%   scientific defaults:
%     threshold_mode       - 'absolute', 'range_divisor_unanchored', or
%                            'range_fraction_above_minimum'
%     threshold_value      - finite scalar or one finite value per trial
%     threshold_scope      - 'search_window' or 'full_trial'
%     threshold_comparison - 'greater_than_or_equal' or 'greater_than'
%     minimum_run_samples  - positive integer number of consecutive samples
%     zero_time_policy     - 'require_exact', 'first_nonnegative',
%                            'nearest_earlier', or 'nearest_later'
%
%   The unanchored range-divisor threshold is range(signal) / value. The
%   above-minimum threshold is min(signal) + value * range(signal). The
%   relevant signal is selected by threshold_scope. Supplying an absolute
%   threshold bypasses a range-based definition.
%
%   DIAGNOSTICS is one structure per input trial and records the search
%   anchor, computed amplitude threshold, detected sample and run length.
%   This function does not convert milliseconds to samples and does not
%   apply delays to events. A non-detection is represented neutrally by its
%   status and NaN numerical fields so a later integration can apply an
%   explicitly approved missing-crossing policy.

validate_inputs(processed_trials, times_ms, options);

times_ms = reshape(times_ms, 1, []);
n_trials = size(processed_trials, 1);
n_samples = size(processed_trials, 2);

threshold_mode = option_text(options.threshold_mode, 'threshold_mode');
threshold_scope = option_text(options.threshold_scope, 'threshold_scope');
threshold_comparison = option_text( ...
    options.threshold_comparison, 'threshold_comparison');
zero_time_policy = option_text(options.zero_time_policy, 'zero_time_policy');
threshold_values = trial_parameter( ...
    options.threshold_value, n_trials, 'threshold_value');

validate_option_values( ...
    threshold_mode, threshold_values, threshold_scope, ...
    threshold_comparison, options.minimum_run_samples, zero_time_policy);

delays_ms = nan(n_trials, 1);
status = strings(n_trials, 1);
diagnostic_template = struct( ...
    'trial_index', NaN, ...
    'exact_zero_present', false, ...
    'search_start_index', NaN, ...
    'search_start_time_ms', NaN, ...
    'threshold_signal_range', NaN, ...
    'threshold_amplitude', NaN, ...
    'detected_sample_index', NaN, ...
    'detected_search_index', NaN, ...
    'detected_time_ms', NaN, ...
    'qualifying_run_length_samples', NaN, ...
    'qualifying_run_end_index', NaN);
diagnostics = repmat(diagnostic_template, n_trials, 1);

exact_zero_index = find(times_ms == 0, 1, 'first');
exact_zero_present = ~isempty(exact_zero_index);

for trial_index = 1:n_trials
    diagnostics(trial_index).trial_index = trial_index;
    diagnostics(trial_index).exact_zero_present = exact_zero_present;

    [search_start_index, anchor_status] = select_search_start( ...
        times_ms, exact_zero_index, zero_time_policy);
    if ~strcmp(anchor_status, 'ready')
        status(trial_index) = anchor_status;
        continue
    end

    diagnostics(trial_index).search_start_index = search_start_index;
    diagnostics(trial_index).search_start_time_ms = ...
        times_ms(search_start_index);

    if strcmp(threshold_scope, 'search_window')
        threshold_samples = processed_trials( ...
            trial_index, search_start_index:n_samples);
    else
        threshold_samples = processed_trials(trial_index, :);
    end

    [threshold_amplitude, threshold_signal_range] = calculate_threshold( ...
        threshold_samples, threshold_mode, threshold_values(trial_index));
    diagnostics(trial_index).threshold_signal_range = threshold_signal_range;
    diagnostics(trial_index).threshold_amplitude = threshold_amplitude;
    if ~strcmp(threshold_mode, 'absolute') && threshold_signal_range == 0
        status(trial_index) = "zero_range";
        continue
    end

    search_signal = processed_trials(trial_index, search_start_index:n_samples);
    if strcmp(threshold_comparison, 'greater_than_or_equal')
        above_threshold = search_signal >= threshold_amplitude;
    else
        above_threshold = search_signal > threshold_amplitude;
    end

    [run_start_index, run_end_index, run_length] = first_qualifying_run( ...
        above_threshold, options.minimum_run_samples);
    if isempty(run_start_index)
        status(trial_index) = "no_crossing";
        continue
    end

    detected_sample_index = search_start_index + run_start_index - 1;
    qualifying_run_end_index = search_start_index + run_end_index - 1;
    detected_time_ms = times_ms(detected_sample_index);

    delays_ms(trial_index) = detected_time_ms;
    status(trial_index) = "detected";
    diagnostics(trial_index).detected_sample_index = detected_sample_index;
    diagnostics(trial_index).detected_search_index = run_start_index;
    diagnostics(trial_index).detected_time_ms = detected_time_ms;
    diagnostics(trial_index).qualifying_run_length_samples = run_length;
    diagnostics(trial_index).qualifying_run_end_index = ...
        qualifying_run_end_index;
end

end

function validate_inputs(processed_trials, times_ms, options)
if ~isnumeric(processed_trials) || ~isreal(processed_trials) || ...
        isempty(processed_trials) || ndims(processed_trials) ~= 2 || ...
        any(~isfinite(processed_trials(:)))
    error('detect_photodiode_delays_reference:InvalidData', ...
        ['processed_trials must be a nonempty, finite, real numeric ', ...
        'trials-by-samples matrix.']);
end

if ~isnumeric(times_ms) || ~isreal(times_ms) || ~isvector(times_ms) || ...
        isempty(times_ms) || any(~isfinite(times_ms(:)))
    error('detect_photodiode_delays_reference:InvalidTimes', ...
        'times_ms must be a nonempty, finite, real numeric vector.');
end

if numel(times_ms) ~= size(processed_trials, 2)
    error('detect_photodiode_delays_reference:TimeLengthMismatch', ...
        'times_ms must contain one value per column of processed_trials.');
end

if any(diff(reshape(times_ms, 1, [])) <= 0)
    error('detect_photodiode_delays_reference:InvalidTimes', ...
        'times_ms must be strictly increasing.');
end

required_fields = { ...
    'threshold_mode', ...
    'threshold_value', ...
    'threshold_scope', ...
    'threshold_comparison', ...
    'minimum_run_samples', ...
    'zero_time_policy'};
if ~isstruct(options) || ~isscalar(options) || ...
        ~all(isfield(options, required_fields))
    error('detect_photodiode_delays_reference:InvalidOptions', ...
        'options must be a scalar structure containing every required field.');
end
end

function value = option_text(raw_value, field_name)
if isstring(raw_value) && isscalar(raw_value)
    value = char(raw_value);
elseif ischar(raw_value) && isrow(raw_value)
    value = raw_value;
else
    error('detect_photodiode_delays_reference:InvalidOptions', ...
        'options.%s must be a character vector or string scalar.', field_name);
end
value = lower(strtrim(value));
end

function values = trial_parameter(raw_value, n_trials, field_name)
if ~isnumeric(raw_value) || ~isreal(raw_value) || ...
        ~isvector(raw_value) || isempty(raw_value) || ...
        any(~isfinite(raw_value(:)))
    error('detect_photodiode_delays_reference:InvalidThreshold', ...
        'options.%s must contain finite, real numeric values.', field_name);
end

if isscalar(raw_value)
    values = repmat(double(raw_value), n_trials, 1);
elseif numel(raw_value) == n_trials
    values = reshape(double(raw_value), [], 1);
else
    error('detect_photodiode_delays_reference:InvalidThreshold', ...
        'options.%s must be scalar or contain one value per trial.', field_name);
end
end

function validate_option_values(threshold_mode, threshold_values, ...
        threshold_scope, threshold_comparison, minimum_run_samples, ...
        zero_time_policy)
valid_threshold_modes = { ...
    'absolute', ...
    'range_divisor_unanchored', ...
    'range_fraction_above_minimum'};
if ~ismember(threshold_mode, valid_threshold_modes)
    error('detect_photodiode_delays_reference:InvalidThresholdMode', ...
        'Unsupported threshold_mode: %s.', threshold_mode);
end

if strcmp(threshold_mode, 'range_divisor_unanchored') && ...
        any(threshold_values <= 0)
    error('detect_photodiode_delays_reference:InvalidThreshold', ...
        'A range divisor must be greater than zero.');
end
if strcmp(threshold_mode, 'range_fraction_above_minimum') && ...
        any(threshold_values < 0 | threshold_values > 1)
    error('detect_photodiode_delays_reference:InvalidThreshold', ...
        'A range fraction must be between zero and one, inclusive.');
end

if ~ismember(threshold_scope, {'search_window', 'full_trial'})
    error('detect_photodiode_delays_reference:InvalidThresholdScope', ...
        'Unsupported threshold_scope: %s.', threshold_scope);
end
if ~ismember(threshold_comparison, ...
        {'greater_than_or_equal', 'greater_than'})
    error('detect_photodiode_delays_reference:InvalidComparison', ...
        'Unsupported threshold_comparison: %s.', threshold_comparison);
end

if ~isnumeric(minimum_run_samples) || ~isreal(minimum_run_samples) || ...
        ~isscalar(minimum_run_samples) || ~isfinite(minimum_run_samples) || ...
        minimum_run_samples < 1 || minimum_run_samples ~= fix(minimum_run_samples)
    error('detect_photodiode_delays_reference:InvalidRunLength', ...
        'minimum_run_samples must be a finite positive integer.');
end

valid_zero_time_policies = { ...
    'require_exact', ...
    'first_nonnegative', ...
    'nearest_earlier', ...
    'nearest_later'};
if ~ismember(zero_time_policy, valid_zero_time_policies)
    error('detect_photodiode_delays_reference:InvalidZeroTimePolicy', ...
        'Unsupported zero_time_policy: %s.', zero_time_policy);
end
end

function [search_start_index, status] = select_search_start( ...
        times_ms, exact_zero_index, zero_time_policy)
search_start_index = [];
status = 'ready';

if strcmp(zero_time_policy, 'require_exact')
    if isempty(exact_zero_index)
        status = 'no_exact_zero';
        return
    end
    search_start_index = exact_zero_index;
elseif strcmp(zero_time_policy, 'first_nonnegative')
    search_start_index = find(times_ms >= 0, 1, 'first');
    if isempty(search_start_index)
        status = 'no_post_trigger_sample';
    end
else
    minimum_distance = min(abs(times_ms));
    tied_indices = find(abs(times_ms) == minimum_distance);
    if strcmp(zero_time_policy, 'nearest_earlier')
        search_start_index = tied_indices(1);
    else
        search_start_index = tied_indices(end);
    end
end
end

function [threshold, signal_range] = calculate_threshold(samples, mode, value)
signal_range = max(samples) - min(samples);
if strcmp(mode, 'absolute')
    threshold = value;
elseif strcmp(mode, 'range_divisor_unanchored')
    threshold = signal_range / value;
else
    signal_minimum = min(samples);
    threshold = signal_minimum + value * signal_range;
end
end

function [run_start, run_end, run_length] = first_qualifying_run( ...
        above_threshold, minimum_run_samples)
transitions = diff([false, above_threshold, false]);
run_starts = find(transitions == 1);
run_ends = find(transitions == -1) - 1;
run_lengths = run_ends - run_starts + 1;
qualifying_run = find(run_lengths >= minimum_run_samples, 1, 'first');

if isempty(qualifying_run)
    run_start = [];
    run_end = [];
    run_length = [];
else
    run_start = run_starts(qualifying_run);
    run_end = run_ends(qualifying_run);
    run_length = run_lengths(qualifying_run);
end
end
