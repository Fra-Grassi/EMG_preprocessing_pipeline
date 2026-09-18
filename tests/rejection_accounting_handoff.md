# Tier 1.5 rejection accounting handoff (CD-18)

Baseline: `0f8c6f3`. Scoped files: Stage 2, `tests/test_rejection_accounting.m`, and this handoff. Stage 2 retains CRLF. No raw data, settings, thresholds, feature algorithms, shared plans, or wiki drafts were changed.

## Behavior

- Section 2.4.8 constructs only the current participant's rejection table. Section 2.4.16 stores it and writes the cumulative CSV after preprocessing, feature-table construction, existing calculation checks, and requested feature saving succeed. Only completed participants contribute rows; there are no preallocated blank CSV rows.
- An absent configured condition has numeric `NaN` for both count and fraction. A present condition with no flagged trials has `0` for both. Column names and configured condition order are unchanged, and `subject_ID` is text, preserving `001`.
- The existing `perc_*` encoding remains a **fraction from 0 to 1**, despite its name. CSV missing values should be imported into numeric columns as `NaN`; CSV readers may need explicit column types for an entirely missing column.
- Rejection saving requires its own toggle and at least one detection method. Turning saving off neither creates nor overwrites the rejection CSV. The rejected-feature-row toggle remains independent.
- The preprocessed SET intentionally retains all epochs and rejection marks. Section 2.4.11 removes flagged epochs before feature calculation and standardization. Optional rejected feature rows are restored with missing values afterward. Feature-checkpoint code is unchanged.

## Validation actually performed here

Static checks passed: scoped diff review, comparison against the baseline confirming unchanged detection, baseline correction, rejection, feature calculations and feature checkpoint; exclusive CRLF verification; and `git -c core.whitespace=cr-at-eol diff --check`.

MATLAB and Octave were not installed/on PATH in this environment. **The MATLAB suite, MATLAB Code Analyzer, Stage 2, and real EEGLAB/GUI acceptance were not run. No participant output files were generated here.** Runtime validation remains pending.

## Synthetic MATLAB R2024b checks (no EEGLAB required)

From the project root:

```matlab
results = runtests(fullfile('tests', 'test_rejection_accounting.m'));
assertSuccess(results);
checkcode('EMG_02_preprocessing_feature_extraction.m', '-id');
checkcode(fullfile('tests', 'test_rejection_accounting.m'), '-id');
```

The tests execute production Section 2.3 and Sections 2.4.8–2.4.16 using synthetic epochs. Controlled local functions substitute for detection/GUI/SET operations, while table construction, numerical feature calculations, validation failures, and CSV writes are real. CSVs are confined to temporary directories removed by test cleanup. GUI doubles do not open or close real windows. The tests check:

- automatic-only, manual-only, combined union, and disabled detection;
- configured missing conditions, present conditions with zero rejections, column ordering and leading-zero IDs;
- cumulative one- then two-participant CSVs with no blank rows;
- later-participant standardization failure and feature-save failure leaving the previous rejection CSV byte-for-byte intact, plus first-participant failure creating no CSV;
- no CSV creation/overwrite with statistics disabled, or with both detection methods disabled;
- statistics with feature saving disabled, and independence from rejected-row restoration;
- the saved SET-call input retaining flagged trials, clean feature values and standardization using retained trials, and optional rejected rows remaining missing;
- continuous execution versus executing each extracted production section once.

These substitutes test pipeline orchestration, not EEGLAB detection accuracy, actual SET serialization, or real manual GUI callbacks. Entry/settings/loading sections retain their existing tests. The continuous-versus-section test starts at already-epoched data; the following acceptance covers the actual Editor flow.

## Representative MATLAB R2024b / EEGLAB acceptance

Use current Stage 0 settings and disposable output folders/filenames; preserve raw inputs. Keep the intended stage active in the Editor. Record MATLAB/EEGLAB versions, warnings, test results, and output paths.

1. Run the synthetic checks above. In Stage 0 select two representative participants, with text IDs including a leading-zero ID if available. Keep scientific thresholds unchanged. Enable rejection statistics, preprocessed SET saving, and feature saving. Use automatic-only detection first. Run Stage 2 as a complete script. At a breakpoint before Section 2.4.16 on participant 1, the current run must not yet have written its rejection CSV. After this section, inspect exactly one completed row; after participant 2, inspect exactly two. Confirm the ordinary feature checkpoints still appear.
2. Read the rejection CSV with `subject_ID` explicitly imported as string and the rejection columns as double. Compare counts with each saved SET's `reject.rejglobal` and condition trial counts. Check `perc_rejected_total = n_rejected_total / original_epoch_count`. For a participant missing one configured condition (but having another), both corresponding values must be `NaN`; a present condition with no flags must be `0, 0`. Use an existing suitable participant/valid study configuration; do not edit raw data to create this case.
3. Repeat on representative data with manual-only and combined detection, using distinct output filenames. Follow the existing GUI instructions to keep marks. Verify the merged `rejglobal` against the CSV. Inspect the saved SET: original epochs and flags must remain. In feature output, rejected trials must be absent when row restoration is off, or have missing feature values when on. Toggle restoration independently of statistics saving.
4. With statistics saving off, rerun an enabled detection path using both a fresh rejection filename and an existing rejection CSV: neither creation nor overwrite should occur. With both detection methods off, turn rejected-row restoration off as required by the validator; even if statistics saving is on, no rejection CSV should be written. Features should contain all trials.
5. Verify later-participant recovery using a disposable run. Break just before Section 2.4.15 for participant 2 and set `sets.amplitudes_dir` to a nonexistent subdirectory. Continue and expect the feature write to fail. The rejection CSV must remain exactly the participant-1 version. Restore settings from Stage 0 before another run. The participant-2 preprocessed SET may already exist: it is an earlier inspection checkpoint, not evidence of completed feature processing.
6. Repeat a deterministic automatic-only case by Editor sections, starting with Sections 2.1–2.3 and then each participant subsection once in order through the new **2.4.16** (set `si = 1` when manually stepping a single participant). Compare rejection tables and feature outputs against the full-script run with the same inputs/settings. Do not rerun a preprocessing subsection on the same in-memory data (CD-12).

## Boundaries reported to Agent 0

No policy was added for a recording with zero trials in **every** configured condition; existing epoching/feature failure behavior remains. Existing fractional `perc_*` encoding was preserved and reported explicitly rather than changed to percentages. Real manual marking/unmarking and EEGLAB epoch/event alignment need representative acceptance; the controlled tests assume the existing one-condition-event-per-epoch contract. Direct `writetable` behavior is retained: this change protects prior CSVs from failures before the rejection write, not an operating-system interruption during that write.
