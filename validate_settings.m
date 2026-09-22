function validate_settings(sets, stage)
%VALIDATE_SETTINGS Check current Stage 0 settings without changing them or disk.
%   validate_settings(sets, 'stage0') checks the complete configuration.
%   'stage1' and 'stage2' check only their execution requirements. Run once
%   at stage entry, including when executing subsequent sections individually.
%   Optional values are checked only when used; Stage 0 still requires every
%   current field. Sampling-rate and other recording-dependent checks belong
%   in processing code. No saved-settings migration or defaults are supplied.

if ~isstruct(sets) || ~isscalar(sets)
    error('validate_settings:InvalidSetting', ...
        'sets must be a scalar struct. Configure Stage 0, Section 0.2 and rerun Stage 0.');
end
if ~ischar(stage) || ~isrow(stage) || ~ismember(stage, {'stage0', 'stage1', 'stage2'})
    error('validate_settings:InvalidStage', 'Use stage0, stage1, or stage2 as the validation stage.');
end
is_stage0 = strcmp(stage, 'stage0');
check_import = is_stage0 || strcmp(stage, 'stage1');
check_processing = is_stage0 || strcmp(stage, 'stage2');
internal_paths = {'project_dir', 'rawSET_dir', 'processed_dir', 'amplitudes_dir', 'utilities_dir'};
processing_toggles = {'do_filtering_main', 'do_filtering_notch', ...
    'do_downsampling', 'do_rectifying', 'do_artefact_detection_automatic', ...
    'do_artefact_detection_manual', 'do_baseline_correction', ...
    'do_standardization_muscle', 'do_standardization_subject', ...
    'do_trial_averaging', 'do_save_trial_rejection_stats', ...
    'do_save_preprocessed_data', 'do_save_features_amplitudes', 'do_save_rejected_trial_rows'};

if is_stage0
    % Complete current schema, including fields whose values may be inactive.
    need([internal_paths, {'study_name', 'rawBDF_dir', 'eeglab_dir', ...
        'recording_layout', 'condition_triggers', 'condition_names', ...
        'emg_reference_mode', 'emg_channel_numbers', 'emg_channel_names', 'do_shift_triggers', ...
        'shift_method', 'shift_markers', 'shift_window', 'shift_threshold', ...
        'shift_minimum_duration_ms', 'filter_type_main', 'filter_cutoff_main', ...
        'filter_cutoff_notch', 'downsample_rate', 'rectify_method', 'epoch_length', ...
        'artefact_threshold_baseline', 'artefact_threshold_trial', ...
        'baseline_correction_window', 'baseline_correction_method', ...
        'feature_extraction_method', 'feature_extraction_bin_dur', ...
        'fname_raw_data', 'fname_trial_rejection_stats', 'fname_preprocessed_data', ...
        'fname_feature_amplitudes'}, processing_toggles]);
    text_setting('study_name');
    for k = 1:numel(internal_paths)
        folder(internal_paths{k});
    end
end
folder('eeglab_dir');
folder('rawSET_dir');

if check_import
    folder('rawBDF_dir');
    option('recording_layout', {'EMG', 'EEG_64', 'EEG_128'});
    text_setting('fname_raw_data');
    if ~strcmp(sets.recording_layout, 'EMG')
        folder('utilities_dir');
        if strcmp(sets.recording_layout, 'EEG_64')
            resource = 'chanloc_biosemi_64.elp';
        else
            resource = 'chanloc_biosemi_128.ced';
        end
        if ~isfile(fullfile(sets.utilities_dir, resource))
            invalid('utilities_dir', ['must contain ', resource, ' for recording_layout.']);
        end
    end
    toggle('do_shift_triggers');
    if sets.do_shift_triggers
        % All arguments are accessed by Stage 1, even for fixed shifting.
        need({'shift_method', 'shift_markers', 'shift_window', ...
            'shift_threshold', 'shift_minimum_duration_ms'});
        if isempty(sets.shift_markers)
            codes('condition_triggers');
        elseif ischar(sets.shift_markers) && isrow(sets.shift_markers)
            % Standalone shift_triggers also accepts a single exact code.
        else
            codes('shift_markers');
        end
        if isnumeric(sets.shift_method)
            numeric_scalar('shift_method', false);
        else
            % The production shifting function requires character method names.
            text_setting('shift_method');
            option('shift_method', {'variable', 'median'});
            window('shift_window');
            if sets.shift_window(1) > -0.029 || sets.shift_window(2) <= 0
                invalid('shift_window', 'must include [-0.029, 0] seconds and post-trigger data.');
            end
            numeric_scalar('shift_threshold', true);
            numeric_scalar('shift_minimum_duration_ms', true);
        end
    end
end

if check_processing
    for k = 1:numel(processing_toggles)
        toggle(processing_toggles{k});
    end
    codes('condition_triggers');
    codes('condition_names');
    if numel(sets.condition_triggers) ~= numel(sets.condition_names)
        invalid('condition_names', 'must have the same number of entries as condition_triggers, in matching order.');
    end
    codes('emg_channel_names');
    text_setting('emg_reference_mode');
    option('emg_reference_mode', {'single', 'bipolar'});
    need({'emg_channel_numbers'});
    channels = sets.emg_channel_numbers;
    if ~isnumeric(channels) || ~ismatrix(channels) || isempty(channels) || ...
            ~isreal(channels) || any(~isfinite(channels(:))) || ...
            any(channels(:) < 1 | channels(:) ~= fix(channels(:)))
        invalid('emg_channel_numbers', 'must be a nonempty matrix of positive integer channel indices.');
    end
    if strcmp(sets.emg_reference_mode, 'single')
        if ~isvector(channels)
            invalid('emg_channel_numbers', 'must be a row or column vector in single mode.');
        end
        if numel(sets.emg_channel_names) ~= numel(channels)
            invalid('emg_channel_names', 'requires one name per selected channel in single mode.');
        end
    else
        if size(channels, 2) ~= 2
            invalid('emg_channel_numbers', 'must have exactly two columns in bipolar mode.');
        end
        if numel(sets.emg_channel_names) ~= size(channels, 1)
            invalid('emg_channel_names', 'requires one name per channel pair in bipolar mode.');
        end
    end

    option('feature_extraction_method', {'mav'});
    if sets.do_rectifying
        option('rectify_method', {'abs'});
    end
    % The four original Section 0.3 combination checks (CD-05/07/04).
    if ~(sets.do_rectifying && isfield(sets, 'rectify_method') && strcmp(sets.rectify_method, 'abs'))
        invalid('do_rectifying / rectify_method', 'MAV extraction requires do_rectifying = 1 and rectify_method = ''abs''.');
    end
    if sets.do_standardization_muscle && sets.do_standardization_subject
        invalid('do_standardization_muscle / do_standardization_subject', 'cannot both be enabled; select one reference distribution or disable both.');
    end
    if sets.do_save_rejected_trial_rows && sets.do_trial_averaging
        invalid('do_save_rejected_trial_rows / do_trial_averaging', 'cannot retain rejected trial rows when trial averaging is enabled.');
    end
    do_rejection = sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual;
    if sets.do_save_rejected_trial_rows && ~do_rejection
        invalid('do_save_rejected_trial_rows', 'requires at least one enabled artefact detection method.');
    end

    if sets.do_filtering_main
        option('filter_type_main', {'lowpass', 'highpass', 'bandpass'});
        if strcmp(sets.filter_type_main, 'bandpass')
            window('filter_cutoff_main');
            if sets.filter_cutoff_main(1) <= 0
                invalid('filter_cutoff_main', 'must contain two positive increasing cutoffs in Hz.');
            end
        else
            numeric_scalar('filter_cutoff_main', true);
        end
    end
    if sets.do_filtering_notch
        numeric_scalar('filter_cutoff_notch', true);
        if sets.filter_cutoff_notch <= 2.5
            invalid('filter_cutoff_notch', 'must exceed 2.5 Hz so the existing +/-2.5 Hz notch band has a positive lower edge.');
        end
    end
    % Filtering precedes resampling: cutoff Nyquist checks need the loaded
    % recording rate, not the configured subsequent downsampling rate.
    if sets.do_downsampling
        numeric_scalar('downsample_rate', true);
    end
    if sets.do_artefact_detection_automatic
        numeric_scalar('artefact_threshold_baseline', true);
        numeric_scalar('artefact_threshold_trial', true);
    end

    window('epoch_length');
    numeric_scalar('feature_extraction_bin_dur', true);
    epoch_ms = double(sets.epoch_length) * 1000;
    bin_ms = double(sets.feature_extraction_bin_dur);
    if any(~isfinite(epoch_ms)) || epoch_ms(1) > -bin_ms || epoch_ms(2) <= 0
        invalid('epoch_length / feature_extraction_bin_dur', ...
            'epoch_length (seconds) must contain the full [-bin_duration, 0] feature bin (milliseconds) and positive post-stimulus time.');
    end
    n_post_bins = epoch_ms(2) / bin_ms;
    if ~isfinite(n_post_bins) || round(n_post_bins) < 1 || ...
            abs(n_post_bins - round(n_post_bins)) > 1e-10
        invalid('epoch_length / feature_extraction_bin_dur', ...
            'post-stimulus seconds * 1000 must be a whole number of feature bins in milliseconds (tolerance 1e-10 bins).');
    end
    if sets.do_baseline_correction
        option('baseline_correction_method', {'subtraction', 'division'});
        window('baseline_correction_window');
        baseline_ms = double(sets.baseline_correction_window);
        if baseline_ms(1) < epoch_ms(1) || baseline_ms(2) > min(0, epoch_ms(2))
            invalid('baseline_correction_window', ...
                'must lie inside the pre-stimulus epoch; baseline is in milliseconds, epoch_length in seconds.');
        end
    end

    if sets.do_save_preprocessed_data || (do_rejection && sets.do_save_trial_rejection_stats)
        folder('processed_dir');
    end
    if sets.do_save_preprocessed_data
        text_setting('fname_preprocessed_data');
    end
    if do_rejection && sets.do_save_trial_rejection_stats
        text_setting('fname_trial_rejection_stats');
    end
    if sets.do_save_features_amplitudes
        folder('amplitudes_dir');
        text_setting('fname_feature_amplitudes');
    end
end

    function need(fields)
        for j = 1:numel(fields)
            if ~isfield(sets, fields{j})
                invalid(fields{j}, 'is missing; rerun the current Stage 0 to save a complete configuration.');
            end
        end
    end

    function toggle(field)
        need({field});
        value = sets.(field);
        if ~(islogical(value) || isnumeric(value)) || ~isscalar(value) || ...
                ~isreal(value) || ~(value == 0 || value == 1)
            invalid(field, 'must be scalar logical true/false or numeric 0/1.');
        end
    end

    function numeric_scalar(field, positive)
        need({field});
        value = sets.(field);
        if ~isnumeric(value) || ~isscalar(value) || ~isreal(value) || ~isfinite(value)
            invalid(field, 'must be a finite real numeric scalar.');
        end
        if positive && value <= 0
            invalid(field, 'must be positive.');
        end
    end

    function window(field)
        need({field});
        value = sets.(field);
        if ~isnumeric(value) || ~isvector(value) || numel(value) ~= 2 || ...
                ~isreal(value) || any(~isfinite(value)) || value(1) >= value(2)
            invalid(field, 'must be a finite real two-element vector with start < end.');
        end
    end

    function text_setting(field)
        need({field});
        value = sets.(field);
        if ~ischar(value) || ~isrow(value) || isempty(value)
            invalid(field, 'must be a nonempty character vector (single quotes).');
        end
    end

    function option(field, choices)
        need({field});
        value = sets.(field);
        if ~((ischar(value) && isrow(value)) || (isstring(value) && isscalar(value) && ~ismissing(value))) || ...
                ~any(strcmp(value, choices))
            invalid(field, ['must be one of: ', strjoin(choices, ', '), '.']);
        end
    end

    function codes(field)
        need({field});
        value = sets.(field);
        if ~iscell(value) || ~isrow(value) || isempty(value) || ...
                ~all(cellfun(@(x) ischar(x) && isrow(x) && ~isempty(x), value))
            invalid(field, 'must be a nonempty row cell array of character vectors; preserve exact encoded content.');
        end
    end

    function folder(field)
        need({field});
        value = sets.(field);
        if ~((ischar(value) && isrow(value) && ~isempty(value)) || ...
                (isstring(value) && isscalar(value) && ~ismissing(value) && strlength(value) > 0)) || ~isfolder(value)
            invalid(field, 'must name an existing folder.');
        end
    end

    function invalid(field, explanation)
        section = '0.2';
        if any(strcmp(field, internal_paths))
            section = '0.1';
        end
        error('validate_settings:InvalidSetting', ...
            '%s: %s Check Stage 0, Section %s.', field, explanation, section);
    end
end
