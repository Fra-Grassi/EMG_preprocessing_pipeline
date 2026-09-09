# Tier 1.3 settings validator handoff — Agent 0

Implementation starts from main `c088082` in the isolated
`codex/tier-1-3-settings-validator` branch. No scientific defaults, participant
processing calculations, or raw data were changed. CD-10 and CD-16 guide the
entry-point and current-settings contract; CD-04–07 and CD-11/13–15 are retained.

## Changed files and validation boundary

- `validate_settings.m`: one read-only validator with stage-specific checks.
- `EMG_00_settings.m`: resources-folder check moved into 0.1; 0.2 contains
  assignments and comments only; 0.3 calls the validator; usage comments explain
  automatic setup, validation, and saving. Existing folder creation remains
  create-only-if-missing.
- `EMG_01_raw2set_shift_triggers.m` and
  `EMG_02_preprocessing_feature_extraction.m`: validate after loading settings
  and before toolbox startup/processing. Add the inferred project root to the
  MATLAB path so the shared function resolves during Editor section execution.
- `tests/test_validate_settings.m`: portable synthetic MATLAB function tests.
- This handoff.

Stage 0 requires all 49 current fields, including inactive parameter fields,
but checks optional values only when their operation is enabled. Later stages
require only fields they access. Stage 1 needs all five shifting arguments when
shifting is enabled, even in fixed mode; unused photodiode values are not
validated in fixed mode. Stage 2 needs neither the BDF path nor the Stage 1
layout/shift settings. Output paths and filenames in Stage 2 are checked only
when the corresponding write can execute. Stage 0 checks all internal folders
because it establishes the complete configuration and saves settings.

EEGLAB and relevant input/output folders must exist. Only the selected EEG
layout requires its channel-location file; EMG-only requires neither file.
Folder existence does not establish an operational EEGLAB/BIOSIG/CleanLine
installation; that remains part of representative integration acceptance.

Moved all four Stage 0 combination rules: MAV/rectification, mutually exclusive
standardizations, rejected rows/trial averaging, and rejected rows/no rejection.
Removed exact configuration-only downstream checks for layout, main-filter
method, baseline method (both branches), MAV method, and complete feature bins.
The existing absolute tolerance of `1e-10` bins is preserved. Window checks
explicitly convert epoch seconds to milliseconds; baseline correction stays
within the documented pre-stimulus epoch and one complete pre-bin must fit.

Retained Stage 2 checks against actual `EMG.times(1)`, empty baseline/bin sample
selections, and inadequate/nonfinite/zero-SD standardization references. All
standalone `shift_triggers` checks remain. Actual recording channel bounds,
sampling rate/Nyquist constraints, epoch sampling and photodiode detections
remain data-dependent processing concerns. No checks are added to participant
loops. Filtering precedes downsampling, so the later downsampling rate is not
used as a substitute for the filter's input Nyquist frequency.

## Decision for Agent 0

Stage 0's general BioSemi description suggests any number of muscle pairs,
but Stage 2 selects bipolar subtraction only when the channel matrix has more
than one row. `[3 4]` therefore represents two single channels and requires two
muscle names; it cannot represent one bipolar muscle. The validator rejects
that one-name configuration with an explicit explanation. It also rejects
multirow matrices without exactly two columns. No channel logic or scientific
interface was changed. Agent 0 should resolve the one-muscle bipolar interface
under planned Tier 2.1 before documenting it as supported (for example, an
explicit recording-system setting versus an unambiguous shape rule).

## Checks performed here

MATLAB and Octave are unavailable; **MATLAB tests and production stages have not
been run**. Static inspection confirms:

- current Stage 0 assignments and the synthetic fixture cover the same 49 fields;
- Section 0.2 contains only settings assignments and comments;
- stage section identifiers and original LF (Stage 0)/CRLF (Stages 1–2) endings
  are preserved;
- the validator has no settings assignments, folder creation, file writes,
  settings migration, or participant-data loading;
- stage diffs retain production calculations and configured values;
- `git -c core.whitespace=cr-at-eol diff --check` passes.

These are static checks, not MATLAB syntax/runtime verification. No production
outputs were generated. The test fixture creates only disposable temporary
folders and an empty location-file placeholder used to test existence checks;
it does not pretend to validate EEGLAB resource contents.

## Exact MATLAB commands and acceptance sequence

From the project root in MATLAB:

```matlab
addpath(pwd);
results = runtests(fullfile('tests', 'test_validate_settings.m'));
disp(results);
assertSuccess(results);
checkcode('validate_settings.m');
checkcode(fullfile('tests', 'test_validate_settings.m'));
```

Then, in the MATLAB Editor (the active script determines project paths):

1. Open `EMG_00_settings.m`; configure actual external paths and approved
   settings in 0.2. Run it with F5. Confirm `resources/preprocessing_settings.mat`
   and `resources/preprocessing_settings.txt` exist and existing output contents
   remain intact. Repeat 0.1, 0.2, 0.3, 0.4 once in order to exercise sections.
2. Open and activate `EMG_01_raw2set_shift_triggers.m`; run a representative BDF
   through the whole script. Confirm the raw SET/FDT output and, when shifting
   is enabled, diagnostics MAT/plots. Repeat using sections in order, beginning
   with 1.1, with each participant's processing subsections executed once.
3. Open and activate `EMG_02_preprocessing_feature_extraction.m`; process the
   representative raw SET. Confirm configured preprocessed SET/FDT, rejection
   CSV, and feature CSV outputs. Repeat by sections starting at 2.1, once each
   per participant, and compare outputs to the full-script run. Preserve the
   first run's outputs separately before rerunning because normal saves overwrite.
4. For raw-BDF independence, after a successful Stage 0 run, make the external
   BDF source unavailable (for example disconnect its drive) while keeping raw
   SET/FDT and EEGLAB accessible. Stage 2 must still pass 2.1 and process the
   existing SET. Do not rerun Stage 0 while its configured BDF source is absent.

Do not change saved settings or skip entry validation during section runs;
change Stage 0 and restart the stage if configuration changes. Record MATLAB
version, test results, integration outputs, and any warnings/errors for Agent 0.
