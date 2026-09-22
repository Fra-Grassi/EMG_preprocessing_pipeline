function tests = test_lightweight_provenance
% Actual production save sections, real MAT/TXT I/O, controlled Git/SET doubles.
% No EEGLAB, GUI, network, or participant data required.
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
project_dir = fileparts(fileparts(mfilename('fullpath')));
testCase.TestData.original_path = path;
addpath(project_dir);
source = fileread(fullfile(project_dir, 'EMG_00_settings.m'));
start_idx = strfind(source, '%% 0.4 - Save settings');
assert(isscalar(start_idx));
testCase.TestData.stage0 = source(start_idx:end);
source = fileread(fullfile(project_dir, 'EMG_01_raw2set_shift_triggers.m'));
testCase.TestData.stage1 = source_between(source, ...
    '%% 1.3.6 - Save SET file', '    fprintf([');
source = fileread(fullfile(project_dir, 'EMG_02_preprocessing_feature_extraction.m'));
testCase.TestData.stage2 = source_between(source, ...
    '%% 2.4.10 - Save preprocessed datasets', '%% 2.4.11 - Remove flagged trials');
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testSettingsSavedWithReadableNestedVersions(testCase)
result = run_settings(testCase.TestData.stage0, 'available', 'available');
verify_settings_outputs(testCase, result);
verifyEqual(testCase, result.sets.eeglab_version, '2025.1.0');
verifyEqual(testCase, result.sets.plugin_versions, ...
    struct('BIOSIG', 'biosig3.8.4', 'CleanLine', 'cleanline2.1', 'FIRfilt', 'firfilt2.8'));
verifyEqual(testCase, result.sets.pipeline_git_commit, repmat('a', 1, 40));
end

function testUnavailableVersionsAreNonfatal(testCase)
% Missing files, unrecognized declarations, multiple installations, read errors.
for mode = {'missing', 'malformed', 'ambiguous', 'read_error'}
    result = run_settings(testCase.TestData.stage0, mode{1}, 'available');
    verify_settings_outputs(testCase, result);
    verifyEqual(testCase, result.sets.eeglab_version, 'unavailable');
    verifyEqual(testCase, struct2cell(result.sets.plugin_versions), ...
        repmat({'unavailable'}, 3, 1));
    verifyEqual(testCase, result.sets.pipeline_git_commit, repmat('a', 1, 40));
end
end

function testMissingOnePluginDoesNotHideOtherVersions(testCase)
result = run_settings(testCase.TestData.stage0, 'missing_cleanline', 'available');
verify_settings_outputs(testCase, result);
verifyEqual(testCase, result.sets.eeglab_version, '2025.1.0');
verifyEqual(testCase, result.sets.plugin_versions, ...
    struct('BIOSIG', 'biosig3.8.4', 'CleanLine', 'unavailable', 'FIRfilt', 'firfilt2.8'));
end

function testUnavailableGitIsNonfatalAndRestoresFolder(testCase)
for mode = {'nonzero', 'error', 'malformed', 'no_repository'}
    result = run_settings(testCase.TestData.stage0, 'available', mode{1});
    verify_settings_outputs(testCase, result);
    verifyEqual(testCase, result.sets.pipeline_git_commit, 'unavailable');
    verifyEqual(testCase, result.sets.eeglab_version, '2025.1.0');
end
end

function testAllOptionalInformationUnavailable(testCase)
result = run_settings(testCase.TestData.stage0, 'missing', 'nonzero');
verify_settings_outputs(testCase, result);
verifyEqual(testCase, result.sets.eeglab_version, 'unavailable');
verifyEqual(testCase, struct2cell(result.sets.plugin_versions), repmat({'unavailable'}, 3, 1));
verifyEqual(testCase, result.sets.pipeline_git_commit, 'unavailable');
end

function testBothSaveInputsHaveScalarEtcAndTimestamp(testCase)
base = struct('subject', '001', 'filename', '001_raw.set', ...
    'filepath', 'configured raw folder', 'data', [1 2 3]);
variants = {[], 'old text', {}, struct([]), repmat(struct('note', 1), 1, 2), ...
    struct(), struct('note', 'preserve me')};
for stage = 1:2
    code = testCase.TestData.(sprintf('stage%d', stage));
    for idx = 0:numel(variants)
        input = base;
        if idx > 0
            input.etc = variants{idx};
        end
        result = run_set_save(code, input, true);
        saved = result.captured;
        verifyTrue(testCase, isstruct(saved.etc) && isscalar(saved.etc));
        verify_timestamp(testCase, saved.etc.creation_timestamp);
        verifyEqual(testCase, saved.data, input.data);
        verifyEqual(testCase, saved.subject, '001');
        if idx == numel(variants)
            verifyEqual(testCase, rmfield(saved.etc, 'creation_timestamp'), input.etc);
        else
            verifyEqual(testCase, fieldnames(saved.etc), {'creation_timestamp'});
        end
        if stage == 1
            verifyEqual(testCase, saved.filename, input.filename);
            verifyEqual(testCase, saved.filepath, input.filepath);
        else
            verifyEqual(testCase, saved.filename, '001_preprocessed.set');
            verifyEqual(testCase, saved.filepath, 'configured processed folder');
        end
    end
end
end

function testStage2ReplacesInheritedTimestampAndHonorsToggle(testCase)
raw = struct('subject', '001', 'filename', '001_raw.set', ...
    'filepath', 'configured raw folder', 'data', [1 2 3], ...
    'etc', struct('creation_timestamp', '2000-01-01T00:00:00+00:00', 'note', 'retain'));
original = raw;
result = run_set_save(testCase.TestData.stage2, raw, true);
verify_timestamp(testCase, result.captured.etc.creation_timestamp);
verifyNotEqual(testCase, result.captured.etc.creation_timestamp, raw.etc.creation_timestamp);
verifyEqual(testCase, result.captured.etc.note, raw.etc.note);
verifyEqual(testCase, raw, original);
disabled = run_set_save(testCase.TestData.stage2, raw, false);
verifyEqual(testCase, disabled, raw); % No double called and no timestamp changed.
end

function result = run_settings(code, version_mode, git_mode)
root = tempname;
mkdir(root);
cleanup = onCleanup(@() rmdir(root, 's')); %#ok<NASGU>
sets.project_dir = fullfile(root, 'project with spaces');
sets.utilities_dir = fullfile(root, 'settings output');
sets.eeglab_dir = fullfile(root, 'eeglab');
mkdir(sets.project_dir);
mkdir(sets.utilities_dir);
mkdir(sets.eeglab_dir);
if ~strcmp(git_mode, 'no_repository')
    write_text(fullfile(sets.project_dir, '.git'), 'test metadata; Git is doubled');
end
names = {'eeg_getversion.m', 'eegplugin_biosig.m', ...
    'eegplugin_cleanline.m', 'eegplugin_firfilt.m'};
versions = {'2025.1.0', 'biosig3.8.4', 'cleanline2.1', 'firfilt2.8'};
folders = {'functions/adminfunc', 'plugins/Biosig/biosig/eeglab', ...
    'plugins/cleanline', 'plugins/firfilt'};
if ~strcmp(version_mode, 'missing')
    for idx = 1:numel(names)
        if strcmp(version_mode, 'missing_cleanline') && idx == 3
            continue
        end
        folder = fullfile(sets.eeglab_dir, folders{idx});
        mkdir(folder);
        source = sprintf(['%% vers = ''ignore comment'';\n', ...
            'function vers = fixture\n  vers = ''%s'';\n', ...
            'error(''Fixture:Executed'', ''Version files must only be read.'');\nend\n'], versions{idx});
        if strcmp(version_mode, 'malformed')
            source = sprintf('%% vers = ''comment only'';\nvers = compute_version();\n');
        end
        write_text(fullfile(folder, names{idx}), source);
        if strcmp(version_mode, 'ambiguous')
            duplicate = fullfile(sets.eeglab_dir, 'duplicate', folders{idx});
            mkdir(duplicate);
            write_text(fullfile(duplicate, names{idx}), source);
        end
    end
end
original_sets = sets;
original_dir = pwd;
system = @(command) git_double(command, git_mode, sets.project_dir); %#ok<NASGU>
fileread = @(filename) version_read_double(filename, version_mode); %#ok<NASGU>
eval(code);
assert(strcmp(pwd, original_dir), 'Stage 0 must restore the caller folder, even after Git failure.');
loaded = load(fullfile(sets.utilities_dir, 'preprocessing_settings.mat'));
assert(isequal(fieldnames(loaded), {'sets'}), 'Only sets belongs in the MAT output.');
assert(isequal(loaded.sets, sets), 'The enriched settings must actually be saved.');
result.sets = loaded.sets;
result.original_sets = original_sets;
result.text = read_saved_text(fullfile(sets.utilities_dir, 'preprocessing_settings.txt'));
outputs = dir(sets.utilities_dir);
result.output_names = sort({outputs(~ismember({outputs.name}, {'.', '..'})).name});
end

function verify_settings_outputs(testCase, result)
fields = {'timestamp'; 'operating_system'; 'matlab_version'; ...
    'eeglab_version'; 'plugin_versions'; 'pipeline_git_commit'};
verifyEqual(testCase, sort(fieldnames(result.sets)), ...
    sort([fieldnames(result.original_sets); fields]));
verifyEqual(testCase, rmfield(result.sets, fields), result.original_sets);
verifyEqual(testCase, result.output_names, ...
    {'preprocessing_settings.mat', 'preprocessing_settings.txt'});
verify_timestamp(testCase, result.sets.timestamp);
verifyTrue(testCase, isscalar(result.sets.plugin_versions));
for idx = [1:4 6]
    name = fields{idx};
    value = result.sets.(name);
    verifyTrue(testCase, ischar(value) && isrow(value) && ~isempty(value));
    verifyTrue(testCase, contains(result.text, sprintf('%s\t: %s', name, value)));
end
for name = {'BIOSIG', 'CleanLine', 'FIRfilt'}
    value = result.sets.plugin_versions.(name{1});
    verifyTrue(testCase, ischar(value) && isrow(value) && ~isempty(value));
    verifyTrue(testCase, contains(result.text, ...
        sprintf('plugin_versions.%s\t: %s', name{1}, value)));
end
end

function verify_timestamp(testCase, value)
verifyTrue(testCase, ischar(value) && isrow(value));
verifyNotEmpty(testCase, regexp(value, ...
    '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(Z|[+-]\d{2}:\d{2})$', 'once'));
end

function EMG = run_set_save(code, EMG, enabled)
sets.do_save_preprocessed_data = enabled;
sets.fname_preprocessed_data = '_preprocessed';
sets.processed_dir = 'configured processed folder';
pop_saveset = @(dataset, varargin) save_double(dataset, varargin{:}); %#ok<NASGU>
eval(code);
end

function result = save_double(dataset, varargin)
assert(isequal(varargin, {'filename', dataset.filename, 'filepath', dataset.filepath}));
assert(isfield(dataset.etc, 'creation_timestamp'), 'Timestamp must exist before pop_saveset.');
result = struct('captured', dataset);
end

function [status, value] = git_double(command, mode, expected_dir)
assert(strcmp(command, 'git rev-parse --verify HEAD 2>&1'));
assert(strcmp(pwd, expected_dir));
status = 0;
value = [repmat('a', 1, 40) newline];
if strcmp(mode, 'error')
    error('Fixture:GitError', 'Simulated unavailable system/Git access.');
elseif strcmp(mode, 'nonzero')
    status = 127;
    value = 'git unavailable';
elseif strcmp(mode, 'malformed')
    value = 'not a commit';
end
end

function source = version_read_double(filename, mode)
if strcmp(mode, 'read_error')
    error('Fixture:ReadError', 'Simulated unreadable local version source.');
end
source = fileread(filename);
end

function source = read_saved_text(filename)
% Separate scope avoids the runner's controlled version-source reader.
source = fileread(filename);
end

function write_text(filename, text)
fid = fopen(filename, 'w');
assert(fid ~= -1);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s', text);
end

function code = source_between(source, start_marker, stop_marker)
start_idx = strfind(source, start_marker);
stop_idx = strfind(source, stop_marker);
assert(isscalar(start_idx) && isscalar(stop_idx) && start_idx < stop_idx, ...
    'Production section markers changed; review the test extraction boundaries.');
code = source(start_idx:stop_idx - 1);
end
