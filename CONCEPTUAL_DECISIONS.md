# EMG Preprocessing Pipeline: Conceptual Decisions

Last updated: 2026-09-07
Applies to validated baseline: commit `3786055`

## Purpose and scope

This document records why the pipeline behaves as it does. It is source material for future GitHub wiki documentation and shared context for development agents. It should distinguish three things clearly:

1. decisions already implemented and validated;
2. assumptions inherited from the current pipeline or its upstream sources;
3. questions that still require scientific or engineering review.

The pipeline is derived from the EEGLAB-based workflow described by Rutkowska et al. (2024) and the associated `EMG_Pipelines` repository, with project-specific modifications. This file is not yet a methods manuscript and should not be treated as a substitute for citing the original method.

## Decision register

Agents should cite these identifiers in implementation handoffs and wiki drafts. Detailed rationale appears in the corresponding sections below.

| ID | Approved decision | Status |
| --- | --- | --- |
| CD-01 | Infer project-internal paths from the active MATLAB Editor script and construct them with `fullfile`. | Implemented and validated |
| CD-02 | Treat participant IDs as strings and identify feature rows with `subject_ID + condition + trial_number + bin`. | Implemented and validated |
| CD-03 | Build rejected-trial joins participant-locally and rewrite the cumulative feature checkpoint after each completed participant. | Implemented and validated |
| CD-04 | Keep rejection-statistics saving distinct from restoration of rejected feature rows; restored values are missing, not zero. | Implemented and validated |
| CD-05 | Process MAV as rectification, trial-wise waveform baseline correction, clean-trial binning, post-stimulus-derived standardization, then optional averaging. | Implemented and validated |
| CD-06 | Use half-open feature bins except for inclusion of the final epoch endpoint; do not apply `abs` after baseline correction. | Implemented and validated |
| CD-07 | Treat muscle-wise and subject-pooled z scoring as alternatives, use sample SD, exclude the pre-bin from estimation, and transform every bin. | Implemented and validated |
| CD-08 | Keep a wide output with adjacent unstandardized and standardized columns per muscle and method-specific names. | Implemented and validated |
| CD-09 | Keep Stage 2 production calculations inline after helper-backed validation; retain helpers only as test references. | Implemented and validated |
| CD-10 | Add one entry-point settings validator later rather than accumulating redundant checks inside participant loops. | Approved direction; not implemented |
| CD-11 | Convert all event types to MATLAB character vectors without altering experimenter-encoded character content; configure trigger codes as characters and add no audit field. | Implemented and validated |
| CD-12 | Treat Stage 2 section execution as non-idempotent: users run each section once and rely on completion messages rather than per-section duplicate-execution guards. | Implemented and validated existing behavior |

Trigger shifting does not yet have an approved decision ID. Worker agents must treat related conclusions as proposals until Agent 0 and the researcher approve them. New approved decisions should receive the next available ID rather than rewriting an existing entry.

## Cross-agent knowledge protocol

- `PROJECT_PLAN.md` is authoritative for work status, dependencies, and file ownership.
- This file is authoritative for approved conceptual behavior.
- Worker agents should read both files at the assigned baseline commit and cite relevant decision IDs in their final handoff.
- Workers should report a proposed decision with its rationale, alternatives, scientific impact, and validation implications; they should not silently add it to this register.
- Agent 0 discusses material proposals with the researcher, updates the register after approval, and communicates the new ID to implementation and documentation agents.
- Wiki drafts may paraphrase approved entries but must link each substantive claim to a decision ID or mark it as unresolved.

## Pipeline stages and data ownership

### Stage 0: configuration

`EMG_00_settings.m` defines preprocessing choices and saves the `sets` structure plus a human-readable text snapshot in `resources`.

Project-internal directories are derived from the active Stage 0 script:

- `raw`: SET files produced from acquisition files;
- `preprocessed`: processed SET checkpoints and trial-rejection statistics;
- `extracted_amplitudes`: cumulative feature tables;
- `resources`: tracked channel-location resources and generated settings snapshots.

The raw BDF source directory and EEGLAB installation remain external because they are not properties of the repository. Output directories are created only if they do not already exist. Rerunning Stage 0 does not delete their contents, although later output-writing commands may intentionally replace files with the same configured filename.

### Stage 1: acquisition format to raw SET

Stage 1 imports selected BDF files, normalizes supported event-marker forms, optionally shifts selected triggers, assigns participant metadata, and saves one raw SET file per participant. The obsolete dyad-specific data model was removed: every selected file is treated as an independent participant dataset.

### Event representation contract

All imported `EEG.event.type` values are represented as MATLAB character vectors. Conversion changes only MATLAB type and does not rewrite the trigger value encoded by the experimenter:

- numeric `121` becomes character `'121'`;
- character `'121'` remains `'121'`;
- string `"121"` becomes character `'121'`;
- character Brain Vision markers such as `'S 121'` and `'S121'` remain exactly unchanged;
- prefixes, spacing, leading zeros, and textual event names are preserved.

No original-value audit field is added. Stage 0 requires trigger settings to be entered as character vectors and explains that the pipeline converts event types to characters, consistent with the character-based event handling used by relevant EEGLAB functions.

Stage 2 retains its existing approach of copying each matching trigger event and replacing the copy's type with the configured condition name. Because the whole source event is copied, its latency and other event metadata are preserved. Trigger matching uses exact character comparison.

Stage 2 sections are intentionally not protected against repeated execution on the same in-memory structure. Running any preprocessing section twice may alter the result, so section-level users are responsible for running each section once. The completion message at the end of each section is the execution cue. Section 2.4.2 therefore receives no special duplicate-label guard.

### Stage 2: preprocessing and feature output

Stage 2 selects EMG channels, performs optional bipolar re-referencing, filtering, downsampling, rectification, epoching, artifact detection, trial-wise waveform baseline correction, rejection, feature extraction, feature standardization, and optional condition-level trial averaging.

The saved preprocessed SET is a checkpoint before flagged epochs are removed. This preserves the signals and rejection marks for inspection. Feature extraction, by contrast, uses retained trials only.

## Project-path resolution and section execution

Stages 0–2 infer the project root with:

```matlab
fileparts(matlab.desktop.editor.getActiveFilename)
```

This choice was made because the researcher commonly executes Stage 1 and Stage 2 by MATLAB Editor sections as well as as complete scripts. In MATLAB R2024b, the current working directory during section execution may point to a temporary Editor directory, so `pwd` and relative paths can resolve incorrectly. The active-editor API continues to identify the actual script file.

Consequences:

- a stage should be open and active in the MATLAB Editor when it is run;
- project-internal paths should be built with `fullfile` from the inferred root;
- stages should not depend on the process working directory;
- compatibility with later MATLAB versions is expected but should be recorded when actually tested.

## Participant identity and cumulative feature aggregation

### Identity contract

Participant identifiers are strings. This preserves meaningful prefixes and leading zeros. A feature row is identified by the four-part key:

```text
subject_ID + condition + trial_number + bin
```

Including `subject_ID` is essential because different participants normally share condition labels, trial numbers, and bin numbers. Joining on only the latter three fields allows rows from different participants to match incorrectly.

### Participant-local construction

Stage 2 builds a separate feature table for each participant. If rejected trials should remain visible, it also builds a complete trial-by-bin skeleton for that participant from the pre-rejection event table. Retained features are left-joined onto that skeleton using all four key fields.

This gives rejected observations an explicit representation: their key columns remain present, while every MAV-derived value is missing. Rejected data are not replaced with zero, because zero would be a measured amplitude and would bias summaries or models.

### Incremental checkpoint behavior

After a participant completes preprocessing and table construction, its table is added to the collection of successful participants. Stage 2 then rewrites the cumulative feature CSV inside the participant loop. If a later participant fails before reaching this point, the previous CSV still contains all earlier completed participants.

The current implementation deliberately uses a direct `writetable` call. More elaborate uniqueness and temporary-file helper functions were removed to keep the production script readable. Early validation of duplicate participant inputs is planned separately rather than repeating cross-participant join checks after code that already uses participant-local joins.

## Distinct rejection-output settings

Two related outputs are controlled independently:

- `sets.do_save_trial_rejection_stats` and `sets.fname_trial_rejection_stats` control the summary table containing rejection counts and percentages;
- `sets.do_save_rejected_trial_rows` controls whether rejected trials are restored as missing rows in the final feature-amplitude table.

The distinction matters because a researcher may want a rejection report without carrying rejected observations into the analysis table, or vice versa. Rejected-row restoration is incompatible with condition-level trial averaging, because an averaged row no longer maps to an individual rejected trial.

## MAV processing model

The validated order of operations is:

```text
full-wave rectification
    -> trial-wise waveform baseline correction
    -> rejection of flagged trials
    -> non-overlapping binned feature extraction
    -> post-stimulus-derived standardization
    -> optional condition-level trial averaging
```

Each step has a separate interpretation and should not be reordered without an explicit scientific decision and new validation.

### 1. Full-wave rectification

For a raw EMG sample `x`, full-wave rectification is:

```text
r = abs(x)
```

MAV requires `sets.do_rectifying = 1` and `sets.rectify_method = 'abs'`. Rectification occurs once, before baseline correction. The pipeline must not take an absolute value again after subtractive baseline correction, because a below-baseline response is meaningfully negative.

### 2. Trial-wise waveform baseline correction

For each muscle channel and each trial, let `b` be the ordinary mean of rectified samples in the configured baseline-correction window. The interval is left-inclusive and right-exclusive:

```text
baseline_start <= time < baseline_end
```

The supported transformations are:

- no correction: `c(t) = r(t)`;
- subtraction: `c(t) = r(t) - b`;
- division: `c(t) = r(t) / b`.

The correction is applied to the full epoched waveform, not independently within each feature bin. It is calculated separately for every trial and muscle.

No custom check is performed for a zero, nonfinite, or otherwise unusable divisive baseline mean. This was an explicit scope decision: such a value is treated as evidence of a larger data-quality problem that should be detected during quality control, and MATLAB's native arithmetic behavior is allowed to apply.

### 3. Non-overlapping binned feature extraction

After correction, each output feature is the ordinary mean of the corrected waveform samples inside a bin:

```text
feature(trial, muscle, bin) = mean(c(samples in bin))
```

Calling this quantity MAV reflects that the underlying signal was fully rectified before correction. The extractor does not apply `abs` again. Therefore:

- uncorrected values are raw MAV values;
- subtractively corrected values are MAV differences and may be negative;
- divisively corrected values are MAV ratios.

The output-column suffixes make this distinction explicit:

- `MAV_raw`;
- `MAV_difference`;
- `MAV_ratio`.

### 4. Bin boundaries

The pipeline creates one pre-stimulus bin of the configured duration and as many post-stimulus bins as fit exactly into the post-stimulus epoch. The post-stimulus duration must be an integer multiple of the bin duration.

Every bin is left-inclusive and right-exclusive, except the final post-stimulus bin, which includes the epoch's final endpoint:

```text
pre-bin:       [-D, 0)
post-bin 1:    [0, D)
post-bin 2:    [D, 2D)
...
final bin:     [end-D, end]
```

This convention prevents boundary samples from being counted twice while retaining the final sample. If the baseline-correction window exactly matches the pre-bin, subtractive correction makes that bin's mean zero and divisive correction makes it one, apart from floating-point precision. This identity does not apply when the correction window and pre-bin differ.

### 5. Trial rejection relative to feature estimation

Artifact flags are determined before baseline correction, and the preprocessed SET checkpoint retains the flagged epochs. Flagged trials are then removed before feature extraction and before standardization parameters are estimated. Consequently, rejected trials do not contribute to unstandardized feature values, reference means, reference standard deviations, or condition averages.

When requested, rejected rows are restored only after these calculations, with missing values in every MAV-derived column.

### 6. Post-stimulus-derived standardization

The pre-stimulus bin is retained for visualization and interpretation but is excluded from the reference distribution. Only finite feature observations from retained post-stimulus bins estimate the standardization parameters.

For reference observations `y`, the standardized feature is:

```text
z = (feature - mean(y)) / std(y)
```

MATLAB's sample-standard-deviation convention is used (`std(..., 0)`, denominator `n - 1`). The transform is then applied to every feature bin, including the pre-stimulus bin.

Two mutually exclusive reference distributions are available:

- muscle mode pools conditions, retained trials, and post-stimulus bins separately for each muscle;
- subject mode pools muscles, conditions, retained trials, and post-stimulus bins into one participant-level distribution.

These are alternative scientific normalizations, not two sequential transformations. Enabling both produces a settings error. A selected reference must contain at least two finite observations and have a finite, nonzero standard deviation.

### 7. Standardization before trial averaging

Standardization parameters are estimated from trial-level post-stimulus features. Both the unstandardized and standardized arrays are then carried independently into optional condition-level averaging.

This order preserves the intended trial-level reference distribution. Estimating the reference after averaging would change both its sample size and variance and would therefore define a different analysis.

### 8. Wide output schema

The feature table remains wide. Each muscle's unstandardized column is followed immediately by its standardized column when standardization is enabled. Examples are:

```text
CS_MAV_ratio, CS_MAV_z_muscle
OO_MAV_ratio, OO_MAV_z_muscle
```

Subject-pooled standardization uses `_MAV_z_subject`. When both standardization toggles are disabled, only the method-specific unstandardized columns are saved.

## MAV validation evidence

The numerical implementation was first extracted into three EEGLAB-independent helper functions so it could be tested deterministically. Tests covered:

- known raw, subtractive, and divisive values;
- non-duplication of shared bin boundaries and inclusion of the final endpoint;
- preservation of negative baseline differences;
- muscle-wise and subject-pooled reference means and sample standard deviations;
- exclusion of pre-stimulus values from reference estimation;
- pooling across conditions;
- standardization before trial averaging;
- invalid reference distributions;
- output keys, paired columns, ordering, rejected-row missingness, and z-score invariants;
- complete-script versus section execution;
- helper-backed versus final inline outputs.

All deterministic tests passed in MATLAB R2024b. The helper-backed and final inline Stage 2 integrations also passed the output validator and numerical comparisons. The validated reference implementations now live in `tests/helpers`; Stage 2 contains the same calculations inline and has no production dependency on them.

## Settings validation philosophy

The current code checks only known incompatible settings combinations in Stage 0. This keeps Stage 2 readable, but it means a user who edits a saved settings structure or runs a later stage independently can encounter a less informative downstream error.

The agreed future direction is one reusable settings validator invoked by every stage. Validation should happen near stage entry, not repeatedly inside participant loops. It should catch structural or configuration errors while avoiding speculative checks for scientifically possible but poor-quality data.

## Decisions intentionally deferred

The following points are not settled by the completed MAV work:

- automatic artifact-rejection thresholds and the scientific criteria used to select them;
- the validated behavior of variable photodiode trigger shifting;
- acceptable behavior when a configured condition contains zero trials;
- how output files should encode the exact settings and software versions used for a run;
- formal compatibility claims beyond the MATLAB R2024b tests already performed.

These items should be resolved through the tiered tasks in `PROJECT_PLAN.md`. When a decision is made, this document should be updated in the same integration cycle.
