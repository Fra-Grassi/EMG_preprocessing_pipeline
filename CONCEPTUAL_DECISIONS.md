# EMG Preprocessing Pipeline: Conceptual Decisions

Last updated: 2026-09-22
Latest researcher-tested implementation: CD-19 channel selection and re-referencing, integrated in `4e95048`; deterministic tests, a representative Stage 0/Stage 2 run, and targeted analyzer checks were reported passing on 2026-09-22.

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
| CD-10 | Use one stage-specific entry-point settings validator rather than accumulating redundant checks inside participant loops. | Implemented; researcher checks passed on 2026-09-09 |
| CD-11 | Convert all event types to MATLAB character vectors without altering experimenter-encoded character content; configure trigger codes as characters and add no audit field. | Implemented and validated |
| CD-12 | Treat Stage 2 section execution as non-idempotent: users run each section once and rely on completion messages rather than per-section duplicate-execution guards. | Implemented and validated existing behavior |
| CD-13 | Add signed delays to event latency, preserving the existing positive-delay direction; convert milliseconds to whole samples with `round(delay_ms * srate / 1000)`. | Integrated; synthetic and representative-run validation reported |
| CD-14 | Configure the range-divisor threshold (default 4) and crossing duration in milliseconds (default 20 ms); use the nearest zero-time sample with positive-side tie breaking. | Integrated; synthetic and representative-run validation reported |
| CD-15 | Add participant-level median shifting and median fallback for missing trial estimates, with warnings and separate diagnostics. | Integrated; synthetic and representative-run validation reported |
| CD-16 | Require settings from the current Stage 0; do not add compatibility fallbacks for saved development settings. | Implemented; researcher rerun passed |
| CD-17 | Use the raw BDF filename stem as the text participant ID; load from the directory returned by the file selector and stop cleanly on cancellation. Leave filename correctness to the user. | Implemented; researcher tests and representative runs passed on 2026-09-18 |
| CD-18 | Write each participant's rejection-statistics checkpoint immediately after its statistics are calculated, using only processed rows so far; represent a configured condition with zero trials by missing count and percentage (`NaN`). | Implemented; revised MATLAB tests and real-data check passed on 2026-09-18 |
| CD-19 | Configure EMG channel handling explicitly as `single` or `bipolar`; in bipolar mode each row is one muscle and is calculated as first channel minus second channel. | Implemented; deterministic and representative-run validation reported on 2026-09-22 |
| CD-20 | Identify each Stage 0 processing batch with a run ID while keeping user-selected data folders unchanged; archive a run manifest, tag outputs, append new participants across batches, and replace an existing participant only when explicitly enabled. | Approved; implementation and validation pending |

## Run provenance and cumulative cross-batch outputs (CD-20)

The user remains responsible for choosing the project folders and the subset of participants processed on each occasion. The pipeline must not scatter participant datasets into automatically generated run-specific data folders. Raw SET files, preprocessed SET files, rejection statistics, and feature amplitudes continue to use the configured study-level folders.

Each complete Stage 0 execution generates a filesystem-safe `sets.run_ID` for that settings snapshot and processing batch. Stage 0 continues to save the active `preprocessing_settings.mat` and readable settings text used by later stages. It also archives an immutable MAT and text run manifest under `resources/run_manifests/`, identified by the run ID. Current-settings behavior remains governed by CD-16; no fallback or silent migration is added for older development settings.

The run manifest contains the exact settings, run timestamp and timezone, MATLAB release and version, operating system, EEGLAB version, relevant plugin versions when available, the pipeline Git commit when available, and the selected inputs and generated outputs recorded by Stages 1 and 2. Missing optional Git or plugin version information is recorded as unavailable and may warn, but must not stop preprocessing. Later stages update the manifest for the active run rather than reorganizing participant data.

Every saved SET records its run ID and relevant provenance under `EMG.etc`. Cumulative rejection-statistics and feature CSVs include a `run_ID` metadata column. The feature table retains `subject_ID + condition + trial_number + bin` as its four-row key; `run_ID` identifies provenance and is not an additional scientific join key.

When a cumulative CSV already exists with the expected schema, newly processed participant IDs are appended to its existing participants. The file is still rewritten after each successfully completed participant, so CD-03 and CD-18 checkpoint behavior now protects both earlier batches and completed participants from the current batch. An incompatible existing schema, including a missing required provenance column, causes a clear error without silently migrating or replacing the file.

Stage 0 exposes `sets.do_overwrite_existing_participant_outputs`, defaulting to disabled. With overwriting disabled, an already existing participant SET target or participant ID in a cumulative CSV causes a clear error before that participant's existing output is replaced. With overwriting enabled, that participant's SET output and all of that participant's rows in the relevant cumulative CSV are replaced by the newly processed version and its new run ID. Other participants remain untouched. Ordinary within-run cumulative checkpoint rewriting is not treated as participant replacement.

## EMG channel selection and re-referencing (CD-19)

Stage 0 will define `sets.emg_reference_mode` as either `single` or `bipolar`, rather than asking Stage 2 to infer the operation from the shape of `sets.emg_channel_numbers`.

In `single` mode, `sets.emg_channel_numbers` is a vector containing one recorded source channel per output muscle, in the same order as `sets.emg_channel_names`. Stage 2 selects those channels without subtraction and preserves their source-channel metadata while applying the configured output labels.

In `bipolar` mode, `sets.emg_channel_numbers` is an `n_muscles`-by-2 matrix. Each row defines one output muscle as `first channel - second channel`, and the corresponding entry in `sets.emg_channel_names` supplies its label. A one-row pair such as `[3 4]` is therefore a valid one-muscle bipolar configuration. Because the result is a derived differential signal, its `chanlocs` entry must use the configured muscle label without falsely inheriting either source electrode's spatial metadata.

The settings validator will enforce the mode-specific shape and name count. Stage 2 will validate configured indices against the loaded dataset before selecting or subtracting data, then keep `EMG.data`, `EMG.nbchan`, `EMG.chanlocs`, and channel labels mutually consistent. CD-19 does not change the configured subtraction direction, feature calculations, rejection logic, or output schema.

Agent 10 implemented CD-19 in `4e95048`. The researcher reported that the validator and focused production-section tests passed in MATLAB R2024b, and that rerunning Stage 0 and Stage 2 on representative data completed successfully with the expected output. The only initial analyzer message was an obsolete test suppression, removed without executable changes in `6cea1ed`; the targeted post-cleanup analyzer check returned no messages.

## Rejection accounting (CD-18)

Immediately after calculating a participant's rejection statistics in Stage 2 Section 2.4.8, rewrite the cumulative rejection-statistics CSV with only the participants processed so far. Keep the calculation and its save together inside the participant loop, with no preallocated blank CSV rows. If a later feature-processing step fails for the current participant, that participant's rejection row remains in the CSV, while the separate feature checkpoint still contains only participants whose feature processing completed. This difference between the two checkpoints is intentional.

For a configured condition with no trials for a participant, write `NaN` in both its rejected-trial count and rejection-percentage columns. This distinguishes an absent condition from a present condition with zero rejected trials. Existing `perc_*` values remain fractions from 0 to 1. Scientific rejection thresholds are unchanged. The synthetic tests cover automatic-only, manual-only, combined, and disabled rejection paths.

Agent 6 commits `f3116f5` and `5f16bbb` were integrated as `c2d4bdc` and `7a08a45`. The researcher reported all original tests and two representative participant runs passing, then reported all revised tests and a real-data check passing after the Section 2.4.8 timing change. MATLAB was not run by Agent 0. Automatic-rejection thresholds remain user/researcher settings to choose for each dataset according to data quality and research questions; selecting them is outside this pipeline implementation work.

## File selection and participant identity (CD-17)

The configured input folders are starting locations for the Stage 1 and Stage 2 selectors. Each stage loads from the folder actually returned by its selector. Cancelling either dialog ends that run before participant processing. When run by sections, a cancelled selection is emptied; users stop there and select files again before continuing.

Stage 1 uses `fileparts` on the raw BDF filename: `001.bdf` gives the character ID `'001'`. It saves that value in `EMG.subject`, and Stage 2 uses the saved subject rather than parsing the SET filename. Feature-table keys use strings, preserving leading zeros. Other studies can adapt the filename-stem extraction line in Stage 1; this project does not add a general parser or a new Stage 0 naming setting. The researcher explicitly chose not to add empty-ID or duplicate-ID checks, leaving filename correctness to users.

Agent 5 commits `558f803` and `d7ab337` were integrated as `f9e77d7` and `e5333e8`. The researcher reported all MATLAB tests and acceptance checks passing, including batch processing, on 2026-09-18. See [the handoff](tests/file_selection_identity_handoff.md). MATLAB and EEGLAB were not run by Agent 0.

CD-13 through CD-15 define the approved trigger-shifting behavior. The researcher selected 20 ms as the default crossing duration, replacing the former fixed 10-sample default.

T1.2-A's photodiode onset-detection audit and test-only reference are integrated at `9ac2f7f` (Agent 3 source commit `2a624b4`); the researcher reported all reference tests passing on 2026-09-08. See [the audit](tests/trigger_shift_photodiode_audit.md) for current defects and unresolved scientific choices. Passing these parameterized tests does not approve a threshold, duration, zero-time anchor, failure policy, shift direction, or rounding rule. EEGLAB-based preprocessing remains part of the planned production workflow.

## Trigger-shift direction and rounding (CD-13)

The researcher approved these conventions on 2026-09-08 for fixed and trial-specific delay application:

```matlab
sample_offset = round(delay_ms * srate / 1000);
corrected_latency = original_latency + sample_offset;
```

A positive photodiode delay means measured stimulus onset occurs after the recorded trigger, so the corrected trigger moves later. This preserves the existing intended direction. A negative signed delay moves an event earlier; zero leaves its latency unchanged. Only the offset is rounded; the original event latency is not rounded.

The offset uses MATLAB's ordinary `round` behavior (nearest integer, with half-integer ties away from zero), replacing the current `ceil` convention. T1.2-B tests positive, negative, zero, fractional-sample, and half-sample offsets. The researcher reported the MATLAB reference suite passing on 2026-09-08 at source commit `accfbce`, integrated unchanged as `ca9f604`; see [the handoff](tests/trigger_latency_application_handoff.md). Its explicit mapping is supplied by the caller and does not establish EEGLAB epoch provenance. Production implementation and its MATLAB/EEGLAB validation remain pending. CD-14 and CD-15 below settle the additional detection and fallback policies, including the duration default.

## Photodiode detection parameters (CD-14)

Keep the existing EEGLAB signal preparation: continuous CleanLine processing, epoching, baseline subtraction, rectification, and second baseline subtraction. The threshold remains `range(signal) / divisor`, with user-configurable divisor defaulting to 4 and comparison `>=`. Estimate the range over the detection segment from the chosen zero-time anchor to epoch end; do not add the minimum signal amplitude to the threshold.

Select the sample closest to zero, whether negative or positive; choose the positive sample when equally close. Return the first sample of the first qualifying sustained run, correcting the existing one-sample indexing error.

Expose minimum crossing duration in milliseconds, defaulting to 20 ms. Convert using `max(1, ceil(minimum_duration_ms * srate / 1000))` consecutive samples, with a positive configured duration. This adopts sample-count duration (`n / srate`), matching the original run-length convention, rather than elapsed time between the first and last sample. The ceiling ensures the sample-count duration is at least the requested duration; it is distinct from CD-13's nearest-sample rounding of delay offsets. At 512 Hz, 20 ms corresponds to 10.24 samples and therefore requires 11 consecutive samples.

## Median shifting and fallback (CD-15)

Support three behaviors: fixed applies the configured signed delay to every selected target; variable applies each successfully detected trial delay and uses the median for unavailable estimates; median applies the median to every selected target.

Compute the median in milliseconds, before sample rounding, from successfully detected delays within the current participant recording across configured target events. Missing crossings, flat/uninformative signals, and epochs omitted at recording boundaries or discontinuities do not contribute. Preserve explicit retained-epoch-to-original-event identity; never infer the association from matching counts alone.

When an estimate is unavailable, use the median of the successful trials and warn with the affected event identities, reasons, applied median, and number of supporting detections. Keep measured delays and applied delays distinguishable in a separate diagnostic result, without adding event fields. One successful detection is sufficient, with the support count visible. No successful detections or a missing photodiode channel must produce a clear error. Reject corrected latencies outside the recording rather than clipping them.

The median assumes a common typical delay across selected targets in that recording. Provide a delay-distribution diagnostic to help assess differences across targets or over the recording. Retain paired before/after photodiode diagnostics using the same available trials.

These decisions extend the tested numerical references. T1.2-C must add tests for median mode, fallback, duration conversion, identity mapping, and failure cases, then undergo representative MATLAB/EEGLAB validation.

## Integration evidence and wiki handoff (2026-09-09)

CD-13 through CD-15 are implemented in `5539508` (Agent 3 source `9f4a6a1`). The researcher reported all synthetic tests passing and actual-data Stage 1 runs succeeding in variable and median modes. Earlier future-tense implementation notes above describe the decision history; this evidence updates their status. Targeted real EEGLAB edge cases are not individually confirmed. The researcher confirmed the final Stage 1 legacy-settings cleanup passed its quick rerun at `be6537d` on 2026-09-09.

Median shifting removes a common delay, preserving differences between trials. For example, clusters at 20 and 37 ms remain separated by 17 ms after any common shift: a median of 20 ms leaves residuals at 0 and 17 ms. The median can align either group or fall between groups depending on the distribution. Variable mode corrects each successful detection individually; fallback trials still receive the common median. The researcher observed this two-group pattern in representative data. Monitor-frame timing is a possible explanation, not a cause established by the plot alone. Wiki Curator should explain this distinction when drafting trigger-shifting documentation.

## Current-settings contract (CD-16)

Stage 1 import and inspection update (2026-09-09): at the researcher's request, BDF loading uses BIOSIG's `pop_biosig` to import data and events before character normalization. BIOSIG is a required import plugin. Trigger-shifting diagnostic figures remain open after each participant for manual inspection; the automatic five-second pause and figure closure were removed. The researcher confirmed a representative BDF run passed with these changes on 2026-09-09, following the request to check import, events, saved SET, and the persistent diagnostic window.

Users define their own settings using the current Stage 0 before running later stages. Settings files from previous development runs are not a supported compatibility target. Do not silently supply missing settings fields for legacy files. Stage 1 passes `sets.shift_minimum_duration_ms` directly. Optional defaults in standalone function calls remain part of their documented interfaces; they are distinct from migrating saved pipeline settings.

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

`validate_settings(sets, stage)` runs once at each stage's entry. Stage 0 checks the complete current configuration; later stages check their own requirements. Stage 2 does not require access to the original BDF folder. Optional parameter values are checked when used, while required fields reflect actual downstream access. No settings are repaired or migrated, and the validator creates no files or folders.

Section 0.2 contains assignments and explanatory comments only. Resources-folder checking and output-folder creation are in Section 0.1; Section 0.3 calls the validator. Settings-only checks cover supported options, dimensions, combinations, paths and timing relationships. Data-dependent checks remain in processing code, and standalone trigger-shifting checks remain available. Section execution starts with the stage's entry section and runs each section once.

Agent 4 commit `610de9a` was integrated unchanged as `47a8d2e`; the researcher reported all handoff checks passing on 2026-09-09. The validator preserves and explains the existing restriction that a single-row channel array selects independent channels, so one bipolar muscle is not yet supported. Resolving that interface remains Tier 2.1 work.

## Decisions intentionally deferred

The following points remain outside the completed implementation work:

- behavior when every configured condition has zero trials, beyond the defined `NaN` rejection statistics for an individually absent condition;
- how output files should encode the exact settings and software versions used for a run;
- formal compatibility claims beyond the MATLAB R2024b tests already performed.

These items should be resolved through the tiered tasks in `PROJECT_PLAN.md`. When a decision is made, this document should be updated in the same integration cycle.
