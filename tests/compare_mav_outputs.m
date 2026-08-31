function compare_mav_outputs(first_csv, second_csv, tolerance)
%COMPARE_MAV_OUTPUTS Compare two Stage 2 feature CSV files.
%   Useful for full-script versus section execution and for helper-backed
%   versus final inline implementations.

if nargin < 1 || isempty(first_csv)
    first_csv = select_csv('Select the first MAV feature CSV');
end
if nargin < 2 || isempty(second_csv)
    second_csv = select_csv('Select the second MAV feature CSV');
end
if nargin < 3 || isempty(tolerance)
    tolerance = 1e-12;
end

first_table = read_pipeline_table(first_csv);
second_table = read_pipeline_table(second_csv);

if ~isequal(first_table.Properties.VariableNames, second_table.Properties.VariableNames)
    error('The two CSV files have different variable names or column order.');
end

key_variables = {'subject_ID', 'condition', 'trial_number', 'bin'};
if ~all(ismember(key_variables, first_table.Properties.VariableNames))
    error('One or more composite-key columns are missing.');
end

first_table = sortrows(first_table, key_variables);
second_table = sortrows(second_table, key_variables);

if height(first_table) ~= height(second_table)
    error('The two CSV files contain different numbers of rows.');
end

variables = first_table.Properties.VariableNames;
for vi = 1:length(variables)
    variable = variables{vi};
    first_values = first_table.(variable);
    second_values = second_table.(variable);

    if isnumeric(first_values) && isnumeric(second_values)
        compare_numeric(first_values, second_values, variable, tolerance);
    else
        if ~isequaln(string(first_values), string(second_values))
            error('Non-numeric values differ in column %s.', variable);
        end
    end
end

fprintf('\nMAV output comparison PASSED\nFirst:  %s\nSecond: %s\n\n', ...
    first_csv, second_csv);
end

function compare_numeric(first_values, second_values, variable, tolerance)
first_missing = ismissing(first_values);
second_missing = ismissing(second_values);
if ~isequal(first_missing, second_missing)
    error('Missingness patterns differ in column %s.', variable);
end

finite_values = isfinite(first_values) & isfinite(second_values);
if any(abs(first_values(finite_values) - second_values(finite_values)) > tolerance)
    error('Numeric values differ beyond tolerance in column %s.', variable);
end

nonfinite_values = ~finite_values & ~first_missing & ~second_missing;
if any(first_values(nonfinite_values) ~= second_values(nonfinite_values))
    error('Nonfinite numeric values differ in column %s.', variable);
end
end

function selected_file = select_csv(prompt)
[file_name, file_path] = uigetfile('*.csv', prompt);
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
