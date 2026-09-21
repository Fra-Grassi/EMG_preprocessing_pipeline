# Tier 1.5 rejection accounting handoff (revised checkpoint timing)

Original baseline: `0f8c6f3`; this revision follows researcher feedback on `f3116f5`. The explicit request to save immediately after rejection calculation supersedes CD-18's original completed-feature-processing timing requirement; its missing-condition rule remains unchanged. Scoped files: Stage 2, `tests/test_rejection_accounting.m`, and this handoff. Stage 2 retains CRLF. No raw data, settings, thresholds, feature algorithms, shared plans, or wiki drafts were changed.

## Behavior

- Section 2.4.8 constructs the current participant's rejection table and immediately stores it and writes the cumulative CSV. Only participants whose rejection statistics have been calculated contribute rows; there are no preallocated blank CSV rows. There is no separate Section 2.4.16.
- If a later baseline or feature step fails, the current participant's rejection row remains in the CSV. The feature CSV checkpoint remains at its existing later point in Section 2.4.15 and may therefore contain fewer participants than the rejection CSV.
- An absent configured condition has numeric `NaN` for both count and fraction. A present condition with no flagged trials has `0` for both. Column names and configured condition order are unchanged, and `subject_ID` is text, preserving `001`.
- The existing `perc_*` encoding remains a **fraction from 0 to 1**, despite its name. CSV missing values should be imported into numeric columns as `NaN`; CSV readers may need explicit column types for an entirely missing column.
- Rejection saving requires its own toggle and at least one detection method. Turning saving off neither creates nor overwrites the rejection CSV. The rejected-feature-row toggle remains independent.
- The preprocessed SET intentionally retains all epochs and rejection marks. Section 2.4.11 removes flagged epochs before feature calculation and standardization. Optional rejected feature rows are restored with missing values afterward. Feature-checkpoint code is unchanged.

## Validation actually performed here

Static checks passed: scoped diff review, comparison against `f3116f5` confirming unchanged detection, rejection calculations, baseline correction, trial removal, feature calculations and feature checkpoint; exclusive CRLF verification; and `git -c core.whitespace=cr-at-eol diff --check`.

The researcher reported that all synthetic tests and runs on two representative participants passed at `f3116f5`. After the checkpoint-timing revision, the researcher also reported the revised MATLAB tests and a real-data check passing on 2026-09-18. MATLAB and Octave remain unavailable on the coordinator machine; no participant output files were generated there.

## Synthetic MATLAB R2024b checks (no EEGLAB required)

From the project root:

```matlab
results = runtests(fullfile('tests', 'test_rejection_accounting.m'));
assertSuccess(results);
checkcode('EMG_02_preprocessing_feature_extraction.m', '-id');
checkcode(fullfile('tests', 'test_rejection_accounting.m'), '-id');
```

The tests execute production Section 2.3 and Sections 2.4.8–2.4.15 using synthetic epochs. Controlled local functions substitute for detection/GUI/SET operations, while table construction, numerical feature calculations, validation failures, and CSV writes are real. CSVs are confined to temporary directories removed by test cleanup. GUI doubles do not open or close real windows. The tests check:

- automatic-only, manual-only, combined union, and disabled detection;
- configured missing conditions, present conditions with zero rejections, column ordering and leading-zero IDs;
- cumulative one- then two-participant CSVs with no blank rows;
- immediate CSV availability after Section 2.4.8 alone, before any feature step;
- later-participant standardization failure and feature-save failure retaining both rejection rows while the feature CSV still contains only participant 1; first-participant feature failure retaining one rejection row and creating no feature CSV;
- no CSV creation/overwrite with statistics disabled, or with both detection methods disabled;
- statistics with feature saving disabled, and independence from rejected-row restoration;
- the saved SET-call input retaining flagged trials, clean feature values and standardization using retained trials, and optional rejected rows remaining missing;
- continuous execution versus executing each extracted production section once.

These substitutes test pipeline orchestration, not EEGLAB detection accuracy, actual SET serialization, or real manual GUI callbacks. Entry/settings/loading sections retain their existing tests. The continuous-versus-section test starts at already-epoched data; the following acceptance covers the actual Editor flow.

## Representative MATLAB R2024b / EEGLAB acceptance

Use current Stage 0 settings and disposable output folders/filenames; preserve raw inputs. Keep the intended stage active in the Editor. Record MATLAB/EEGLAB versions, warnings, test results, and output paths.

1. Run the synthetic checks above. In Stage 0 select two representative participants, with text IDs including a leading-zero ID if available. Keep scientific thresholds unchanged. Enable rejection statistics, preprocessed SET saving, and feature saving. Use automatic-only detection first. Run Stage 2 as a complete script. Break at the start of Section 2.4.9, immediately after rejection accounting: the rejection CSV must already contain exactly one row for participant 1, then exactly two at the same point for participant 2. Neither participant needs to have finished feature processing for its rejection row to appear. Confirm the ordinary feature checkpoints still appear.
2. Read the rejection CSV with `subject_ID` explicitly imported as string and the rejection columns as double. Compare counts with each saved SET's `reject.rejglobal` and condition trial counts. Check `perc_rejected_total = n_rejected_total / original_epoch_count`. For a participant missing one configured condition (but having another), both corresponding values must be `NaN`; a present condition with no flags must be `0, 0`. Use an existing suitable participant/valid study configuration; do not edit raw data to create this case.
3. Repeat on representative data with manual-only and combined detection, using distinct output filenames. Follow the existing GUI instructions to keep marks. Verify the merged `rejglobal` against the CSV. Inspect the saved SET: original epochs and flags must remain. In feature output, rejected trials must be absent when row restoration is off, or have missing feature values when on. Toggle restoration independently of statistics saving.
4. With statistics saving off, rerun an enabled detection path using both a fresh rejection filename and an existing rejection CSV: neither creation nor overwrite should occur. With both detection methods off, turn rejected-row restoration off as required by the validator; even if statistics saving is on, no rejection CSV should be written. Features should contain all trials.
5. Verify later-participant recovery using a disposable run. Break just before Section 2.4.15 for participant 2 and set `sets.amplitudes_dir` to a nonexistent subdirectory. Continue and expect the feature write to fail. The rejection CSV must contain both participants, with the participant-1 row unchanged. The feature CSV must still contain only participant 1. Restore settings from Stage 0 before another run. The participant-2 preprocessed SET may already exist: it is an earlier inspection checkpoint, not evidence of completed feature processing.
6. Repeat a deterministic automatic-only case by Editor sections, starting with Sections 2.1–2.3 and then each participant subsection once in order through **2.4.15** (set `si = 1` when manually stepping a single participant). Compare rejection tables and feature outputs against the full-script run with the same inputs/settings. Do not rerun a preprocessing subsection on the same in-memory data (CD-12).

## Boundaries reported to Agent 0

No policy was added for a recording with zero trials in **every** configured condition; existing epoching/feature failure behavior remains. Existing fractional `perc_*` encoding was preserved and reported explicitly rather than changed to percentages. Real manual marking/unmarking and EEGLAB epoch/event alignment need representative acceptance; the controlled tests assume the existing one-condition-event-per-epoch contract. Direct `writetable` behavior is retained; writes are not transactional. A saved rejection row establishes completion of rejection accounting only, not completion of preprocessing or features.

## Tier 2 participant-key regression extension (Agent 9, 2026-09-21)

This extension changes only `tests/test_rejection_accounting.m` and this handoff, covering CD-02, CD-03, and CD-04 without changing production or scientific assumptions. The existing two-participant fixture still uses IDs `001` and `P007` with the same condition/trial/bin combinations. Participant 2 now receives a synthetic trial-dependent offset of `100 + trial_number^2` on every sample. Raw values differ for every retained key, and the trial-dependent offset also makes the standardized arrays distinguishable; a constant participant offset alone would disappear under standardization.

For automatic-only, manual-only, combined, and disabled rejection, and both applicable rejected-row settings, assertions now inspect each participant table, each cumulative in-memory feature checkpoint, and its actual CSV readback. They check:

- unique `subject_ID + condition + trial_number + bin` keys and preservation of both participants' otherwise identical keys;
- string IDs, including exact preservation of `001` before and after CSV writing (readback explicitly imports `subject_ID` as string);
- exactly the configured `n_bins` rows and the complete expected bin sequence for every restored rejected trial, as well as retained trials;
- missing values in **all** feature columns discovered after the four keys on rejected rows, and nonmissing values in all those columns on retained rows;
- analytic participant-specific raw MAV and muscle-standardized values, including after cumulative aggregation and CSV readback;
- absence of rejected keys in clean-only output.

All existing checkpoint/failure assertions remain. The seven test functions outside the expanded rejection-mode test are byte-for-byte unchanged. Static validation passed: `git diff --check`, scoped diff review, preservation checks against the baseline, and an independent Python arithmetic check of the synthetic bin means, nonzero standardization reference SDs, and participant distinguishability for every rejection mode. The researcher subsequently reported that the extended MATLAB R2024b suite passed and that `assertSuccess` completed successfully on 2026-09-21. MATLAB and Octave remain unavailable on the coordinator machine. No participant outputs or raw data were generated or changed during this extension.

Exact MATLAB R2024b command from the MATLAB Command Window for this isolated worktree:

```matlab
cd('/private/tmp/emg-tier2-agent9-20260921');
fprintf('MATLAB release: %s\n', version('-release'));
results = runtests(fullfile('tests', 'test_rejection_accounting.m'));
assertSuccess(results);
checkcode(fullfile('tests', 'test_rejection_accounting.m'), '-id');
```

The fixture remains limited to one muscle, two bins, five already-epoched trials per participant, raw MAV, muscle-wise standardization, no trial averaging, and matching rejection masks across participants. It does not establish multi-muscle, baseline-correction, subject-standardization, or all-trials-rejected behavior. Generic missingness checks will include added feature columns, but this fixture currently creates only raw and muscle-standardized CS columns. Detection, GUI operations, and SET saving remain controlled substitutes; real EEGLAB serialization, preprocessing before Section 2.4.8, and manual interaction need the representative acceptance checks above. Temporary CSV files are removed by the existing fixture cleanup. The 2026-09-21 R2024b run passed; after comment-only analyzer cleanup, all three targeted Code Analyzer checks returned no output.
