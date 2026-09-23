# MAV Processing and Standardization

This page explains how the pipeline calculates mean-absolute-value-derived (MAV-derived) EMG features, including waveform baseline correction, bin boundaries, standardization reference populations, optional averaging, and output naming.

The muscle signals entering this workflow are defined by [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md). Channel referencing defines the signals; feature standardization later transforms the extracted observations using a reference mean and standard deviation.

## Processing sequence

The implemented order is:

```text
full-wave rectification
    → trial-wise waveform baseline correction
    → removal of flagged trials for feature estimation
    → binned MAV extraction
    → post-stimulus-derived standardization
    → optional condition-level trial averaging
```

Each operation acts at a different level. Baseline correction is calculated separately for each muscle and trial. Binning produces trial × muscle × bin observations. Standardization uses a participant-level reference population, either separately by muscle or pooled across muscles. Optional averaging combines retained trials within condition only after standardization.

Changing this order changes the scientific meaning of the result and requires separate validation.

## 1. Full-wave rectification

For a raw EMG sample `x`, full-wave rectification produces `abs(x)`. This prevents positive and negative voltage deflections from cancelling in the within-bin mean. Stage 0 therefore rejects MAV settings unless rectification is enabled with the `abs` method.

Rectification occurs once, before baseline correction. The feature extractor later takes an ordinary arithmetic mean; it does not apply another absolute-value operation.

## 2. Trial-wise waveform baseline correction

For each muscle and trial, Stage 2 calculates the mean of the rectified samples in the configured baseline window. The interval is left-inclusive and right-exclusive:

```text
baseline_start ≤ time < baseline_end
```

The resulting trial- and muscle-specific baseline mean is applied to the full epoched waveform before feature bins are extracted. Baseline correction is not recalculated within each bin.

| State | Waveform operation | Unstandardized output meaning | Column suffix |
| --- | --- | --- | --- |
| Disabled | Rectified waveform is unchanged. | Raw MAV | `MAV_raw` |
| Subtraction | Subtract the baseline mean from every time point. | MAV difference from the trial baseline | `MAV_difference` |
| Division | Divide every time point by the baseline mean. | MAV ratio to the trial baseline | `MAV_ratio` |

A subtractive result can legitimately be negative when activity in a bin is below its trial baseline. No second `abs` is applied, because that would turn a below-baseline difference into a positive magnitude and change its meaning.

Division by a zero, nonfinite, or otherwise unusable baseline mean follows MATLAB's native arithmetic. The pipeline does not silently replace or repair the denominator. Researchers should inspect such values as a data-quality issue.

## 3. Binned features from retained trials

Artifact flags are established before waveform baseline correction. The optional preprocessed SET checkpoint retains flagged epochs for inspection, but flagged trials are removed before feature extraction and standardization.

For every retained trial, muscle, and bin, the feature is the ordinary mean of corrected waveform samples within that bin. The result is called MAV-derived because the waveform was fully rectified before baseline correction, not because the extractor takes another absolute value.

Stage 2 creates one pre-stimulus bin of the configured duration and as many post-stimulus bins as fit exactly into the post-stimulus epoch. The post-stimulus duration must be an integer multiple of the bin duration.

Bins are left-inclusive and right-exclusive, except for the final post-stimulus bin, which includes its right endpoint. For a bin duration `D`:

```text
pre-stimulus bin:  [-D, 0)
post bin 1:        [0, D)
post bin 2:        [D, 2D)
...
final post bin:    [end-D, end]
```

This convention counts a shared boundary sample once while retaining the final epoch sample.

If the baseline-correction window exactly matches the pre-stimulus feature bin, that bin's mean should be approximately zero after subtraction or approximately one after division, apart from floating-point precision. This identity does not apply when the two windows differ.

## 4. Post-stimulus-derived standardization

Only finite feature observations from retained post-stimulus bins estimate the standardization parameters. The pre-stimulus bin is excluded from the reference population but is transformed after the parameters are estimated.

For reference observations `y`:

```text
z = (feature - mean(y)) / std(y)
```

MATLAB's sample-standard-deviation convention is used: `std(..., 0)`, with denominator `n - 1`. A reference population must contain at least two finite observations and have a finite, nonzero standard deviation.

Two alternative modes are available:

- **Muscle-wise standardization** estimates a separate mean and sample standard deviation for each muscle within a participant. It pools retained trials, conditions, and post-stimulus bins for that muscle.
- **Subject-pooled standardization** estimates one mean and sample standard deviation for the participant. It pools muscles as well as retained trials, conditions, and post-stimulus bins.

These modes define different scientific reference populations. They are mutually exclusive alternatives, not sequential transformations.

## 5. Standardization before optional averaging

Standardization is performed on trial-level features before optional condition-level averaging. Stage 2 carries the unstandardized and standardized arrays separately into the averaging step and averages each within condition.

Averaging first would change the number and variance of observations used to estimate the reference distribution. It would therefore define a different normalization.

Rejected trials contribute to neither the unstandardized features, the standardization parameters, nor condition averages. If rejected rows are requested, they are restored only after calculation and contain missing values in every MAV-derived column.

## 6. Wide output columns

The first four columns are `subject_ID`, `condition`, `trial_number`, and `bin`. Feature columns remain wide. For each muscle, the method-specific unstandardized column is followed immediately by its standardized partner when standardization is enabled.

For a hypothetical muscle named `M1`, possible pairs include:

```text
M1_MAV_raw,        M1_MAV_z_muscle
M1_MAV_difference, M1_MAV_z_muscle
M1_MAV_ratio,      M1_MAV_z_subject
```

Only the pair appropriate to the selected baseline and standardization settings is written. If standardization is disabled, each muscle has only its unstandardized `MAV_raw`, `MAV_difference`, or `MAV_ratio` column.

When rejected rows are restored, their key columns remain populated and all MAV-derived columns are missing.

## Validation scope

The numerical workflow is covered by deterministic MATLAB R2024b tests for known raw, subtractive, and divisive values; bin boundaries; negative baseline differences; muscle-wise and subject-pooled standardization; pre-stimulus exclusion from reference estimation; pooling across conditions; standardization before averaging; invalid reference populations; output ordering; and rejected-row missingness.

The final production calculations remain visible inline in Stage 2. Test-only helper implementations under `tests/helpers/` provide numerical references but are not production dependencies. Validation of those calculations does not replace inspection of signal quality, artifact settings, and output distributions for each dataset.
