# MAV Processing and Standardization

This page explains the validated calculation of mean-absolute-value-derived (MAV-derived) EMG features, including waveform correction, bin boundaries, standardization reference populations, optional averaging, and output naming.

The muscle signals entering this workflow are defined earlier by [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md). Channel referencing selects source signals or subtracts electrode pairs; the feature standardization below transforms the later MAV-derived observations using a reference mean and standard deviation.

## Validated sequence

The approved workflow is:

```text
full-wave rectification
    → trial-wise waveform baseline correction
    → removal of flagged trials for feature estimation
    → binned MAV extraction
    → post-stimulus-derived standardization
    → optional condition-level trial averaging
```

In shorter form, this is rectification → waveform baseline correction → retained-trial binning → standardization → optional averaging. Each operation has a different level: baseline correction is calculated separately for each muscle and trial, binning produces trial × muscle × bin observations, standardization uses a participant-level reference population defined either separately by muscle or pooled across muscles, and optional averaging combines retained trials within condition only after standardization.

## 1. Full-wave rectification

For a raw EMG sample `x`, full-wave rectification produces `abs(x)`. MAV requires this step because positive and negative voltage deflections should contribute by magnitude rather than cancel in the within-bin mean. Stage 0 therefore rejects the MAV configuration unless rectification is enabled with the `abs` method.

Rectification occurs once, before baseline correction. The later feature extractor takes an ordinary arithmetic mean of the corrected waveform; it does not apply another absolute-value operation.

## 2. Trial-wise waveform baseline correction

For each muscle and each trial, Stage 2 calculates the ordinary mean of the rectified samples in the configured baseline window. The baseline window is left-inclusive and right-exclusive:

```text
baseline_start ≤ time < baseline_end
```

That single trial- and muscle-specific baseline mean is then applied to the full epoched waveform before feature bins are extracted. Baseline correction is not recalculated separately within every bin.

The user-facing states and their output interpretations are:

| State | Waveform operation | Unstandardized output meaning | Column suffix |
| --- | --- | --- | --- |
| Disabled | Rectified waveform is unchanged. | Raw MAV | `MAV_raw` |
| Subtraction | Baseline mean is subtracted from every time point. | MAV difference from the trial baseline | `MAV_difference` |
| Division | Every time point is divided by the baseline mean. | MAV ratio to the trial baseline | `MAV_ratio` |

A subtractive result can legitimately be negative when a bin's corrected activity is below its trial baseline. No second `abs` is taken, because doing so would turn a below-baseline difference into a positive magnitude and change its meaning.

The current approved behavior leaves division by a zero, nonfinite, or otherwise unusable baseline mean to MATLAB's native arithmetic. This is treated as a data-quality issue to be found during quality control; the pipeline does not silently replace or repair the denominator.

## 3. Binned feature extraction from retained trials

Artifact flags are established before waveform baseline correction. The preprocessed SET checkpoint retains the flagged epochs for inspection, but flagged trials are removed before feature extraction. The unstandardized feature array therefore contains retained trials only.

For each retained trial, muscle, and bin, the feature is the ordinary mean of corrected waveform samples in that bin. The output is called MAV-derived because the waveform was fully rectified before correction, not because the extractor takes another absolute value.

Stage 2 creates one pre-stimulus bin of the configured bin duration and as many post-stimulus bins as fit exactly in the post-stimulus epoch. The post-stimulus duration must be an integer multiple of the bin duration.

Bins are left-inclusive and right-exclusive, except for the final post-stimulus bin, which includes its right endpoint. For bin duration `D`:

```text
pre-stimulus bin:  [-D, 0)
post bin 1:        [0, D)
post bin 2:        [D, 2D)
...
final post bin:    [end-D, end]
```

This convention counts a shared boundary sample once while retaining the last epoch sample. If the waveform baseline window exactly equals the pre-stimulus feature bin, the pre-bin mean is expected to be approximately zero after subtraction or approximately one after division. That identity is not expected when the two windows differ.

## 4. Post-stimulus-derived standardization

Standardization parameters are estimated from finite, retained, post-stimulus feature observations only. The pre-stimulus bin does not contribute to the reference mean or standard deviation. Once the parameters are estimated, however, the selected transformation is applied to every feature bin, including the pre-stimulus bin.

For reference observations `y`, Stage 2 applies:

```text
z = (feature - mean(y)) / std(y)
```

MATLAB's sample-standard-deviation convention is used: `std(..., 0)`, with denominator `n - 1`. A reference distribution must contain at least two finite observations and have a finite, nonzero standard deviation.

Two alternative modes are available:

- **Muscle-wise standardization** estimates a separate reference mean and sample standard deviation for each muscle within one participant. For that muscle, the reference pools retained trials, conditions, and post-stimulus bins.
- **Subject-pooled standardization** estimates one reference mean and sample standard deviation for the participant. It pools muscles as well as retained trials, conditions, and post-stimulus bins.

The modes are mutually exclusive because they define different scientific reference populations. They are alternatives, not sequential transformations. Enabling both is rejected in Stage 0.

## 5. Standardization before optional averaging

Standardization is performed on trial-level features before optional condition-level averaging. Stage 2 carries the unstandardized and standardized arrays separately into the averaging step and averages each within condition.

This order preserves the approved trial-level post-stimulus reference distribution. Averaging first would reduce the number of reference observations and change their variance, producing a different normalization rather than an equivalent rearrangement.

Rejected trials contribute to neither the unstandardized features nor the reference mean, reference standard deviation, or condition average. If rejected rows are requested, they are restored only after feature calculation and have missing values in every MAV-derived column.

## 6. Wide output columns

The first four columns are the composite identifiers `subject_ID`, `condition`, `trial_number`, and `bin`. Feature columns remain wide. For each muscle, the method-specific unstandardized column is followed immediately by its standardized partner when standardization is enabled. For a hypothetical muscle named `M1`, examples are:

```text
M1_MAV_raw,        M1_MAV_z_muscle
M1_MAV_difference, M1_MAV_z_muscle
M1_MAV_ratio,      M1_MAV_z_subject
```

Only the relevant pair is written for the selected configuration. If both standardization toggles are disabled, each muscle has only its unstandardized `MAV_raw`, `MAV_difference`, or `MAV_ratio` column.

When rejected rows are restored, every one of these MAV-derived columns is missing on those rows. Their key columns remain populated so the rejected trial and bin are visible without treating rejection as a measured zero.

## Why production code is inline

The numerical operations were first represented in EEGLAB-independent helper functions so deterministic tests could verify known values, boundary behavior, standardization populations, invalid references, and operation order. After helper-backed and integrated outputs were validated, the equivalent calculations were kept inline in Stage 2. The helpers remain under `tests/helpers/` as validation references; production Stage 2 does not depend on them.

This design keeps the processing sequence visible in the main script while preserving compact reference implementations for regression tests. The recorded validation includes deterministic MATLAB R2024b tests, output-schema and missingness validation, complete-script versus section comparisons, and final inline versus helper-backed numerical comparisons.

## Traceability

- **Decisions:** [CD-05 through CD-09](../CONCEPTUAL_DECISIONS.md#mav-processing-model).
- **Production file and sections:** [`EMG_00_settings.m`, rectification through trial-averaging settings and incompatible-setting checks](../EMG_00_settings.m); [`EMG_02_preprocessing_feature_extraction.m`, Sections 2.4.6–2.4.15](../EMG_02_preprocessing_feature_extraction.m).
- **Deterministic tests:** [`test_mav_calculation.m`](../tests/test_mav_calculation.m), [`test_mav_standardization.m`](../tests/test_mav_standardization.m), and [`run_mav_tests.m`](../tests/run_mav_tests.m).
- **Reference helpers:** [`apply_mav_baseline_correction.m`](../tests/helpers/apply_mav_baseline_correction.m), [`extract_binned_mav.m`](../tests/helpers/extract_binned_mav.m), and [`standardize_mav_features.m`](../tests/helpers/standardize_mav_features.m).
- **Integration validation:** [`validate_mav_output.m`](../tests/validate_mav_output.m), [`compare_mav_outputs.m`](../tests/compare_mav_outputs.m), and the recorded [PROJECT_PLAN.md validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Current implementation status:** CD-05 through CD-09 are implemented and validated. No MATLAB execution was required for this documentation-only draft.
