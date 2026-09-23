# Trigger Shifting and Diagnostics

The event marker in a recording and the physical onset of a stimulus need not occur at exactly the same time. If you have measured a delay, or recorded a photodiode signal, Stage 1 can adjust the event times before you extract epochs. The EMG samples themselves stay unchanged.

## What trigger shifting changes

A positive delay moves the marker later in the recording; a negative fixed delay moves it earlier. For example, a positive photodiode delay means that measured stimulus onset followed the recorded marker. A delay of zero leaves the marker where it was.

The pipeline converts delays in milliseconds to sample offsets:

```text
sample offset = round(delay in ms × sampling rate / 1000)
corrected latency = original latency + sample offset
```

The offset is rounded to the nearest whole sample. If the original event latency already has a fractional sample position, that fraction is preserved. The event code and other event information are also retained.

## Choosing a correction

Enable this step with `sets.do_shift_triggers` in Stage 0, then choose `sets.shift_method`:

| Setting | What happens |
| --- | --- |
| A number, such as `20` | Apply the same delay in milliseconds to every selected marker. No photodiode signal is needed. |
| `'variable'` | Estimate a delay for each event from the photodiode. When an estimate is unavailable, use the median of the successful detections in that participant's recording. |
| `'median'` | Estimate the median photodiode delay for the participant's recording and apply it to every selected marker. |

Use `sets.shift_markers` to list the event codes you want to shift. If you leave it empty, the pipeline uses `sets.condition_triggers`. Enter the codes exactly as recorded, including spaces and prefixes; see [Event Codes and Condition Labels](Event-Representation-and-Condition-Labels.md).

For either photodiode mode, also review:

- `sets.shift_window`: the epoch around each selected event, which must include the −29 to 0 ms baseline and data after the trigger;
- `sets.shift_threshold`: the divisor used to calculate the detection threshold from the signal's range;
- `sets.shift_minimum_duration_ms`: how long the signal must stay at or above that threshold.

The Stage 0 example uses a divisor of 4 and a duration of 20 ms. Check their suitability for your photodiode signal and experimental setup. Save your choices by running the current Stage 0 before Stage 1; older settings files are not supplemented with missing parameters automatically.

## How the photodiode onset is detected

The pipeline looks first for a channel named `Erg1`. If that name is absent, it looks for `photodiode`. Processing stops if neither is available.

The photodiode waveform is prepared in the following order:

1. Apply CleanLine to the continuous photodiode signal.
2. Extract epochs around the selected events.
3. Subtract the mean over −29 to 0 ms.
4. Take the absolute value of the waveform.
5. Subtract the baseline mean again over the same interval.
6. Search from the sample nearest zero to the end of the epoch.

An exact zero-time sample is not necessary. If two samples lie equally far on either side of zero, the later one is used. Photodiode processing requires EEGLAB and CleanLine.

For each epoch, the threshold is calculated from the range of the processed signal over the search interval:

```text
threshold = (maximum − minimum) / divisor
```

With a divisor of 4, this is one quarter of that range. The minimum amplitude is not added back to the threshold. The signal must then stay **at or above** the threshold for the requested duration. The first sample of the first qualifying stretch gives the detected onset.

Duration is converted to a number of consecutive samples by rounding upwards:

```text
minimum samples = ceil(duration in ms × sampling rate / 1000)
```

At 512 Hz, 20 ms gives 10.24 samples, so the pipeline requires 11 consecutive samples. Duration here is counted as the number of samples divided by the sampling rate. This upward rounding ensures the required duration is met; it is separate from the nearest-sample rounding used to shift event times.

## When an onset cannot be estimated

Some epochs may be unavailable because they cross the start or end of a recording, contain a discontinuity, or are omitted by EEGLAB for another reason. Others may contain a flat or unusable photodiode signal, or never stay above threshold long enough. These epochs do not contribute to the median delay.

The median is calculated in milliseconds from successful detections within the current participant's recording, pooling all selected event codes. It is calculated before conversion to sample offsets. Each retained photodiode epoch stays associated with its original event, so an omitted epoch does not cause later delays to be assigned to the wrong markers.

In variable mode, an event without an estimate receives this median delay. In median mode, every selected event receives it, including those with their own successful detection. Warnings identify events without estimates, explain why detection was unavailable, and report the applied median and how many detections support it.

One successful detection is enough for the calculation to proceed. In that case, the median rests on just one observation; check the support count in the diagnostics. With no successful detections, processing stops. It also stops if the photodiode channel is missing, epochs cannot be matched consistently to their events, or a corrected marker would fall outside the recording. Out-of-range markers are not moved to the nearest recording boundary.

## Interpreting a common median

Applying one median delay corrects a common offset while leaving differences between trials in place. Suppose your detected delays form two groups, at 20 and 37 ms. A median correction of 20 ms leaves residual delays of 0 and 17 ms. The two groups are still 17 ms apart.

Depending on their relative sizes, the median can coincide with one group or fall between them. Variable correction instead uses each event's own detected delay, except where a missing estimate is replaced by the median.

Two clusters in the diagnostic plot therefore do not by themselves indicate an error in median correction. Monitor-frame timing is one possible explanation, but the plot cannot establish the cause. Interpret the distribution alongside what you know about stimulus presentation and acquisition timing. Adjusting detection parameters should have a reason grounded in those signals and the experiment, rather than simply making the plot look tidier.

## Saved diagnostics

Stage 1 saves the timing results in `raw/`, in a file named after the input recording with `_trigger_shift_diagnostics.mat` added. This file is written for fixed as well as photodiode corrections.

It records the original and corrected event times, measured and applied delays, sample offsets, detection status, and the median with its number of supporting detections. For photodiode processing, it also includes detection thresholds, onset samples, the correspondence between epochs and events, and paired waveforms before and after correction. These details are saved separately from the event list.

The photodiode figure shows the before-and-after waveforms, a histogram of detected delays, and delays over recording time separated by event code. It stays open for inspection. Review it together with the warnings: a completed run does not necessarily mean that every event had a direct onset estimate.

## How trigger shifting was checked

Automated tests in MATLAB R2024b check the direction and rounding of shifts, event matching, onset detection, missing estimates, median calculations, errors at recording boundaries, and agreement with the saved diagnostics. Representative recordings were also processed using variable and median correction, including saved datasets and diagnostic figures.

Some automated tests replace individual EEGLAB operations with simplified versions to check specific calculations. The results therefore do not cover every possible recording or plugin version. Inspect timing corrections when applying the pipeline to your own setup.
