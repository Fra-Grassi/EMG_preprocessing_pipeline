# Trigger Shifting and Diagnostics

This page explains how Stage 1 corrects selected event latencies using a fixed delay or a photodiode signal, how unavailable photodiode estimates are handled, and what evidence is saved for inspection. It describes the approved behavior in CD-13 through CD-16; it does not introduce new timing assumptions.

## Why trigger shifting exists

An event marker records when a trigger reached the acquisition system. The physical event measured by a photodiode can occur later or earlier. Trigger shifting changes the selected event's latency so it represents the approved timing correction while leaving its exact character code and other event metadata intact.

The direction and conversion are the same in all three modes:

```text
sample offset = round(delay in ms × sampling rate / 1000)
corrected latency = original latency + sample offset
```

A positive delay moves the event later; a negative fixed delay moves it earlier; zero leaves it unchanged. Only the calculated offset is rounded to a whole sample. An original latency with a fractional part keeps that fractional part.

## The three interfaces

Stage 0 controls the step with `sets.do_shift_triggers` and chooses the behavior with `sets.shift_method`:

| `sets.shift_method` | Delay applied to each selected target |
| --- | --- |
| Signed numeric value | The same configured delay in milliseconds. No photodiode estimate is required. |
| `'variable'` | That event's detected photodiode delay when available; otherwise the participant recording's median successful delay. |
| `'median'` | The participant recording's median successful photodiode delay for every selected target. |

Target codes come from `sets.shift_markers`. They must be exact MATLAB character codes: prefixes, spaces, and leading zeros are significant. If `sets.shift_markers` is empty, Stage 1 uses `sets.condition_triggers`. This preserves the CD-11 event contract rather than converting different-looking codes into a common value.

The photodiode modes also use:

- `sets.shift_window`, the epoch window around each target, which must include the −29 to 0 ms baseline and post-trigger data;
- `sets.shift_threshold`, the range divisor, currently configured with a default of 4;
- `sets.shift_minimum_duration_ms`, the required sustained-crossing duration, currently configured with a default of 20 ms.

Stage 1 requires settings saved by the current Stage 0 and reads `sets.shift_minimum_duration_ms` directly. Saved settings from earlier development versions are not a supported compatibility interface. The standalone `shift_triggers` function still documents optional defaults for omitted function arguments; those defaults do not migrate an older pipeline settings file. The broader reusable settings validator described by CD-10 remains future work.

## How photodiode delays are detected

For `'variable'` and `'median'`, the pipeline first identifies an `Erg1` channel or, if that label is absent, a `photodiode` channel. A missing photodiode channel is an error.

The selected signal follows the established EEGLAB and CleanLine preparation sequence:

1. run CleanLine on the continuous photodiode channel;
2. extract epochs around the configured target events;
3. subtract the mean of the −29 to 0 ms baseline;
4. full-wave rectify the signal;
5. subtract the same baseline again;
6. search the processed waveform from the zero-time anchor to the end of the epoch.

The search starts at the sample closest to zero, whether that sample is just before or just after zero. If negative and positive samples are equally close, the positive sample is selected. An exact zero sample is therefore not required.

Within each retained target epoch, the threshold is:

```text
threshold = range(search segment) / divisor
```

The comparison is `signal >= threshold`. The minimum signal amplitude is not added to the threshold. With the default divisor of 4, the threshold is one quarter of the processed search segment's range. Changing the divisor changes the numerical detection threshold; this page does not recommend a different value.

A detection must remain at or above the threshold for the configured minimum duration. Milliseconds are converted to a sample count with:

```text
minimum samples = ceil(duration in ms × sampling rate / 1000)
```

The first sample of the first qualifying sustained run is the measured delay. At 512 Hz, the default 20 ms duration is 10.24 samples, so 11 consecutive samples are required. This ceiling rule applies to the crossing duration; latency offsets use the separate nearest-sample `round` rule above.

The photodiode modes require EEGLAB and CleanLine. The sustained-run calculation is implemented directly and does not require `bwareafilt`.

## Participant median and unavailable estimates

The median is computed separately within each participant recording. It pools successful measured delays across all configured target codes and calculates the median in milliseconds before any delay is rounded to samples.

Only successful detections enter this reference. The following do not contribute:

- an epoch omitted because it would cross a recording boundary;
- an epoch containing an EEGLAB discontinuity boundary;
- another epoch omitted by EEGLAB;
- a nonfinite or flat photodiode signal;
- a processed signal with no qualifying sustained crossing.

Stage 1 preserves an explicit association between each retained photodiode epoch and its original event. It uses the accepted epoch positions returned by EEGLAB and maps them back to the original continuous-event indices. It does not assume that equal epoch and event counts prove the correct trial correspondence.

In `'variable'` mode, every successful event uses its own measured delay. An unavailable event uses the successful-delay median as a fallback. In `'median'` mode, every selected event uses that common median, including events with successful individual estimates.

One successful detection is sufficient to define the median, and the diagnostics show that the support count is one. If no target has a successful detection, the function errors because no median can be estimated. It also errors rather than guessing when the photodiode channel is missing or the epoch-to-event mapping returned by EEGLAB is inconsistent.

Warnings list each affected event, its character code, and the reason its estimate was unavailable. They also report the applied median and the number of successful detections supporting it. If a corrected event would fall before sample 1 or after the end of the recording, the operation errors; latencies are not clipped to the recording boundary.

## What a common median can and cannot align

A common median removes a common delay but preserves differences between trials. Suppose detected delays form two groups at 20 ms and 37 ms. If the median is 20 ms, the residual delays after the common correction are 0 ms and 17 ms. The groups remain 17 ms apart.

Depending on the number of observations in each group, the median may align one group or fall between them. By contrast, `'variable'` mode aligns each successfully detected onset using its own estimate; only trials without a usable estimate receive the common median fallback.

A two-cluster pattern is therefore useful diagnostic information rather than proof that median mode failed. Monitor-frame timing is one possible explanation for separated clusters, but the plot alone does not establish that cause.

## Diagnostics and Stage 1 outputs

Trigger shifting changes the latency field of selected events without adding audit fields to the EEGLAB event structure. Instead, `shift_triggers` returns a separate diagnostics structure containing, among other values:

- each selected event's original and corrected latency;
- measured and applied delays in milliseconds;
- the rounded sample offset;
- detection status, threshold, detected sample, and epoch mapping;
- the participant median and its number of successful supporting detections;
- paired photodiode waveforms before and after correction for retained epochs.

Stage 1 saves this structure as a MAT file beside the participant's SET output in `raw/`, using the input filename stem plus `_trigger_shift_diagnostics.mat`. It does this for fixed and photodiode modes. Photodiode modes also open a diagnostic figure with paired before/after waveforms, a histogram of successful estimates, and delay over recording time by target code. Stage 1 leaves these windows open for researcher inspection.

Stage 1 now imports BDF data and events with BIOSIG's `pop_biosig`, making BIOSIG an import dependency, and then applies the character-vector event normalization before any optional shift. Earlier study-specific hyperscanning import comments are no longer part of the production script.

## Validation evidence and limits

The researcher reported all synthetic trigger-shifting suites passing and successful actual-data Stage 1 runs in both `'variable'` and `'median'` modes at Agent 3 commit `9f4a6a1`, integrated as `5539508`. These suites cover the numerical direction and rounding, exact target matching, per-event identity, median-before-rounding behavior, fallback statuses and warnings, duration conversion, zero-time anchoring, recording-boundary and discontinuity handling, missing-channel and no-detection errors, out-of-bounds errors, and diagnostic agreement.

The researcher then confirmed a quick Stage 0 → Stage 1 run after the direct current-settings cleanup at `be6537d`. After the BIOSIG import and persistent-figure changes were committed as `c088082`, a representative BDF Stage 1 run also passed, including import, event handling, saved SET output, and the persistent diagnostic window.

The production synthetic suite replaces five EEGLAB operations with controlled test versions so it can verify integration arithmetic and mapping deterministically. The reported actual-data runs add representative end-to-end evidence, but they do not establish that every specialized real EEGLAB edge case listed in the acceptance guide was individually tested.

## User-facing implications

- Create settings with the current Stage 0 before running Stage 1.
- Enter exact character trigger codes; an empty `sets.shift_markers` deliberately reuses `sets.condition_triggers`.
- Choose a signed numeric delay for one common configured correction, `'variable'` for individual detected delays with median fallback, or `'median'` for one participant-recording median across all targets.
- Inspect warnings, the saved diagnostics MAT file, and any open photodiode diagnostic figure rather than treating a completed run as evidence that every trial had a direct detection.
- Interpret median support and any delay clusters at the participant-recording level. Do not infer a physical cause from the diagnostic plot alone.

## Traceability

- **Decisions:** [CD-13](../CONCEPTUAL_DECISIONS.md#trigger-shift-direction-and-rounding-cd-13), [CD-14](../CONCEPTUAL_DECISIONS.md#photodiode-detection-parameters-cd-14), [CD-15](../CONCEPTUAL_DECISIONS.md#median-shifting-and-fallback-cd-15), and [CD-16](../CONCEPTUAL_DECISIONS.md#current-settings-contract-cd-16). Exact character matching also follows [CD-11](../CONCEPTUAL_DECISIONS.md#event-representation-contract).
- **Production files and sections:** [`EMG_00_settings.m`, Trigger shift](../EMG_00_settings.m); [`EMG_01_raw2set_shift_triggers.m`, Sections 1.3.1, 1.3.2, and 1.3.4–1.3.6](../EMG_01_raw2set_shift_triggers.m); [`shift_triggers.m`](../shift_triggers.m).
- **Tests and references:** [`test_shift_triggers_production.m`](../tests/test_shift_triggers_production.m), [`test_trigger_latency_application.m`](../tests/test_trigger_latency_application.m), [`test_photodiode_delay_detection.m`](../tests/test_photodiode_delay_detection.m), [`apply_trigger_delays_reference.m`](../tests/helpers/apply_trigger_delays_reference.m), and [`detect_photodiode_delays_reference.m`](../tests/helpers/detect_photodiode_delays_reference.m).
- **Recorded validation:** [PROJECT_PLAN.md, Task T1.2-C and Validation baseline](../PROJECT_PLAN.md#task-t12-c-integrate-and-validate-trigger-shifting).
- **Current implementation status:** CD-13 through CD-16 are integrated. The researcher reported all synthetic suites passing, successful actual-data variable and median runs, successful current-settings cleanup, and a representative BDF run after the BIOSIG import and persistent-diagnostic changes at `c088082`. These claims do not extend beyond the stated validation evidence.
