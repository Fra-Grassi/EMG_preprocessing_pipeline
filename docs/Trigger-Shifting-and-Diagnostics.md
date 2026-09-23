# Trigger Shifting and Diagnostics

This page explains how Stage 1 corrects selected event latencies using a fixed delay or a photodiode signal, how unavailable photodiode estimates are handled, and how to interpret the saved diagnostics.

## What trigger shifting changes

An event marker records when a trigger reached the acquisition system. The physical event measured by a photodiode can occur later or earlier. Trigger shifting changes the selected event's latency while preserving its exact character code and other event metadata.

All three modes use the same direction and conversion:

```text
sample offset = round(delay in ms × sampling rate / 1000)
corrected latency = original latency + sample offset
```

A positive delay moves the event later. A negative fixed delay moves it earlier. Zero leaves it unchanged. Only the calculated offset is rounded to a whole sample; an original latency with a fractional part retains that fractional part.

Trigger shifting corrects event timing. It does not change the recorded signal samples.

## Available modes

Stage 0 controls the step with `sets.do_shift_triggers` and selects the mode with `sets.shift_method`:

| `sets.shift_method` | Delay applied to each selected target |
| --- | --- |
| Signed numeric value | The same configured delay in milliseconds; no photodiode estimate is required. |
| `'variable'` | The event's detected photodiode delay when available; otherwise the participant recording's median successful delay. |
| `'median'` | The participant recording's median successful delay for every selected target. |

Target codes come from `sets.shift_markers`. They are exact character codes: prefixes, spaces, and leading zeros are significant. If `sets.shift_markers` is empty, Stage 1 uses `sets.condition_triggers`.

Photodiode modes also use:

- `sets.shift_window`, the epoch window around each target, which must include the −29 to 0 ms baseline and post-trigger data;
- `sets.shift_threshold`, the signal-range divisor;
- `sets.shift_minimum_duration_ms`, the required sustained-crossing duration.

The current Stage 0 example uses a divisor of 4 and a duration of 20 ms. These are configurable scientific parameters, not values that should be adopted without checking the recording and experimental setup.

Stage 1 requires settings saved by the current Stage 0. Older settings files are not migrated by supplying missing trigger parameters.

## Photodiode preparation and detection

For `'variable'` and `'median'`, the pipeline first looks for a channel labeled `Erg1`, then for one labeled `photodiode`. A missing photodiode channel is an error.

The signal preparation is:

1. run CleanLine on the continuous photodiode channel;
2. extract epochs around the selected target events;
3. subtract the mean of the −29 to 0 ms baseline;
4. full-wave rectify the signal;
5. subtract the same baseline again;
6. search the processed waveform from the zero-time anchor to the end of the epoch.

The search begins at the sample closest to zero. If negative and positive samples are equally close, the positive sample is selected. An exact zero sample is not required.

Within each retained epoch:

```text
threshold = range(search segment) / divisor
```

The comparison is `signal >= threshold`; the minimum signal amplitude is not added to the threshold. With a divisor of 4, the threshold is one quarter of the processed search segment's range.

A detection must stay at or above the threshold for the configured minimum duration:

```text
minimum samples = ceil(duration in ms × sampling rate / 1000)
```

The first sample of the first qualifying run is the measured delay. At 512 Hz, 20 ms corresponds to 10.24 samples and therefore requires 11 consecutive samples. This ceiling rule applies to crossing duration; latency offsets use the separate `round` rule described above.

Photodiode modes require EEGLAB and CleanLine.

## Participant median and unavailable estimates

The median is calculated separately within each participant recording. It pools successful measured delays across all configured target codes and is computed in milliseconds before any delay is rounded to samples.

Only successful detections contribute. The following are excluded:

- an epoch that would cross a recording boundary;
- an epoch containing an EEGLAB discontinuity boundary;
- another epoch omitted by EEGLAB;
- a nonfinite or flat photodiode signal;
- a signal without a qualifying sustained crossing.

The pipeline preserves the association between each retained photodiode epoch and its original continuous event. It does not infer correspondence from equal event and epoch counts.

In `'variable'` mode, each successful event uses its own measured delay. An event without an estimate uses the participant median. In `'median'` mode, every selected event uses that median, including events with successful individual estimates.

One successful detection is sufficient to define the median, with a support count of one shown in the diagnostics. If no valid detection exists, the function errors rather than inventing a delay. It also errors for a missing photodiode channel, inconsistent event-to-epoch mapping, or corrected latencies outside the recording. Latencies are not clipped to the recording boundary.

Warnings identify events that used the median fallback, the reason their estimate was unavailable, the applied median, and the number of successful detections supporting it.

## Interpreting a common median

A common median removes a typical shared delay but preserves differences among trials. If detected delays form groups at 20 ms and 37 ms, applying a 20 ms median leaves residual delays of 0 ms and 17 ms. The groups remain 17 ms apart.

Depending on their relative sizes, the median may align one group or fall between groups. By contrast, `'variable'` mode applies each successful trial's own delay; only unavailable trials receive the common median.

Separated clusters are therefore useful diagnostic information, not proof that median mode malfunctioned. Monitor-frame timing is one possible explanation, but the plot alone cannot establish the physical cause. Researchers should interpret delay distributions alongside knowledge of the presentation and acquisition systems.

## Saved diagnostics

Trigger shifting does not add audit fields to the EEGLAB event structure. Instead, Stage 1 saves a separate diagnostics structure containing:

- original and corrected latency for each selected event;
- measured and applied delays in milliseconds;
- the rounded sample offset;
- detection status, threshold, detected sample, and epoch mapping;
- the participant median and its number of supporting detections;
- paired photodiode waveforms before and after correction for retained epochs.

The file is saved under `raw/` using the input stem plus `_trigger_shift_diagnostics.mat`. It is written for fixed and photodiode modes.

Photodiode modes also open a figure with paired before/after waveforms, a histogram of successful estimates, and measured delay over recording time by target code. Stage 1 leaves the figure open for inspection.

## Practical implications

- Create settings with the current Stage 0 before running Stage 1.
- Enter exact character trigger codes.
- Use a numeric value for one fixed correction, `'variable'` for individual detections with median fallback, or `'median'` for one participant-recording median.
- Inspect warnings, the diagnostics MAT file, and the diagnostic figure rather than treating completion as evidence that every event had a direct detection.
- Review the median support count and delay distribution for every participant.
- Do not change detection parameters merely to make a diagnostic plot look cleaner; changes require a scientific rationale.

## Validation scope

Trigger shifting is covered by deterministic MATLAB R2024b tests for direction and rounding, exact target matching, per-event identity, median-before-rounding behavior, fallback warnings, duration conversion, zero-time anchoring, boundary and discontinuity handling, missing-channel and no-detection errors, out-of-bounds errors, and diagnostic agreement.

Representative BDF runs have also exercised variable and median modes, event handling, saved SET output, diagnostics, and persistent figures. Synthetic integration tests use controlled substitutes for selected EEGLAB operations, so the evidence does not establish every specialized real-data or plugin-version edge case.
