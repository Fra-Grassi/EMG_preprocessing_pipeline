# Lightweight provenance: Agent 12 handoff

Baseline: clean local `main` at `d26a3b252151fd2e34f69dc429a083210f94880c`.
Implementation follows revised CD-20 and Tier 2.3. No files from rejected
Agent 11 commit `7de164c` were used.

## Change and assumptions

- Stage 0 Section 0.4 adds the six requested fields to `sets` before the existing
  MAT/TXT saves. Section 0.2 and the text writer are unchanged.
- Timestamps are character vectors formatted `yyyy-MM-dd'T'HH:mm:ssXXX` in
  local time, including a numeric timezone offset (or `Z` for UTC).
- Version discovery reads the first literal `vers = '...'` declaration in
  `eeg_getversion.m` and the BIOSIG, CleanLine, and FIRfilt plugin entry files
  under **the configured `sets.eeglab_dir`**. It does not execute those files,
  launch EEGLAB, change the MATLAB path, or access the network. Declared labels
  are preserved, including plugin-name prefixes and revision bounds. These are
  locally declared versions, not a guarantee about which installation a later
  MATLAB session loads. Missing, unreadable, unrecognized, or duplicate sources
  yield `'unavailable'`; other version discoveries continue independently.
- This declaration convention was checked against local EEGLAB 2019.1,
  BIOSIG and FIRfilt sources, and upstream
  [EEGLAB](https://raw.githubusercontent.com/sccn/eeglab/develop/functions/adminfunc/eeg_getversion.m),
  [CleanLine](https://raw.githubusercontent.com/sccn/cleanline/master/eegplugin_cleanline.m),
  and [FIRfilt](https://raw.githubusercontent.com/widmann/firfilt/master/eegplugin_firfilt.m)
  source. No production network lookup is involved.
- Git discovery requires a `.git` file or directory in `sets.project_dir` and
  a successful `git rev-parse --verify HEAD` returning a 40-character hash.
  It temporarily enters that directory and restores the caller's directory,
  including on command failure. Missing metadata/Git or unrecognized output
  yields `'unavailable'`. The hash identifies HEAD, not uncommitted edits.
- Each SET save adds only `EMG.etc.creation_timestamp`. Existing scalar struct
  fields survive. Missing, nonstruct, empty, or nonscalar `etc` becomes a scalar
  struct. Stage 2 replaces the inherited timestamp only when saving is enabled.
- No new production helper, file, directory, run ID, manifest, CSV field,
  overwrite policy, settings migration, or processing change was added.

## MATLAB R2024b deterministic tests

Start MATLAB R2024b with this checkout as the current folder, then run:

```matlab
assert(strcmp(version('-release'), '2024b'));
assert(isfile('EMG_00_settings.m'));
addpath(pwd);
results = runtests('tests/test_lightweight_provenance.m');
disp(results);
assertSuccess(results);

regression = runtests({'tests/test_file_selection_identity.m', ...
    'tests/test_rejection_accounting.m', ...
    'tests/test_validate_settings.m', ...
    'tests/test_channel_selection.m'});
disp(regression);
assertSuccess(regression);
```

Equivalent shell command from the checkout (with R2024b `matlab` on PATH):

```sh
matlab -batch "assert(strcmp(version('-release'),'2024b')); addpath(pwd); r=runtests({'tests/test_lightweight_provenance.m','tests/test_file_selection_identity.m','tests/test_rejection_accounting.m','tests/test_validate_settings.m','tests/test_channel_selection.m'}); disp(r); assertSuccess(r);"
```

Expected: all seven focused tests and all selected regressions pass. The focused
suite uses real temporary MAT/TXT files and the unchanged writer. It checks all
six saved fields, readable nested plugin labels, unchanged input settings,
exact output filenames, independent discovery failures, Git failure and folder
restoration, SET-save inputs and arguments, scalar `etc`, preservation of other
metadata, replacement of an inherited timestamp, and the disabled Stage 2 save.
It uses timezone/format assertions rather than exact clock comparisons. Its
fixtures are cleaned up; no project settings or participant outputs are written.
The SET double checks the input to `pop_saveset`; real EEGLAB serialization is
covered by the acceptance procedure below.

## Code Analyzer

Run in the same R2024b session:

```matlab
files = {'EMG_00_settings.m', 'EMG_01_raw2set_shift_triggers.m', ...
    'EMG_02_preprocessing_feature_extraction.m', ...
    'tests/test_lightweight_provenance.m'};
for idx = 1:numel(files)
    fprintf('\n--- %s ---\n', files{idx});
    checkcode(files{idx}, '-id');
end
```

Expected: no syntax errors. Review diagnostics on added lines and report their
IDs and line numbers. Existing scripts and `eval`-based test fixtures may have
pre-existing or workspace-use diagnostics; do not suppress them without review.

## Representative Stage 0 / Stage 1 / Stage 2 acceptance

Use a disposable project copy with the same scripts/helpers/resources, a copied
representative BDF input, and separate empty output folders. Keep the existing
scientific settings appropriate for that fixture; only configure its external
paths in Section 0.2. Make sure the tested script is active in the MATLAB Editor
before each stage, as required by the existing path setup.

1. Run Stage 0 Sections 0.1--0.4 in order. Load and inspect the outputs:

   ```matlab
   saved = load(fullfile(sets.utilities_dir, 'preprocessing_settings.mat'), 'sets');
   disp(saved.sets.timestamp);
   disp(saved.sets.operating_system);
   disp(saved.sets.matlab_version);
   disp(saved.sets.eeglab_version);
   disp(saved.sets.plugin_versions);
   disp(saved.sets.pipeline_git_commit);
   type(fullfile(sets.utilities_dir, 'preprocessing_settings.txt'));
   ```

   Expect the six fields in MAT and readable values in TXT, including
   `plugin_versions.BIOSIG`, `.CleanLine`, and `.FIRfilt`. A disposable copy
   without `.git` should report `'unavailable'`. In a Git checkout, compare
   against `git rev-parse HEAD`. Confirm MATLAB's current folder is unchanged.

2. Run Stage 1 on one copied representative BDF. Reload its raw SET using
   EEGLAB `pop_loadset` and inspect `EMG.etc.creation_timestamp`: it must be a
   nonempty character vector with a timezone. Confirm the original filename,
   participant ID, channels, and event behavior. Save a byte-for-byte backup of
   this raw SET and its `.fdt` companion if present, outside the input folder.

3. Run Stage 2 with preprocessed saving enabled. Reload the preprocessed SET
   and inspect the same field: it must report Stage 2's save time. For this manual
   comparison run the stages in different seconds (the deterministic test uses
   an old inherited timestamp). Compare the raw SET/`.fdt` with the backups: they
   must remain byte-identical. Confirm the preprocessed checkpoint still retains
   rejection flags and original trial numbers before rejection. Check feature
   and rejection CSV columns, paths, and cumulative checkpoints against the
   fixture's baseline; they must be unchanged. With preprocessed saving disabled,
   no preprocessed SET should be written, as before.

## Local validation status

MATLAB and Octave were unavailable on this host. The MATLAB tests, Code Analyzer,
actual MAT/TXT serialization, and real EEGLAB acceptance are **not run** here.
No MATLAB success or warning-free result is claimed.

Static validation checked that removing only the six added lines at each SET
save reproduces the baseline Stage 1/2 files byte-for-byte. Stage 0 differs only
in the Section 0.4 metadata block and one usage comment. All section boundaries
and all Stage 1/2 CRLF endings are preserved; processing, CSV logic, filenames,
and existing save calls are unchanged. Only the three stages and these two test
and handoff files are changed.

Plain `git diff --check` flags the required CRLF bytes as trailing whitespace
under this repository's default configuration. The CRLF-aware check passes:

```sh
git -c core.whitespace=cr-at-eol diff --check d26a3b2
git diff --stat d26a3b2
git diff --name-only d26a3b2
```

No Git whitespace configuration was changed. Remaining validation is the R2024b
and real-data-copy acceptance above; no scientific assumptions were changed.
