# Participant-Safe Feature Outputs

This page explains how Stage 2 preserves participant identity, reconstructs rejected-trial rows, and checkpoints a cumulative feature table without allowing one participant's keys to match another participant's rows.

## Conceptual rationale

Participant identifiers are handled as text, preserving meaningful prefixes and leading zeros. Stage 1 takes the raw filename stem with `fileparts`: `001.bdf` becomes character `'001'` in `EMG.subject`. Stage 2 reads that saved subject and uses MATLAB strings in feature-table keys. See [Selecting files and adapting participant names](Project-Structure-and-Paths.md#selecting-files-and-adapting-participant-names) for the naming convention, configuration guidance, and Tier 1.4 validation. Filename correctness is the user's responsibility; empty-ID and duplicate-ID checks are intentionally absent.

Each bin-level feature row is identified by the composite key:

```text
subject_ID + condition + trial_number + bin
```

The levels are distinct:

- `subject_ID` identifies the participant;
- `condition` identifies the experimental condition within that participant;
- `trial_number` preserves the trial's original pre-rejection number;
- `bin` identifies the time bin within that trial.

Condition labels, trial numbers, and bin numbers commonly repeat across participants. Omitting `subject_ID` from a join would therefore allow a retained row from one participant to match the skeleton row of another. CD-02 makes all four fields part of the identity contract.

## Participant-local table construction

Stage 2 processes each participant into a separate feature table. After artifact flags have been assigned, it saves the pre-rejection event table before removing flagged epochs. Feature extraction and standardization then use only retained trials.

If `sets.do_save_rejected_trial_rows` is enabled, Stage 2 constructs a complete trial-by-bin skeleton for the current participant from that participant's pre-rejection events. It repeats every original trial once for each expected bin, adds the participant identifier, and left-joins the retained feature rows onto the skeleton using the complete four-field key.

A **left join** retains every row from the skeleton and attaches a matching retained feature row where one exists. The join is participant-local in both construction and key membership. A rejected trial has no retained feature row to attach, so its participant, condition, trial, and bin identifiers remain present while all MAV-derived cells are missing.

Missing does not mean zero. Zero is a numerical amplitude that could enter an average or model as an observed response. A missing value records that no feature was estimated because the trial was rejected. Restoring rejected rows is therefore a representation step after calculation, not an imputation step.

## Incremental cumulative checkpoint

The participant table is added to the collection only after that participant has completed preprocessing and feature-table construction. Stage 2 then concatenates the tables for participants completed so far and sorts the cumulative output by participant, configured condition order, trial, and bin. When feature saving is enabled, it rewrites the configured feature CSV inside the participant loop.

This file is an incremental recovery checkpoint. If a later participant fails before reaching the save point, the existing CSV still contains the earlier participants that completed successfully. The failing participant is not partially added because storage occurs only after its table construction completes.

The checkpoint is cumulative but not append-only: `writetable` rewrites the file after each successful participant. The current production implementation uses this direct write intentionally. More elaborate provenance or recovery behavior remains future work in `PROJECT_PLAN.md` and should not be inferred from the checkpoint design.

## Rejection statistics versus rejected feature rows

Two settings control different outputs:

- `sets.do_save_trial_rejection_stats` controls the summary table of rejection counts and percentages;
- `sets.do_save_rejected_trial_rows` controls whether rejected trials reappear as identifier-only, missing-amplitude rows in the feature table.

Saving a rejection report does not require restoring rejected feature rows, and restoring rows does not define whether the rejection report is saved. The distinction allows the researcher to choose an audit summary, an analysis-table representation, or both.

Rejected-row restoration is incompatible with condition-level trial averaging in the current settings checks. After averaging, a row represents a condition summary rather than one original trial, so it cannot be mapped back to an individual rejected trial.

## Wide-table organization

The output is **wide**: identifier columns appear first, followed by one or two feature columns for each muscle. An unstandardized column is always present for a muscle. When standardization is enabled, that muscle's standardized column appears immediately beside it. The exact suffixes depend on the baseline-correction and standardization modes and are described in [MAV Processing and Standardization](MAV-Processing-and-Standardization.md).

For a non-averaged output, one row represents one participant × condition × trial × bin combination. All MAV-derived columns on a restored rejected row are missing together; the output validator treats partially missing MAV rows as invalid.

## User-facing implications

- Read `subject_ID` as text when importing the CSV so prefixes and leading zeros remain intact.
- Use all four key fields when joining the feature output to another bin-level table.
- Do not convert restored missing amplitudes to zero unless a separate, explicitly approved analysis decision requires it.
- Treat the cumulative CSV as a checkpoint of successfully completed participants, not evidence that every selected participant completed.
- Interpret rejection-statistics output separately from whether rejected rows are retained in the feature table.

## Traceability

- **Decisions:** [CD-02 and CD-03](../CONCEPTUAL_DECISIONS.md#participant-identity-and-cumulative-feature-aggregation); [CD-04](../CONCEPTUAL_DECISIONS.md#distinct-rejection-output-settings).
- **Production file and sections:** [`EMG_02_preprocessing_feature_extraction.m`, Sections 2.3, 2.4.8, 2.4.11, 2.4.14, and 2.4.15](../EMG_02_preprocessing_feature_extraction.m).
- **Tests and recorded validation:** [`validate_mav_output.m`](../tests/validate_mav_output.m) checks keys, paired missingness, and optional rejection-count agreement; [`compare_mav_outputs.m`](../tests/compare_mav_outputs.m) compares keyed output and missingness; [PROJECT_PLAN.md, Tier 0.5 and the validation baseline](../PROJECT_PLAN.md#05-make-feature-aggregation-participant-safe) records the participant-safe implementation and output validation.
- **Current implementation status:** CD-02 through CD-04 are implemented and validated. On 2026-09-18, the researcher reported all Tier 1.4 MATLAB tests and checks passing, including batch selection and processing. Duplicate participant-input checks are excluded by the researcher's task approval. Rejection-accounting edge cases remain planned and are not represented as solved here.
