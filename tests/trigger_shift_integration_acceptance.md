# T1.2-C implementation and acceptance

CD-11 and CD-13--15 (including the coordinator's approved supplemental text)
govern this implementation. The branch merged main at `232b824`; the merge
imports already integrated changes, including Stage 2/documentation changes,
but this task makes no additional edits to those files.

## Delivered behavior

`shift_triggers` retains numeric fixed delays and adds `'median'` beside
`'variable'`. It adds rounded signed sample offsets to original latencies.
Photodiode modes retain continuous CleanLine and the two baseline subtractions
around rectification. The divisor defaults to 4, minimum duration to 20 ms
(ceiling sample-count conversion), and nearest-zero ties choose the positive
sample. Missing crossings, zero-range and nonfinite signals, and omitted epochs
are excluded from median estimation. Variable substitutes the recording median;
median uses it for all targets. No successful detections errors. Corrected
latencies outside [1, EEG.pnts] error before the caller receives modified data.

The second output is a diagnostic structure: `events` is a table indexed by
original event-array position, with measured/applied delays and original/corrected
latencies. It records unsuccessful reasons, detected sample, threshold and epoch
identity. Summary fields include median and support count. `paired` holds the
same retained waveforms, their original event identities, and before/after time
axes shifted by the actual applied sample offsets. No re-epoching or
interpolation is needed for paired plotting. Omitted epochs cannot be plotted;
available epochs with missing detections remain included using their fallback.
Histogram and recording-time plots show successful measured delays, with target
types distinguished in the latter. No condition-specific median or outlier
exclusion is introduced.

Stage 0 adds `shift_minimum_duration_ms = 20`. Stage 1 resolves empty markers to
`condition_triggers`, uses the default for older saved settings without this
field, and saves `<input_stem>_trigger_shift_diagnostics.mat` beside the raw SET
output. Existing files with that diagnostic name are overwritten on rerun,
consistent with Stage 1 output behavior. The MAT file contains processed
photodiode waveforms as well as the audit and can be sizable.

## Verified mapping semantics and compatibility

Inspected installed EEGLAB 2019 source (`pop_epoch.m`, lines 222--257,
331--338 and 389--406; `epoch.m`, lines 106--159) and official
[current pop_epoch source](https://github.com/sccn/eeglab/blob/develop/functions/popfunc/pop_epoch.m)
on 2026-09-08. `pop_epoch` sorts events, selects candidate positions, and returns
positions within that candidate list after sample-boundary and discontinuity
exclusions. They are not original continuous event indices. The code composes
this accepted-position vector with an explicit original-event permutation.
It selects exact types before epoching and passes empty types plus explicit
candidate event indices, bypassing type selection that can trim trailing spaces.

The preflight uses epoch.m's rounded sample bounds and its floor(event latency)
plus requested window for boundary-event inclusion. This avoids version-specific
errors when every epoch would be removed. Additional EEGLAB omissions still map
through accepted positions and are reported as `omitted_epoch`. The window must
include the existing [-29,0] ms baseline and positive time. Character `boundary`
events identify discontinuities under CD-11.

The output undergoes basic `eeg_checkset`, then its original event array is
restored before assigning approved latencies. Full `eventconsistency` can sort
or rewrite event values; output preserves event order and exact codes even if
corrected events cross. No urevent or metadata is rewritten. The working diode
dataset retains EEGLAB's epoch consistency checks. Verify downstream operations
on real EEGLAB, especially if delays change chronological order.

CleanLine's existing argument set is retained. CleanLine is not installed in
this workspace; the installed plugin version must accept these arguments during
acceptance. Neither `bwareafilt` nor `range` is needed in production detection.
The earlier numerical references and their historical audits remain unchanged.

## Automated MATLAB checks (not executed here)

MATLAB and Octave are unavailable. Static inspection and Git whitespace checks
are the available local validation; no runtime passes are claimed.
The existing CRLF endings in `shift_triggers.m` and Stage 1 are preserved.
Use `git -c core.whitespace=cr-at-eol diff --check` for these files: plain Git
whitespace checking otherwise flags each preserved carriage return. Stage 0
and new test/documentation files retain LF endings.
From the project root in MATLAB R2024b:

```matlab
results = runtests(fullfile('tests', 'test_shift_triggers_production.m'));
table(results)
assertSuccess(results)
results = runtests(fullfile('tests', 'test_photodiode_delay_detection.m'));
assertSuccess(results)
results = runtests(fullfile('tests', 'test_trigger_latency_application.m'));
assertSuccess(results)
```

The new suite executes production arithmetic, identity composition, duration,
anchor, fallback, bounds and diagnostics using five narrow stubs for EEGLAB
operations. It does **not** validate channel selection, CleanLine, baseline
subtraction, real epoch omissions or graphics. Mock epochs deliberately have
simple time grids; some grids are independent of the fixture sample rate to
isolate rounding decisions. The test temporarily prepends and then restores the
mock path. Do not add `tests/mocks` recursively to a normal production MATLAB
path. In a real acceptance session, confirm `which pop_epoch -all` and
`which eeg_checkset -all` point to EEGLAB, not the stubs.

## Real EEGLAB acceptance required

1. On a fresh MATLAB/EEGLAB session with CleanLine, use a disposable in-memory
   copy of an authorized continuous recording (never overwrite acquisition data).
   Confirm character target codes, sampling rate and the photodiode label.
2. Run numeric fixed mode with positive, zero and negative values. Compare exact
   target latencies with the approved rounded offsets; preserve non-target
   events, metadata and fractional latencies. Confirm bounds failures.
3. Run both photodiode modes, capturing both outputs:

```matlab
[shifted, audit] = shift_triggers(EEG, {'121','221'}, ...
    'variable', [-.06 .1], 4, 20, true);
disp(audit.events)
assert(all(audit.events.corrected_latency == ...
    audit.events.original_latency + round(audit.events.applied_delay_ms*EEG.srate/1000)))
```

4. Inspect continuous event identities against retained epochs, including two
   target types, extra targets within an epoch, unsorted input events, a target
   near each recording end and an epoch containing a `boundary` event. Check
   the explicit accepted-position mapping against the installed EEGLAB source;
   counts alone are insufficient. Confirm exact trailing-space codes remain
   distinct in the input and returned events.
5. In a synthetic disposable signal, create distinct sustained onsets, a flat
   epoch, an isolated short excursion and a boundary omission. Confirm only
   successful delays contribute to the median in ms and fallback warns with
   event IDs/reasons, median and support count. Repeat with one successful
   detection, then none. Remove recognized photodiode labels and confirm error.
6. At 512 Hz confirm 20 ms needs 11 samples, and that a 10-sample excursion
   fails. Inspect the two baseline operations and first qualifying sample.
7. Verify the paired panels contain identical event identities/waveforms, with
   corrected time axes translated by the applied offsets. Inspect distribution
   and recording-time plots; do not change scientific parameters merely to
   improve appearance. No RGBA line colors are used.
8. Run Stage 0 then Stage 1 with empty `shift_markers`; inspect the saved audit
   and returned SET. Repeat with explicit character markers and median mode.
   Check saved SET event values after reloading, and report any EEGLAB-induced
   sorting or metadata changes separately from the function's returned array.

No further scientific decisions are assumed necessary under CD-13--15.
Runtime compatibility, real EEGLAB mapping/preprocessing, plots and Stage 1
save/reload validation remain outstanding until researcher acceptance.
