function [EEGout, diagnostics] = shift_triggers(EEGin, target_types, method, ...
        epoch_window, divisor, minimum_duration_ms, show_plots)
%SHIFT_TRIGGERS Correct continuous event latencies under CD-11/CD-13--15.
%   METHOD: signed numeric delay (ms), 'variable', or 'median'. TARGET_TYPES:
%   cell of exact character codes, or one character code. Photodiode modes
%   require EPOCH_WINDOW in seconds including [-.029,0] and post-trigger data.
%   DIVISOR defaults to 4; MINIMUM_DURATION_MS defaults to 20; SHOW_PLOTS to true.
%   Run length = max(1,ceil(duration_ms*srate/1000)); offset = round(delay_ms*srate/1000).
%   Variable substitutes the recording median for unavailable estimates;
%   median applies it to all targets. Median is computed in ms before rounding.
%   No valid detections, missing channel or corrected latency outside [1,pnts]
%   errors. DIAGNOSTICS holds a separate event audit and paired waveforms.
%   No new EEG event fields. Requires EEGLAB and CleanLine (photodiode modes).
%   [EEG,audit] = shift_triggers(EEG, {'121'}, 'variable', [-.06 .1], 4, 20);
%   EEG = shift_triggers(EEG, {'121'}, -10);
%   Original authors: Annika Ziereis and Francesco Grassi.

if nargin < 5 || isempty(divisor), divisor = 4; end
if nargin < 6 || isempty(minimum_duration_ms), minimum_duration_ms = 20; end
if nargin < 7, show_plots = true; end
validateattributes(show_plots, {'logical'}, {'scalar'});
validateattributes(EEGin.srate, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
if EEGin.trials ~= 1 || size(EEGin.data, 2) ~= EEGin.pnts
    error('shift_triggers:ContinuousRequired', 'Supply a loaded continuous dataset.');
end
if ischar(target_types), target_types = {target_types}; end
if ~iscell(target_types) || isempty(target_types) || ...
        ~all(cellfun(@(x) ischar(x) && isrow(x), target_types))
    error('shift_triggers:InvalidTargets', 'Supply exact character trigger codes.');
end
event_types = {EEGin.event.type};
if ~all(cellfun(@(x) ischar(x) && isrow(x), event_types))
    error('shift_triggers:InvalidEvents', 'Normalize event types under CD-11 first.');
end
latencies = [EEGin.event.latency];
validateattributes(latencies, {'numeric'}, {'vector', 'finite', 'real'});
selected = false(size(event_types));
for k = 1:numel(target_types)
    selected = selected | strcmp(event_types, target_types{k});
end
event_index = find(selected(:));
if isempty(event_index)
    error('shift_triggers:NoTargets', 'No events match the configured exact codes.');
end
n_targets = numel(event_index);
original_latency = reshape(latencies(event_index), [], 1);
measured_delay_ms = nan(n_targets, 1);
epoch_index = nan(n_targets, 1);
detected_sample = nan(n_targets, 1);
threshold = nan(n_targets, 1);
status = repmat("fixed", n_targets, 1);
median_delay_ms = NaN;
successful_count = 0;
minimum_run_samples = NaN;
diode = [];
retained_rows = [];
channel = '';
zero_anchor_index = NaN;

if isnumeric(method)
    validateattributes(method, {'numeric'}, {'scalar', 'real', 'finite'});
    applied_delay_ms = repmat(double(method), n_targets, 1);
else
    if ~ischar(method) || ~ismember(method, {'variable', 'median'})
        error('shift_triggers:InvalidMethod', 'Use a numeric delay, variable, or median.');
    end
    if nargin < 4
        error('shift_triggers:InvalidWindow', 'Photodiode modes require an epoch window.');
    end
    validateattributes(epoch_window, {'numeric'}, {'vector', 'numel', 2, 'finite', 'real'});
    if epoch_window(1) > -.029 || epoch_window(2) <= 0
        error('shift_triggers:InvalidWindow', 'Window must include [-29,0] ms and post-trigger data.');
    end
    validateattributes(divisor, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    validateattributes(minimum_duration_ms, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    minimum_run_samples = max(1, ceil(minimum_duration_ms * EEGin.srate / 1000));
    labels = {EEGin.chanlocs.labels};
    if any(strcmp(labels, 'Erg1'))
        channel = 'Erg1';
    elseif any(strcmp(labels, 'photodiode'))
        channel = 'photodiode';
    else
        error('shift_triggers:MissingChannel', 'No Erg1 or photodiode channel exists.');
    end
    diode = pop_select(EEGin, 'channel', {channel});
    diode = pop_cleanline(diode, 'bandwidth', 2, 'chanlist', 1, ...
        'computepower', 0, 'linefreqs', 50, 'newversion', 0, ...
        'normSpectrum', 0, 'p', .01, 'pad', 2, 'plotfigures', 0, ...
        'scanforlines', 1, 'sigtype', 'Channels', 'taperbandwidth', 2, ...
        'tau', 100, 'verb', 1, 'winsize', 4, 'winstep', 2);

    % pop_epoch sorts before interpreting eventindices. Its accepted indices
    % are positions in the selected candidate list, including after omissions.
    % Keep the explicit permutation back to original continuous identity.
    % Empty type selection bypasses EEGLAB's deblank of character codes.
    [~, sort_order] = sort(latencies);
    diode.event = EEGin.event(sort_order);
    candidate_indices = find(selected(sort_order));
    candidate_original = sort_order(candidate_indices);
    status(:) = "omitted_epoch";

    % Mirror epoch.m bounds/event inclusion for all-omitted cases, avoiding
    % pop_select's version-dependent error when removing every epoch.
    candidate_latency = latencies(candidate_original);
    first_sample = floor(candidate_latency) + round(epoch_window(1)*EEGin.srate);
    last_sample = floor(candidate_latency) + round(epoch_window(2)*EEGin.srate-1);
    eligible = first_sample >= 1 & last_sample <= EEGin.pnts;
    boundary_latency = latencies(strcmp(event_types, 'boundary'));
    for k = 1:numel(candidate_indices)
        row = find(event_index == candidate_original(k));
        if ~eligible(k)
            status(row) = "recording_boundary";
        elseif any(boundary_latency >= floor(candidate_latency(k)) + epoch_window(1)*EEGin.srate & ...
                boundary_latency <= floor(candidate_latency(k)) + epoch_window(2)*EEGin.srate)
            eligible(k) = false;
            status(row) = "discontinuity";
        end
    end
    candidate_indices = candidate_indices(eligible);
    candidate_original = candidate_original(eligible);
    if isempty(candidate_indices)
        error('shift_triggers:NoDetections', 'No extractable target epochs; no median can be estimated.');
    end
    [diode, accepted] = pop_epoch(diode, {}, epoch_window, ...
        'eventindices', candidate_indices, 'epochinfo', 'yes');
    accepted = accepted(:);
    if isempty(accepted)
        error('shift_triggers:NoDetections', 'No retained target epochs; no median can be estimated.');
    end
    if numel(accepted) ~= diode.trials || any(~isfinite(accepted)) || ...
            any(accepted < 1 | accepted > numel(candidate_original)) || ...
            any(accepted ~= fix(accepted)) || numel(unique(accepted)) ~= numel(accepted)
        error('shift_triggers:EpochMapping', 'EEGLAB returned an inconsistent accepted-epoch mapping.');
    end
    [~, retained_rows] = ismember(candidate_original(accepted), event_index);
    retained_rows = retained_rows(:);
    diode = pop_rmbase(diode, [-29 0], []);
    diode.data = abs(diode.data);
    diode = pop_rmbase(diode, [-29 0], []);
    diode = eeg_checkset(diode);
    times = double(diode.times(:)');
    if numel(times) ~= size(diode.data, 2) || any(~isfinite(times)) || any(diff(times) <= 0)
        error('shift_triggers:InvalidTimes', 'Epoch times must be finite and strictly increasing.');
    end
    zero_anchor_index = find(abs(times) == min(abs(times)), 1, 'last');
    for trial = 1:numel(retained_rows)
        row = retained_rows(trial);
        epoch_index(row) = trial;
        signal = double(diode.data(1, zero_anchor_index:end, trial));
        if any(~isfinite(signal))
            status(row) = "nonfinite_signal";
            continue
        end
        signal_range = max(signal) - min(signal);
        if signal_range == 0
            status(row) = "zero_range";
            continue
        end
        threshold(row) = signal_range / divisor;
        transitions = diff([false, signal >= threshold(row), false]);
        starts = find(transitions == 1);
        stops = find(transitions == -1) - 1;
        run = find(stops - starts + 1 >= minimum_run_samples, 1);
        if isempty(run)
            status(row) = "no_crossing";
        else
            detected_sample(row) = zero_anchor_index + starts(run) - 1;
            measured_delay_ms(row) = times(detected_sample(row));
            status(row) = "detected";
        end
    end
    successful_count = sum(status == "detected");
    if successful_count == 0
        error('shift_triggers:NoDetections', 'No valid photodiode detections; no median can be estimated.');
    end
    median_delay_ms = median(measured_delay_ms(status == "detected"));
    applied_delay_ms = repmat(median_delay_ms, n_targets, 1);
    if strcmp(method, 'variable')
        valid = status == "detected";
        applied_delay_ms(valid) = measured_delay_ms(valid);
    end
end

sample_offset = round(applied_delay_ms * EEGin.srate / 1000);
corrected_latency = original_latency + sample_offset;
if any(~isfinite(corrected_latency) | corrected_latency < 1 | corrected_latency > EEGin.pnts)
    error('shift_triggers:OutOfBounds', 'Corrected target latencies exceed recording bounds [1,%d].', EEGin.pnts);
end
diagnostics.events = table(event_index, reshape(event_types(event_index), [], 1), ...
    original_latency, measured_delay_ms, applied_delay_ms, sample_offset, ...
    corrected_latency, status, epoch_index, detected_sample, threshold, ...
    'VariableNames', {'event_index', 'event_type', 'original_latency', ...
    'measured_delay_ms', 'applied_delay_ms', 'sample_offset', 'corrected_latency', ...
    'status', 'epoch_index', 'detected_sample', 'threshold'});
diagnostics.median_delay_ms = median_delay_ms;
diagnostics.successful_count = successful_count;
diagnostics.minimum_run_samples = minimum_run_samples;
diagnostics.zero_anchor_index = zero_anchor_index;
diagnostics.channel = channel;
diagnostics.method = method;
diagnostics.srate = EEGin.srate;
diagnostics.divisor = divisor;
diagnostics.minimum_duration_ms = minimum_duration_ms;
diagnostics.paired = struct('event_index', [], 'data', [], 'before_times_ms', [], 'after_times_ms', []);

% Basic EEGLAB consistency check; preserve exact event metadata/order.
% Full eventconsistency can sort events and alter types in some versions.
EEGout = eeg_checkset(EEGin);
EEGout.event = EEGin.event;
for row = 1:n_targets
    EEGout.event(event_index(row)).latency = corrected_latency(row);
end
EEGout.saved = 'no';
if ~isnumeric(method)
    missing = find(status ~= "detected");
    if ~isempty(missing)
        details = strings(numel(missing), 1);
        for k = 1:numel(missing)
            row = missing(k);
            details(k) = sprintf('event %d (%s): %s', event_index(row), ...
                event_types{event_index(row)}, char(status(row)));
        end
        warning('shift_triggers:MedianFallback', ...
            'Unavailable estimates: %s. Applied median %.9g ms; %d successful detections.', ...
            strjoin(cellstr(details), '; '), median_delay_ms, successful_count);
    end
    waveforms = reshape(diode.data(1,:,:), numel(diode.times), []);
    diagnostics.paired.event_index = event_index(retained_rows);
    diagnostics.paired.data = waveforms;
    diagnostics.paired.before_times_ms = double(diode.times(:));
    diagnostics.paired.after_times_ms = double(diode.times(:)) - ...
        (sample_offset(retained_rows)' * 1000 / EEGin.srate);
    fprintf('Photodiode: %d/%d valid estimates; median %.9g ms.\n', successful_count, n_targets, median_delay_ms);
    if show_plots, plot_diagnostics(diagnostics, target_types, EEGin.srate); end
end
end

function plot_diagnostics(diagnostics, target_types, srate)
figure('Name', 'Trigger shift diagnostics');
subplot(2,2,1);
plot(diagnostics.paired.before_times_ms, diagnostics.paired.data);
xlabel('Time from original trigger (ms)'); title('Same retained trials: before');
subplot(2,2,2);
plot(diagnostics.paired.after_times_ms, diagnostics.paired.data);
xlabel('Time from corrected trigger (ms)'); title('Same retained trials: after');
subplot(2,2,3);
audit = diagnostics.events;
histogram(audit.measured_delay_ms(audit.status == "detected"));
xlabel('Measured delay (ms)'); ylabel('Targets'); title('Successful estimates only');
subplot(2,2,4); hold on;
for k = 1:numel(target_types)
    rows = strcmp(audit.event_type, target_types{k}) & audit.status == "detected";
    plot((audit.original_latency(rows)-1)/srate, audit.measured_delay_ms(rows), '.', 'DisplayName', target_types{k});
end
xlabel('Recording time (s)'); ylabel('Measured delay (ms)');
legend('show', 'Interpreter', 'none'); grid on;
end
