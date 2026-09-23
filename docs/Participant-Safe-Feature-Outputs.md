# Feature Tables and Rejected Trials

The feature CSV is the table you take forward into statistical analysis. It contains the EMG measures for the participants who have completed processing. This page explains what a row represents, how rejected trials appear, and why the feature table and rejection report may contain different participants after an error.

## Identifying participants and trials

Participant IDs come from the original BDF filenames: `001.bdf` becomes `'001'`. They are kept as text throughout processing. When importing the CSV into statistical software, read `subject_ID` as text too, so that `'001'` does not become the number `1`.

Unless you have enabled trial averaging, each row describes **one participant, one condition, one trial, and one time bin**:

| Column | Meaning |
| --- | --- |
| `subject_ID` | Participant ID. |
| `condition` | Experimental condition. |
| `trial_number` | The trial's original number, before rejected trials were removed. |
| `bin` | The time bin within the trial. |

These four columns identify the observation together. Trial 1 in a given condition can occur for many participants, so include the participant ID whenever you match these rows to another table. Also check that your original filenames give distinct participant IDs; the pipeline does not check for duplicates or empty IDs.

## What happens to rejected trials

Only retained trials contribute to feature extraction, standardization, and condition averages. If `sets.do_save_rejected_trial_rows` is enabled, the final table also includes rows for rejected trials, with their participant, condition, original trial number, and bin still filled in. All their EMG measures are missing.

The pipeline does this separately for each participant, using the trial information saved before rejection. A rejected trial from one participant therefore cannot pick up values from another participant who happens to have the same condition, trial number, and bin.

**A missing value does not mean zero muscle activity.** It means that the trial was rejected and no feature was estimated. Replacing these missing values with zero would introduce measured amplitudes that were never observed and could change subsequent averages or models.

You cannot keep rejected-trial rows when condition-level trial averaging is enabled. An averaged row summarises the retained trials in a condition; it no longer corresponds to an individual trial that could be marked as rejected.

## When the feature table is saved

After a participant finishes preprocessing and feature extraction, their rows are added to those of earlier completed participants. The combined table is sorted and saved again. If a later participant fails before reaching this point, the existing CSV still contains the earlier results; it does not contain partial feature results for the failing participant.

The whole CSV is rewritten at each save. Reusing its filename on a later run can replace the earlier file, and a write interrupted while it is in progress is not protected by a separate recovery mechanism. Preserve results you need before starting another run. A CSV on disk tells you which participants reached the save step, not that every selected participant finished.

## The rejection report

Two settings answer different questions:

| Setting | What it saves |
| --- | --- |
| `sets.do_save_trial_rejection_stats` | A summary of rejection counts and fractions. |
| `sets.do_save_rejected_trial_rows` | Rows for rejected trials in the feature table, with missing amplitudes. |

You can request a rejection report without retaining rejected rows in your analysis table, or retain the rows without requesting the report.

Rejection statistics are saved as soon as they have been calculated for a participant. Features are saved later. If feature processing fails, you may therefore find that participant in the rejection report but not in the feature table.

An absent condition is different from a condition with no rejected trials:

| Situation | Rejected count | Rejected fraction |
| --- | --- | --- |
| The condition has trials, and none were rejected. | `0` | `0` |
| There are no trials for that condition. | `NaN` | `NaN` |

`NaN` means a missing numerical value. Despite their names, columns beginning with `perc_` contain **fractions from 0 to 1**: a value of `0.2` means 20% of the trials were rejected.

If none of the configured conditions has any trials, there is no special empty-results output; epoching or feature extraction may fail. Check the imported event codes and condition matching before interpreting such a result.

Choose rejection thresholds after inspecting your data, and justify them in relation to your recordings and research question. The example settings are not universal thresholds.

## Wide-table organization

The four identifying columns come first. They are followed by the measures for each muscle, with different muscles in separate columns. When standardization is enabled, each muscle's unstandardized measure is followed by its z score. Otherwise, there is just the unstandardized measure.

Muscle names and their order follow `sets.emg_channel_names`; see [channel selection](EMG-Channel-Selection-and-Re-referencing.md#output-order-and-channel-metadata). The column suffix tells you how the value was calculated—for example, `MAV_difference` for subtractive baseline correction or `MAV_z_muscle` for muscle-wise z scoring. [MAV Processing and Standardization](MAV-Processing-and-Standardization.md#6-wide-output-columns) explains these names and their interpretation.

On a rejected-trial row, all of these muscle measures are missing together. If you have averaged trials, each row instead represents a participant's condition and time bin, averaged over retained trials.
