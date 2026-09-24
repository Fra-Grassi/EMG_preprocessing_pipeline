# MAV Processing and Standardization

The pipeline summarises EMG activity within each time bin using mean absolute value (MAV). Depending on your settings, the saved value can describe rectified activity, a difference from baseline, a ratio to baseline, or a z score. These quantities answer different questions, so it is useful to follow how each is obtained.

[Channel selection and re-referencing](EMG-Channel-Selection-and-Re-referencing.md) have already defined the muscle signals by this point. The standardization described here acts on the extracted measures, after waveform processing.

## Processing sequence

The sequence is:

```text
full-wave rectification
    → baseline correction of each trial's waveform
    → removal of trials marked for rejection
    → mean amplitude within each time bin
    → optional standardization using post-stimulus values
    → optional averaging of trials within each condition
```

Baseline correction is specific to each muscle and trial. Standardization uses values pooled within a participant, either separately for each muscle or across muscles. Keeping these steps separate makes it possible to interpret a change relative to a trial's baseline and, if requested, express the resulting measure on a standardized scale.

## 1. Full-wave rectification

Rectification takes the absolute value of every EMG sample: negative deflections become positive. Without it, positive and negative voltages could cancel when averaged within a time bin. MAV extraction therefore requires `sets.do_rectifying = 1` and `sets.rectify_method = 'abs'`.

Rectification is applied once. The pipeline does not take absolute values again after baseline correction, because that would erase meaningful negative differences from baseline.

## 2. Trial-wise waveform baseline correction

For each trial and muscle, the pipeline averages the rectified samples in your baseline window. It then applies that baseline mean to the whole epoch. The same baseline is used for every time bin in that trial; it is not estimated afresh within each bin.

You can leave baseline correction disabled, subtract the baseline mean, or divide by it:

| Choice | Calculation at each time point | Meaning of the binned result | Column suffix |
| --- | --- | --- | --- |
| No correction | Keep the rectified value. | Raw MAV. | `MAV_raw` |
| Subtraction | Rectified value minus baseline mean. | Difference from the trial's baseline. | `MAV_difference` |
| Division | Rectified value divided by baseline mean. | Ratio to the trial's baseline. | `MAV_ratio` |

With subtraction, a negative value means that activity in the bin was below the trial's baseline. Taking its absolute value would lose that distinction. With division, a value of one corresponds to the baseline mean.

The baseline window includes its starting time but excludes its ending time:

```text
baseline_start ≤ time < baseline_end
```

If you use division, inspect the baseline values carefully. A zero or unusable baseline mean is not replaced automatically; MATLAB's ordinary arithmetic applies, potentially producing infinite or missing values. Such results need attention during data-quality checks.

## 3. Binned features from retained trials

Trials are marked for rejection before baseline correction. The optional preprocessed SET file keeps the marked epochs so that you can inspect them, but those trials are removed before the EMG measures are calculated.

For each remaining trial and muscle, the pipeline takes the mean of the baseline-corrected waveform within each bin. The measures are called MAV-derived because the signal was rectified before baseline correction. No further absolute-value operation is applied.

There is one pre-stimulus bin and a series of post-stimulus bins, all with your chosen duration. The post-stimulus epoch must contain a whole number of bins. Each sample is counted once: a sample on a shared boundary belongs to the later bin, while the final sample of the epoch is included in the last bin.

For bin duration `D`, the intervals are:

```text
pre-stimulus bin:  [-D, 0)
post bin 1:        [0, D)
post bin 2:        [D, 2D)
...
final post bin:    [end-D, end]
```

Here, `[` means the endpoint is included and `)` means it is excluded. If the baseline-correction window is exactly the same as the pre-stimulus bin, that bin's mean should be zero after subtraction or one after division, apart from small numerical rounding differences. If the windows differ, there is no reason to expect those values.

## 4. Post-stimulus-derived standardization

Standardization expresses each extracted value relative to a participant's distribution of retained post-stimulus values:

```text
z = (value − reference mean) / reference standard deviation
```

The pre-stimulus bin is kept in the output, but it does not contribute to the reference mean or standard deviation. Once those are estimated from post-stimulus observations, the same transformation is applied to every bin, including the pre-stimulus bin.

You can choose between two reference distributions:

- **Muscle-wise standardization:** calculate a separate mean and standard deviation for each muscle within each participant, pooling retained trials, conditions, and post-stimulus bins for that muscle.
- **Subject-pooled standardization:** calculate one mean and standard deviation per participant, pooling muscles as well as retained trials, conditions, and post-stimulus bins.

For muscle-wise z scores, a value is therefore expressed relative to that muscle's post-stimulus distribution across conditions. For subject-pooled z scores, it is expressed relative to the participant's pooled distribution across muscles. Choose one approach; the pipeline does not apply both in sequence.

Only finite values contribute to the reference distribution. There must be at least two, and their standard deviation must be finite and greater than zero. The calculation uses the sample standard deviation, with denominator `n − 1`.

## 5. Standardization before optional averaging

If you enable both standardization and condition averaging, the pipeline first standardizes the trial-level values and then averages the retained trials within each condition. It saves averages of the unstandardized values and, when enabled, averages of the z scores.

The order matters. Estimating a mean and standard deviation from condition averages would use fewer observations and a different variance from estimating them across individual trials. It would produce a different normalization.

Rejected trials contribute to none of these calculations. If you ask to keep rejected rows in a table without trial averaging, those rows are added afterwards with missing values, as described in [Feature Tables and Rejected Trials](Participant-Safe-Feature-Outputs.md).

## 6. Wide output columns

The first four columns identify the participant, condition, trial, and bin: `subject_ID`, `condition`, `trial_number`, and `bin`. Each muscle then has a column for its unstandardized measure and, if requested, an adjacent column for its z score.

The baseline method and standardization method are separate choices. For a muscle named `M1`, any of the three unstandardized measures can be accompanied by either type of z score:

| Baseline correction | Unstandardized column | Added with muscle-wise standardization | Added with subject-pooled standardization |
| --- | --- | --- | --- |
| None | `M1_MAV_raw` | `M1_MAV_z_muscle` | `M1_MAV_z_subject` |
| Subtraction | `M1_MAV_difference` | `M1_MAV_z_muscle` | `M1_MAV_z_subject` |
| Division | `M1_MAV_ratio` | `M1_MAV_z_muscle` | `M1_MAV_z_subject` |

The first suffix records whether you used no baseline correction, subtraction, or division. The z-score suffix records muscle-wise or subject-pooled standardization. Only the unstandardized column and the one z-score column matching your chosen method are written. With standardization disabled, only the unstandardized column is saved for each muscle.

## How the calculations were checked

The calculations were tested in MATLAB R2024b using examples with known results. These checks cover the baseline methods, negative differences, bin boundaries, both standardization methods, exclusion of pre-stimulus values from reference estimation, averaging order, and missing values for rejected trials. They check the numerical steps; inspecting signal quality and the resulting distributions remains part of applying the pipeline to your own recordings.
