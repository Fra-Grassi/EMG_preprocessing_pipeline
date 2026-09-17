# Tier 1.4: file selection and participant identity

The researcher approved cancellation before participant processing, loading from the dialog's returned directory, and `fileparts` filename-stem identity (`001.bdf` → character `'001'`). Stage 2 continues to read `EMG.subject`. No empty-ID or duplicate-ID checks, numeric conversion, new Stage 0 naming option, or generic parser are included. This follows CD-01 (paths), CD-02 (text identity), CD-12 (section execution), and CD-16 (current Stage 0 settings). Agent 0 owns updates to the shared plan and decision register, whose older Tier 1.4 checklist still mentions duplicate checks.

## Automated MATLAB checks

From the repository root in MATLAB:

```matlab
results = runtests(fullfile('tests', 'test_file_selection_identity.m'));
disp(table(results));
assertSuccess(results);
checkcode('EMG_01_raw2set_shift_triggers.m');
checkcode('EMG_02_preprocessing_feature_extraction.m');
checkcode(fullfile('tests', 'test_file_selection_identity.m'));
```

The three test functions cover both stages' cancellation, single and multiple selections, configured initial filters, alternate selected directories, `001`/`002`/`P007` stems, default/custom output suffixes, saved-subject use after a SET rename, and string feature keys. They read and execute the production selection, loading, metadata, saving, and table-construction statements. Dialog and EEGLAB calls are replaced by local in-memory doubles. No GUI, EEGLAB installation, real input files, or disk outputs are needed. Extraction markers intentionally fail if the relevant production sections move or are renamed, prompting review of the test boundaries.

Cancellation tests execute each production stage from the selection section through its end and verify early return. The empty file list also establishes zero iterations for a subsequently executed participant loop. These tests do not exercise Editor behavior, EEGLAB serialization, preprocessing, or CSV serialization; use the acceptance steps below for those.

## Representative MATLAB / EEGLAB acceptance

Use a validation checkout with empty output directories so this exercise creates only new outputs. Use an existing representative `001.bdf` input read-only. Configure and run the **current Stage 0** in that checkout with the study's approved settings and available EEGLAB/BIOSIG/plugins. Keep the standard `_raw` suffix for this acceptance run. Do not change preprocessing choices for this file-selection check. Record MATLAB and EEGLAB/plugin versions and all warnings/errors.

1. **Cancel full scripts.** Run Stage 1 with its Editor tab active and cancel the selector. Repeat with Stage 2 active. Each must print its cancellation message, return without an error, and leave all output directories unchanged. Neither should load a participant; Stage 2 should not print `Output variables CREATED`. Setup still loads/validates settings and starts EEGLAB before the selector.
2. **Cancel section execution.** In Stage 1, run Section 1.1 followed by 1.2 and cancel. Confirm `iscell(file) && isempty(file)`. Repeat with Stage 2 Sections 2.1 and 2.2. Stop after cancellation. To test the empty-loop safeguard separately, select and execute the entire remaining script below the selection section: no participant load/save should occur (Stage 2 may create empty output variables in memory). Do not execute an individual inner-loop subsection without its required loop state. Restart at the entry section before the next run.
3. **Stage 1 alternate directory.** Ensure the configured `sets.rawBDF_dir` exists but differs from the folder containing the representative `001.bdf`. With Stage 1 active, run the full script, browse to that other folder, and select `001.bdf`. After completion, run:

   ```matlab
   assert(~strcmp(thissubjectpath, sets.rawBDF_dir)); % also inspect the paths
   assert(ischar(EMG.subject) && strcmp(EMG.subject, '001'));
   expected_raw = ['001' sets.fname_raw_data '.set'];
   assert(strcmp(EMG.filename, expected_raw));
   assert(isfile(fullfile(sets.rawSET_dir, expected_raw)));
   loaded_raw = pop_loadset('filename', expected_raw, 'filepath', sets.rawSET_dir);
   assert(ischar(loaded_raw.subject) && strcmp(loaded_raw.subject, '001'));
   ```

   Path strings can differ only by a trailing separator, so visually confirm these are actually different folders. If trigger shifting is enabled, confirm `001_trigger_shift_diagnostics.mat` is present too; its calculation and naming are unchanged.
4. **Stage 2 alternate directory and full identity path.** Copy the newly generated SET **and its associated FDT if present** to a separate validation input folder. Keep filenames intact for this real-file test (the deterministic test separately checks renamed SET metadata). Run Stage 2 with its tab active, browse to that folder, and select the SET. After completion:

   ```matlab
   assert(~strcmp(thissubjectpath, sets.rawSET_dir)); % confirm distinct folders
   assert(ischar(EMG.subject) && strcmp(EMG.subject, '001'));
   assert(strcmp(subj_ID, '001'));
   assert(~isempty(checkpoint_features_table));
   assert(isstring(checkpoint_features_table.subject_ID));
   assert(all(checkpoint_features_table.subject_ID == "001"));
   if sets.do_save_preprocessed_data
       expected_processed = ['001' sets.fname_preprocessed_data '.set'];
       assert(isfile(fullfile(sets.processed_dir, expected_processed)));
       loaded_processed = pop_loadset('filename', expected_processed, ...
           'filepath', sets.processed_dir);
       assert(strcmp(loaded_processed.subject, '001'));
   end
   if sets.do_save_features_amplitudes
       csv_path = fullfile(sets.amplitudes_dir, sets.fname_feature_amplitudes);
       assert(isfile(csv_path));
       opts = detectImportOptions(csv_path);
       opts = setvartype(opts, 'subject_ID', 'string');
       saved_features = readtable(csv_path, opts);
       assert(all(saved_features.subject_ID == "001"));
   end
   if sets.do_save_trial_rejection_stats && ...
           (sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual)
       assert(isfile(fullfile(sets.processed_dir, sets.fname_trial_rejection_stats)));
   end
   ```

   Read CSV IDs explicitly as text; automatic numeric type inference can discard leading zeros. Choose representative data with retained feature rows; an empty feature table is not evidence for this identity check.
5. **Successful sections and batch selection.** In fresh validation outputs configured via Stage 0, repeat the successful run by Editor sections, starting with each stage's entry section and running each processing section once using the existing loop workflow. Repeat the assertions above. If a second representative `002.bdf` is available, also select both files in one dialog and confirm `001` and `002` remain distinct in saved SET subjects and the final table. Record whether this optional real-data batch check was run; synthetic selection and stem checks cover both IDs independently.

## Local validation status

MATLAB and Octave are unavailable in the implementation worktree. The MATLAB tests, Code Analyzer, GUI cancellation/section behavior, and representative EEGLAB run have **not been executed** here. No participant data or generated outputs were created or modified. Python/static inspection checks CRLF preservation, focused diffs, cancellation before loops, selected-directory loading, `fileparts` extraction, and the unchanged Stage 2 text-key construction. MATLAB acceptance remains pending.
