function validate_mav_output(feature_csv, settings_mat, rejection_csv)
%VALIDATE_MAV_OUTPUT Validate a Stage 2 feature CSV against saved settings.
%   VALIDATE_MAV_OUTPUT() prompts for the feature CSV and settings MAT file.
%   An optional rejection-statistics CSV can be supplied as the third input.

if nargin < 1 || isempty(feature_csv)
    feature_csv = select_file('*.csv', 'Select the Stage 2 feature CSV');
end
if nargin < 2 || isempty(settings_mat)
    settings_mat = select_file('*.mat', 'Select preprocessing_settings.mat');
end
if nargin < 3
    rejection_csv = '';
end

loaded_settings = load(settings_mat, 'sets');
if ~isfield(loaded_settings, 'sets')
    error('The selected MAT file does not contain a variable named ''sets''.');
end
sets = loaded_settings.sets;

feature_table = read_pipeline_table(feature_csv);
key_variables = {'subject_ID', 'condition', 'trial_number', 'bin'};

if ~sets.do_baseline_correction
    unstandardized_suffix = 'MAV_raw';
elseif strcmp(sets.baseline_correction_method, 'subtraction')
    unstandardized_suffix = 'MAV_difference';
elseif strcmp(sets.baseline_correction_method, 'division')
    unstandardized_suffix = 'MAV_ratio';
else
    error('Unsupported baseline correction method in saved settings.');
end

if sets.do_standardization_muscle && sets.do_standardization_subject
    error('Saved settings enable both mutually exclusive standardization modes.');
elseif sets.do_standardization_muscle
    standardized_suffix = 'MAV_z_muscle';
elseif sets.do_standardization_subject
    standardized_suffix = 'MAV_z_subject';
else
    standardized_suffix = '';
end

expected_variables = key_variables;
feature_variables = {};
standardized_variables = {};
for ch = 1:length(sets.emg_channel_names)
    unstandardized_variable = ...
        [sets.emg_channel_names{ch}, '_', unstandardized_suffix];
    expected_variables{end + 1} = unstandardized_variable; %#ok<AGROW>
    feature_variables{end + 1} = unstandardized_variable; %#ok<AGROW>

    if ~isempty(standardized_suffix)
        standardized_variable = ...
            [sets.emg_channel_names{ch}, '_', standardized_suffix];
        expected_variables{end + 1} = standardized_variable; %#ok<AGROW>
        feature_variables{end + 1} = standardized_variable; %#ok<AGROW>
        standardized_variables{end + 1} = standardized_variable; %#ok<AGROW>
    end
end

actual_variables = feature_table.Properties.VariableNames;
if ~isequal(actual_variables, expected_variables)
    error(['Unexpected feature-table schema or column order.\nExpected: %s\nActual: %s'], ...
        strjoin(expected_variables, ', '), strjoin(actual_variables, ', '));
end

subjects = unique(string(feature_table.subject_ID));
for si = 1:length(subjects)
    subject_rows = string(feature_table.subject_ID) == subjects(si);
    if ~any(feature_table.bin(subject_rows) == 1)
        error('Subject %s has no pre-stimulus bin 1.', subjects(si));
    end
end

feature_data = feature_table{:, feature_variables};
any_missing = any(ismissing(feature_data), 2);
all_missing = all(ismissing(feature_data), 2);
if any(any_missing ~= all_missing)
    error('Some rows contain partially missing MAV-derived values.');
end

if ~isempty(standardized_variables) && ~sets.do_trial_averaging
    verify_standardization_invariants(...
        feature_table, sets, standardized_variables, subjects);
end

if ~isempty(rejection_csv)
    rejection_table = read_pipeline_table(rejection_csv);
    verify_rejected_trial_counts(feature_table, rejection_table, all_missing, subjects);
end

fprintf('\nMAV output validation PASSED: %s\n\n', feature_csv);
end

function verify_standardization_invariants(feature_table, sets, standardized_variables, subjects)
tolerance = 1e-8;
post_rows = feature_table.bin > 1;

if sets.do_standardization_muscle
    for si = 1:length(subjects)
        subject_rows = string(feature_table.subject_ID) == subjects(si);
        for ch = 1:length(standardized_variables)
            values = feature_table.(standardized_variables{ch})(subject_rows & post_rows);
            values = values(isfinite(values));
            if abs(mean(values)) > tolerance || abs(std(values, 0) - 1) > tolerance
                error('Post-stimulus z-score invariant failed for subject %s, muscle %s.', ...
                    subjects(si), sets.emg_channel_names{ch});
            end
        end
    end
else
    for si = 1:length(subjects)
        subject_rows = string(feature_table.subject_ID) == subjects(si);
        values = feature_table{subject_rows & post_rows, standardized_variables};
        values = values(isfinite(values));
        if abs(mean(values)) > tolerance || abs(std(values, 0) - 1) > tolerance
            error('Pooled post-stimulus z-score invariant failed for subject %s.', subjects(si));
        end
    end
end
end

function verify_rejected_trial_counts(feature_table, rejection_table, all_missing, subjects)
for si = 1:length(subjects)
    subject_rows = string(feature_table.subject_ID) == subjects(si);
    rejected_keys = unique(...
        feature_table(subject_rows & all_missing, {'condition', 'trial_number'}), ...
        'rows');

    stats_row = string(rejection_table.subject_ID) == subjects(si);
    if sum(stats_row) ~= 1
        error('Expected one rejection-statistics row for subject %s.', subjects(si));
    end

    if height(rejected_keys) ~= rejection_table.n_rejected_total(stats_row)
        error('Total rejected-trial count does not match for subject %s.', subjects(si));
    end

    conditions = unique(string(feature_table.condition(subject_rows)));
    for ci = 1:length(conditions)
        condition_variable = ['n_rejected_', char(conditions(ci))];
        if ismember(condition_variable, rejection_table.Properties.VariableNames)
            observed_count = sum(string(rejected_keys.condition) == conditions(ci));
            expected_count = rejection_table.(condition_variable)(stats_row);
            if observed_count ~= expected_count
                error('Rejected-trial count does not match for subject %s, condition %s.', ...
                    subjects(si), conditions(ci));
            end
        end
    end
end
end

function selected_file = select_file(filter_spec, prompt)
[file_name, file_path] = uigetfile(filter_spec, prompt);
if isequal(file_name, 0)
    error('File selection cancelled.');
end
selected_file = fullfile(file_path, file_name);
end

function output_table = read_pipeline_table(file_path)
import_options = detectImportOptions(file_path, 'TextType', 'string');
string_variables = intersect({'subject_ID', 'condition'}, import_options.VariableNames, 'stable');
if ~isempty(string_variables)
    import_options = setvartype(import_options, string_variables, 'string');
end
output_table = readtable(file_path, import_options);
end
