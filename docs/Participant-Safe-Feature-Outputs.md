# Participant-Safe Feature Outputs

This page explains how Stage 2 preserves participant identity, represents rejected trials, and maintains cumulative rejection and feature outputs.

## Participant identity and row keys

Participant identifiers are handled as text so meaningful prefixes and leading zeros are preserved. Stage 1 takes the raw BDF filename stem with `fileparts`: `001.bdf` becomes character ID `'001'` in `EMG.subject`. Stage 2 reads that saved subject and uses text identifiers in its tables.

Filename correctness and uniqueness are the researcher's responsibility. Empty or duplicate participant IDs are not checked automatically.

Each non-averaged feature row is identified by the composite key:

```text
subject_ID + condition + trial_number + bin
```

The four levels have different meanings:

- `subject_ID` identifies the participant;
- `condition` identifies the condition within that participant;
- `trial_number` preserves the original pre-rejection trial number;
- `bin` identifies the time bin within that trial.

Condition labels, trial numbers, and bin numbers normally repeat across participants. Always include `subject_ID` when joining the feature table to other bin-level data.

## Participant-local construction

Stage 2 constructs one feature table at a time. After artifact flags are assigned, it stores the pre-rejection event information before removing flagged epochs. Feature extraction, standardization, and optional averaging use retained trials only.

If `sets.do_save_rejected_trial_rows` is enabled, Stage 2 builds a complete trial-by-bin skeleton for the current participant from the pre-rejection events. It then left-joins the retained feature rows onto that skeleton using all four key fields.

A **left join** keeps every skeleton row and attaches retained features where a matching observation exists. A rejected trial has no calculated feature row, so its participant, condition, trial, and bin identifiers remain present while every MAV-derived value is missing.

Missing does not mean zero. Zero is an observed numerical amplitude that can enter an average or model. A missing value indicates that no feature was estimated because the trial was rejected. Restoring rejected rows is a representation step, not imputation.

## Feature checkpoint

A participant is added to the cumulative feature table only after preprocessing and feature-table construction have completed for that participant. Stage 2 then concatenates all completed participant tables, sorts the rows, and rewrites the configured feature CSV.

If a later participant fails before reaching the feature save, the existing CSV still contains the earlier completed participants. The failing participant is not partially added.

The checkpoint is cumulative but not append-only: the whole file is rewritten after each completed participant. Writes are not transactional, and using the same filename on a later run can replace an existing output. Treat the CSV as a recovery checkpoint, not as proof that every selected participant completed.

## Rejection statistics and rejected feature rows are different outputs

Two settings control separate representations:

- `sets.do_save_trial_rejection_stats` controls the summary table of rejection counts and fractions;
- `sets.do_save_rejected_trial_rows` controls whether rejected trials reappear as identifier-only rows with missing amplitudes in the feature table.

The rejection-statistics CSV is checkpointed immediately after each participant's rejection statistics are calculated. The feature CSV is saved later, after feature-table construction. If a participant fails during later feature processing, that participant can appear in the rejection report while remaining absent from the feature CSV.

For a configured condition with no trials for a participant, both its rejected count and rejected fraction are `NaN`. A condition that is present but has zero rejected trials has `0` in both columns. Columns beginning with `perc_` contain fractions from 0 to 1, despite their names.

The separate case in which **all** configured conditions have zero trials is not given a special output policy. Epoching or later feature steps may fail, so researchers should verify trigger matching and trial counts before interpreting outputs.

Automatic-rejection thresholds are not universal defaults. Choose and justify them for each dataset according to data quality and the research question.

Rejected-row restoration cannot be combined with condition-level trial averaging. After averaging, a row represents a condition summary rather than an individual original trial, so rejected trials cannot be reconstructed as trial-level rows.

## Wide-table organization

Identifier columns appear first, followed by one or two feature columns for each muscle. Each muscle always has an unstandardized column. When standardization is enabled, its standardized column appears immediately beside it.

Muscle names and column order follow `sets.emg_channel_names`, matched to the selected source channels or bipolar pairs described in [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md#output-order-and-channel-metadata). Feature suffixes are described in [MAV Processing and Standardization](MAV-Processing-and-Standardization.md#6-wide-output-columns).

For non-averaged output, one row represents one participant × condition × trial × bin combination. On a restored rejected row, every MAV-derived column is missing together.

## Practical implications

- Import `subject_ID` as text in downstream software.
- Use all four key fields for trial-by-bin joins.
- Never recode restored missing amplitudes to zero without a separately justified analysis decision.
- Compare rejection counts with the appropriate pre-rejection trial totals.
- Interpret the rejection-statistics and feature checkpoints according to their different save points.
