% Run all deterministic MAV tests from the project tests folder.

clearvars

tests_dir = fileparts(mfilename('fullpath'));
helpers_dir = fullfile(tests_dir, 'helpers');
% The helper functions are test-only reference copies of the calculations
% that are implemented inline in Stage 2.
addpath(helpers_dir);

results = runtests(tests_dir, 'IncludeSubfolders', true);
disp(table(results));

if any([results.Failed]) || any([results.Incomplete])
    error('One or more MAV tests failed or did not complete.');
end

fprintf('\nAll deterministic MAV tests PASSED\n\n');
