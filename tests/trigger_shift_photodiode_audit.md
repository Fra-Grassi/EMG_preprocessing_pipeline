# Photodiode onset-detection audit (Task T1.2-A)

This report audits the variable branch of `shift_triggers.m` at baseline commit
`3786055` (`Record validated event handling integration`). It describes current
behavior; it does not approve that behavior. CD-11 remains authoritative: event
types and configured event codes are character-based, and experimenter-encoded
content is not rewritten.

The accompanying helper is a test-only numerical reference. It neither changes
production behavior nor applies a delay to an event.

## Current variable-mode sequence

At approximately lines 54--159, the production function does the following:

1. It runs `arrayfun(@num2str, epoch_trigger, 'UniformOutput', 0)` before it
   decides between fixed and variable mode. This produces a cell array of
   character trigger codes when `epoch_trigger` is numeric, but it is not a
   valid implementation of CD-11 for character or cell-array inputs.
2. For variable mode, it requires `epoch_window`. It uses a default
   `signal_threshold` divisor of 4 if the optional value is absent.
3. It copies `EEGin.srate` and searches channel labels in case-sensitive order.
   Exact label `Erg1` wins; exact label `photodiode` is the fallback.
4. It selects only that channel with `pop_select`.
5. It calls the CleanLine plugin's `pop_cleanline` on the continuous selected
   channel. The call scans around 50 Hz with a 4-second window and 2-second
   step, among other hard-coded parameters.
6. It calls `pop_epoch` around all supplied target types using `epoch_window`.
   EEGLAB creates an epoched photodiode dataset and may omit events for which
   the requested epoch cannot be extracted.
7. It subtracts the mean over the fixed `[-29 0]` ms baseline with
   `pop_rmbase`, rectifies all epoch samples with `abs`, subtracts the mean of
   the rectified signal over `[-29 0]` ms a second time, and calls
   `eeg_checkset`.
8. For a diagnostic "before" plot, it calls `pop_epoch` again on the already
   epoched and transformed `diode` dataset, using the original trigger types
   and window, then reshapes the channel data for plotting.
9. For every retained photodiode epoch, it looks for samples whose time is
   exactly zero. From that sample through the epoch end, it computes
   `range(thistrial) / signal_threshold`. It compares the processed amplitude
   directly with that positive value using `>=`.
10. It creates a logical threshold mask. `bwareafilt` retains every contiguous
    true run whose length is at least 10 samples. The first sample of the first
    retained run is selected.
11. It attempts to convert that within-search-window index back to an epoch
    time with `diode.times(tp0 + idx)`. Because `idx` is one-based within a
    vector beginning at `tp0`, this advances the result by one sample.
12. It reports the range of unique delay values.
13. It loops over events in the epoched photodiode dataset. For each matching
    event it resets `thistrialhelper` to zero, increments it to one, takes
    `delays(1)`, converts milliseconds to samples with `ceil`, and adds the
    sample shift to that event latency.
14. It epochs the modified photodiode dataset over `[-0.02 0.02]` seconds and
    plots the twice-epoched "before" data above the newly epoched "after" data.
15. It repeats the event loop on the continuous input dataset. The counter is
    again reset inside every iteration, so every matching event uses
    `delays(1)`. It adds the result of the same `ceil` conversion to continuous
    event latency and returns that dataset.

The threshold deserves an exact algebraic description. If `x(t)` is the
CleanLine output, `b1` is the first baseline mean, `y(t) = abs(x(t) - b1)`, and
`b2` is the baseline mean of `y`, the detector receives `z(t) = y(t) - b2`.
Over the exact-zero-to-epoch-end search interval it calculates

```text
q = (max(z) - min(z)) / signal_threshold
```

and declares `z(t) >= q`. Equivalently, on the rectified pre-second-baseline
scale it declares `y(t) >= b2 + range(y) / signal_threshold`. It does **not**
calculate `min(z) + range(z) / signal_threshold`. The range is determined from
the post-zero search interval, so any peak or outlier in that interval changes
the threshold. A zero-range, zero-valued processed signal yields a threshold of
zero and therefore marks every searched sample as above threshold.

## Definite coding defects

The following findings do not depend on choosing a scientific threshold,
duration, delay direction, rounding rule, or missing-trial policy.

### 1. Target conversion and matching violate the character-event contract

- **Location:** `shift_triggers.m`, approximately lines 54--56, 121--131, and
  147--155; integration is supplied from `EMG_00_settings.m` lines 132--136.
- **Current behavior:** `arrayfun(@num2str, ...)` assumes a numeric target
  array. A character code is processed character-by-character (through its
  numeric character values), and a cell array of character codes is not a
  valid input to this `arrayfun` call. Later, a multi-character event type is
  compared with numeric targets by `ismember` and fed to scalar `||`; the first
  comparison can itself be nonscalar. Stage 0 also initializes
  `sets.shift_markers = []` despite saying condition triggers are assumed when
  no separate markers are supplied; Stage 1 implements no fallback.
- **Why incorrect:** CD-11 requires character-based, exact-content matching.
  The current conversion does not preserve such inputs and the empty-marker
  setting does not implement its documented fallback.
- **Consequence:** variable epoching can receive incorrect/empty types, and
  either event-shifting loop can error or fail to identify the intended events.
- **Later fix:** Task T1.2-C for production integration, consuming the
  character-matching contract already validated in Tier 1.1. Target-only
  latency behavior should remain covered by Task T1.2-B.

### 2. Missing recognized channel leaves a variable undefined

- **Location:** `shift_triggers.m`, approximately lines 76--84.
- **Current behavior:** if neither exact label is found, `photodiode_chan` is
  never assigned before it is passed to `pop_select`.
- **Why incorrect:** failure is an incidental undefined-variable error rather
  than an explicit validation result identifying the absent channel.
- **Consequence:** variable mode aborts without an actionable photodiode-channel
  diagnostic.
- **Later fix:** Task T1.2-C.

### 3. The exact-zero lookup is not cardinality-checked

- **Location:** `shift_triggers.m`, approximately lines 106--109.
- **Current behavior:** `find(diode.times == 0)` is used directly as the first
  operand of a colon expression. It can be empty when no sample equals zero
  exactly (or nonscalar if the time vector is malformed/repeated).
- **Why incorrect:** the subsequent indexing requires exactly one scalar index,
  but the code does not establish that precondition.
- **Consequence:** detection fails before it can produce a trial status.
- **Later fix:** Task T1.2-C after the researcher selects the no-exact-zero
  policy. The absence of validation is the defect; which fallback to use is a
  Gate S decision.

### 4. A missing sustained crossing is used as though it were an index

- **Location:** `shift_triggers.m`, approximately lines 113--116.
- **Current behavior:** `find(..., 1)` can return empty, after which the code
  evaluates `diode.times(tp0 + idx)` and tries to append the empty result to
  `delays(end+1)`.
- **Why incorrect:** an expected detector outcome is not represented before an
  array-index/assignment operation that requires a scalar value.
- **Consequence:** processing errors instead of returning one explicit result
  per retained trial.
- **Later fix:** Task T1.2-C after the researcher approves what production does
  with the neutral `no_crossing` status.

### 5. Within-window index conversion is off by one sample

- **Location:** `shift_triggers.m`, approximately line 115.
- **Current behavior:** `thistrial(1)` is `diode.data(..., tp0, ...)`, but its
  time is read from `diode.times(tp0 + 1)` when `idx == 1`.
- **Why incorrect:** the global index is `tp0 + idx - 1`, not `tp0 + idx`.
- **Consequence:** every successfully detected delay is reported one sample
  later than the selected onset. This precedes and is separate from later
  milliseconds-to-samples rounding.
- **Later fix:** Task T1.2-C.

### 6. Trial counters reset inside both event loops

- **Location:** `shift_triggers.m`, approximately lines 121--133 and 147--157.
- **Current behavior:** `thistrialhelper = 0` is executed for each event. A
  matching event increments it only to one and therefore reads `delays(1)`.
- **Why incorrect:** the counter cannot represent progression through trials.
- **Consequence:** all matching epoched and continuous events receive the first
  retained epoch's detected delay, even when trials have distinct onsets.
- **Later fix:** Task T1.2-C. Task T1.2-B should supply the validated ordered
  latency-application behavior.

### 7. Delay/event cardinality and identity are never validated

- **Location:** delay construction at approximately lines 104--116 and
  continuous application at lines 146--157.
- **Current behavior:** delays are created in retained epoch order, but are
  later treated as though they correspond positionally to every matching event
  in the continuous dataset. No count check or EEGLAB `epoch`/`urevent` identity
  is retained for this association.
- **Why incorrect:** positional application is only valid after one-to-one
  identity and cardinality have been established. EEGLAB may omit an
  out-of-bounds epoch, and an epoch may contain additional matching events.
- **Consequence:** after the counter-reset bug is removed, a missing or extra
  epoched event could still shift the wrong later continuous event or cause an
  out-of-range delay lookup.
- **Later fix:** Task T1.2-C, after the researcher approves the boundary-epoch
  reconciliation policy. Task T1.2-B owns mismatch-before-mutation behavior.

### 8. A flat zero processed trial is reported as an onset

- **Location:** `shift_triggers.m`, approximately lines 109--114.
- **Current behavior:** a zero-range, zero-valued search signal produces
  `threshold = 0`; `thistrial >= 0` is true throughout and a sufficiently long
  flat segment qualifies.
- **Why incorrect:** the routine claims to detect a change in a signal that has
  no change.
- **Consequence:** a nonresponsive/flat photodiode trial can receive a delay at
  the search anchor instead of a non-detection status.
- **Later fix:** Task T1.2-C should validate that the selected threshold
  definition is informative before run detection. The researcher still owns
  the wider missing-crossing policy.

## Scientific or policy decisions

Every item below is unresolved Gate S work. The reference helper exposes a
choice where it is part of numerical detection, or returns neutral information
for a later policy. None of these alternatives is approved here.

### Direction of a positive measured delay

- **Current code:** adds `ceil(srate / 1000 * delay_ms)` to event latency, so a
  positive measured time moves an event later.
- **Plausible alternatives:** add the value, subtract it, or define a signed
  offset at the interface and apply that signed value.
- **Effect:** the same 20 ms observation moves the corrected event in opposite
  temporal directions under add versus subtract.
- **Researcher decision:** define what `delay_ms` means relative to recorded
  trigger time and whether a positive value increases latency.
- **Ownership:** Task T1.2-B; the reference helper does not apply delays.

### Milliseconds-to-samples conversion

- **Current code:** uses `ceil(srate / 1000 * delay_ms)`.
- **Plausible alternatives:** `round`, `floor`, another documented rule, or a
  permitted fractional EEGLAB latency.
- **Effect:** noninteger sample offsets can differ by one sample; for negative
  values, `ceil` moves toward zero.
- **Researcher decision:** select and document the conversion rule and behavior
  for positive and negative values.
- **Ownership:** Task T1.2-B; the reference helper returns epoch times in
  milliseconds and performs no conversion.

### Threshold relative to the processed signal

- **Current code:** after baseline, rectification, and second baseline, uses an
  unanchored `post-zero range / divisor` and `>=` comparison. The scope is the
  zero-to-epoch-end segment. With the Stage 0 value 4, the value is one quarter
  of that segment's max-minus-min range.
- **Plausible alternatives:** an absolute processed-amplitude threshold;
  minimum plus a fraction of range; baseline-relative mean/variance or robust
  baseline statistics; a threshold based on the full epoch or a fixed search
  window; `>` rather than `>=`; or a polarity-specific detector without
  rectification.
- **Effect:** these definitions cross at different samples and have different
  sensitivity to offsets, extrema, outliers, noise, and flat signals.
- **Researcher decision:** specify the processed signal, threshold formula,
  estimation window, comparison operator, and any polarity assumption.
- **Reference exposure:** `threshold_mode`, `threshold_value`,
  `threshold_scope`, and `threshold_comparison` are all required. The
  `range_divisor_unanchored` option reproduces the current mathematical
  threshold on already processed input; its presence is not approval. Unlike
  production, the reference reports a neutral `"zero_range"` status before
  comparison when a range-based threshold has no signal variation.

### Sustained-crossing duration

- **Current code:** requires 10 consecutive samples. At sampling rate `fs`,
  this spans 10 samples and corresponds to `10 / fs` seconds by sample count.
- **Plausible alternatives:** retain a sample count, specify a duration in
  milliseconds and an explicit conversion rule, or define elapsed time using
  the supplied epoch time vector.
- **Effect:** a fixed sample count changes physical duration across sampling
  rates, while a fixed duration may require a rounding/boundary convention.
- **Researcher decision:** select the scientific duration and its unit.
- **Reference exposure:** `minimum_run_samples` is mandatory. The helper does
  not convert milliseconds; callers can test any proposed integer run length
  without silently selecting a conversion rule.

### Trial with no valid crossing

- **Current code:** reaches an empty-index/assignment failure; this is not an
  intentional policy.
- **Plausible alternatives:** abort the participant with a trial-specific
  error, leave that trigger unchanged while recording status, mark the trial
  missing for later review, or use another explicit quality-control workflow.
- **Effect:** alternatives differ in whether downstream data remain complete,
  partially corrected, or unavailable.
- **Researcher decision:** choose the production action and required audit
  record.
- **Reference exposure:** one `"no_crossing"` status and `NaN` diagnostic delay
  are returned for that input trial. No event action follows from this status.

### No exact zero-time sample

- **Current code:** exact equality is required accidentally; absence later
  causes indexing failure.
- **Plausible alternatives:** require exact zero and return an explicit status;
  begin at the first nonnegative sample; use a nearest sample; define how an
  equal-distance tie is resolved; or interpolate a zero-time value.
- **Effect:** search start can move to the preceding or following sample and can
  change threshold estimation, detection time, and whether a negative epoch
  time is eligible.
- **Researcher decision:** approve the anchor rule and tie behavior.
- **Reference exposure:** `zero_time_policy` is required. Available
  investigation modes are `require_exact`, `first_nonnegative`,
  `nearest_earlier`, and `nearest_later`. Diagnostics report exact-zero
  presence and the selected anchor. These modes are alternatives, not defaults.

### Boundary epochs omitted from continuous data

- **Current code:** does not reconcile them. It derives delays only for
  retained epochs and then iterates all continuous targets.
- **Plausible alternatives:** abort on any omitted target epoch; keep an
  explicit target identity/status table and leave omitted targets unchanged;
  exclude specified boundary targets under an auditable rule; or use another
  approved mapping policy.
- **Effect:** choices determine whether later targets can be shifted, remain
  unchanged, or cause participant-level failure.
- **Researcher decision:** define the permissible result for every target event
  lacking an extractable epoch.
- **Ownership:** Task T1.2-C integration, supported by Task T1.2-B mismatch
  checks. The numerical reference preserves only input trial order and cannot
  decide continuous-event identity.

Other undocumented current assumptions that require review during integration
include exact case-sensitive channel labels and `Erg1` precedence when both are
present; fixed 50 Hz cleaning and fixed CleanLine parameters; the fixed
`[-29 0]` ms baseline being present within every configured epoch; inclusion of
0 ms in both baseline calls; rectification and a second subtractive baseline;
and the possibility that re-epoching an already epoched dataset selects a
different diagnostic trial set. The "before" and "after" plotting path therefore
needs an explicit paired-trial check. The four-element line `Color` values are
also outside the documented RGB-triplet form for the target MATLAB release and
should be treated as an unverified graphics-compatibility assumption rather
than validation evidence.

## Dependencies

### Current production path

- **EEGLAB core/data model:** `pop_select`, `pop_epoch`, `pop_rmbase`, and
  `eeg_checkset`, plus EEGLAB channel, event, epoch, and `urevent` structures.
  `pop_epoch` is the correct class of operation for extracting event-locked
  epochs, and EEGLAB's epoch structure retains event and `urevent` associations
  that the current mapping does not use. See the official
  [epoch extraction tutorial](https://eeglab.org/tutorials/07_Extract_epochs/Extracting_Data_Epochs.html)
  and [EEGLAB data-structure guide](https://eeglab.org/tutorials/ConceptsGuide/Data_Structures.html).
- **CleanLine plugin:** `pop_cleanline` is not MATLAB or EEGLAB core. The plugin
  also describes Chronux-derived and BCILAB argument-processing code. Parameter
  names and the forced legacy-style `newversion = 0` call should be verified
  against the installed plugin version. See the official
  [CleanLine plugin documentation](https://eeglab.org/plugins/cleanline/).
- **Image Processing Toolbox:** `bwareafilt` is an image connected-component
  filter used here only to retain logical runs by size. MathWorks documents it
  under [Image Processing Toolbox](https://www.mathworks.com/help/images/ref/bwareafilt.html).
  This is unnecessary for one-dimensional run-length detection.
- **Statistics and Machine Learning Toolbox:** the current `range` call is
  documented under [Statistics and Machine Learning Toolbox](https://www.mathworks.com/help/stats/range.html).
  A direct `max - min` calculation avoids this otherwise unnecessary numerical
  dependency.
- **MATLAB graphics:** the current diagnostic requires interactive graphics.
  MathWorks documents line `Color` as a name, hexadecimal value, or
  three-element RGB triplet in the R2024b-compatible
  [`plot` documentation](https://www.mathworks.com/help/matlab/ref/plot.html);
  line alpha is not represented by the four-element values used here.
- **Stage 1 beyond the detector:** `eeglab`, the BDF import plugin
  (`pop_readbdf`), `pop_chanedit`, and `pop_saveset` remain legitimate
  integration dependencies. The production architecture is not expected to
  remove EEGLAB.

### New reference helper

`tests/helpers/detect_photodiode_delays_reference.m` uses only base MATLAB
numeric, logical, string, and structure operations. It calls no EEGLAB function,
does not call `range`, and implements contiguous runs with `diff` and `find`
rather than `bwareafilt`. It therefore eliminates both the Image Processing
Toolbox and Statistics and Machine Learning Toolbox requirements for this
test-only detection step. It does not add a production dependency.

## Mapping risks

### Event order and multiple target types

`pop_epoch` is called once with all target types. The resulting third data
dimension supplies delay order. The current code does not save the accepted
event indexes returned by epoching or construct an identity table from
`diode.epoch`/`urevent`. It instead loops over every event in the epoched
dataset, where an epoch can contain its time-locking event plus other events.
If another configured target lies inside the short epoch, there can be more
matching `diode.event` entries than trials. Multiple target types are pooled in
one positional sequence with no recorded type/identity alongside the delay.

The later continuous loop uses continuous event order. Even if both structures
normally sort events chronologically, equality of order is not proof that the
Nth retained epoch belongs to the Nth continuous target. A production mapping
must establish identity before mutation.

### Omitted boundary epochs and count mismatches

An event too close to the beginning or end of continuous data cannot supply the
requested epoch. Likewise, boundary events/discontinuities can make an epoch
unusable. The photodiode delay vector then has fewer entries than the continuous
target-event sequence. The current function neither captures accepted epoch
indexes nor compares counts. A simple counter fix alone would therefore create
an out-of-range lookup or, worse, shift later events with delays belonging to
different targets.

### Current counter behavior

Both counters are scoped inside their event loops, making every match use delay
1. This currently masks later count exhaustion while applying wrong values. A
counter moved outside a loop would correct only that local defect; it would not
resolve multiple matching events per epoch, omitted epochs, identity, or the
researcher's boundary policy.

The numerical helper intentionally stops at processed input trials. It returns
exactly one ordered status and diagnostic structure per row and does not claim
that a row maps to any continuous event. That association belongs to Tasks
T1.2-B/T1.2-C.

## Reference interface and alternatives

The chosen interface is

```matlab
[delays_ms, status, diagnostics] = ...
    detect_photodiode_delays_reference(processed_trials, times_ms, options)
```

Rows are trials and columns are samples. The required options structure makes
threshold mode/value/scope/comparison, integer sustained-run length, and
zero-time policy visible at every call. `delays_ms`, `status`, and `diagnostics`
all have one element per input row in unchanged order. Diagnostics retain both
the global sample index and the one-based within-search index, allowing the
off-by-one conversion to be tested directly.

Reasonable alternative interfaces include samples-by-trials orientation;
separate positional arguments instead of one options structure; accepting only
caller-computed absolute thresholds; or returning a table/structure instead of
three outputs. The chosen form follows the project's trial-oriented outputs,
keeps evolving policy fields named, and exposes both the current unanchored
range-divisor formula and a contrasting minimum-anchored formula without
declaring either approved.

## Proposed acceptance criteria for production integration

The following checklist is proposed for Task T1.2-C. Items marked **RESEARCHER
APPROVAL REQUIRED** cannot be finalized from technical evidence alone.

- [ ] Preserve CD-11 character event types and exact trigger content; accept
  the documented configured target representation without character-code
  conversion.
- [ ] Resolve the empty `shift_markers` versus `condition_triggers` contract
  explicitly before epoching.
- [ ] Validate a recognized photodiode channel and report which channel was
  selected; document precedence if both recognized labels exist.
- [ ] Keep appropriate EEGLAB selection, continuous-data cleaning, epoching,
  baseline handling, consistency checks, event manipulation, and visualization
  in production; validate each call against the installed EEGLAB/plugin version.
- [ ] **RESEARCHER APPROVAL REQUIRED:** approve line-noise, baseline,
  rectification, second-baseline, polarity, and threshold-estimation sequence.
- [ ] **RESEARCHER APPROVAL REQUIRED:** approve threshold formula, value,
  estimation scope, and comparison operator, including behavior for zero-range
  or otherwise uninformative trials.
- [ ] **RESEARCHER APPROVAL REQUIRED:** approve sustained-run value and whether
  it is expressed in samples or milliseconds; if milliseconds, approve its
  sample-boundary conversion.
- [ ] **RESEARCHER APPROVAL REQUIRED:** approve exact-zero, first-nonnegative,
  nearest-sample/tie, interpolation, or explicit-failure behavior.
- [ ] Return the first sample of the first qualifying run with global index
  `search_start + within_search_index - 1`; cover epoch-final runs.
- [ ] Return exactly one explicit detection status per extracted input epoch;
  never use an empty detection as an array index.
- [ ] Preserve accepted epoch identity (for example through accepted-event and
  `urevent` links), target type, trial order, and status in an auditable mapping.
- [ ] Validate delay/target cardinality and identity before changing any event.
- [ ] **RESEARCHER APPROVAL REQUIRED:** approve participant/trial behavior for
  no crossing and for continuous targets whose epochs are omitted at a boundary.
- [ ] **RESEARCHER APPROVAL REQUIRED (Task T1.2-B):** approve whether positive
  measured delay increases latency.
- [ ] **RESEARCHER APPROVAL REQUIRED (Task T1.2-B):** approve milliseconds-to-
  samples rounding or fractional-latency behavior.
- [ ] Apply trial-specific delays only to their mapped target events; preserve
  non-target events, event order, and an inspectable before/after latency record.
- [ ] Make diagnostic plots use the same mapped trials before and after
  correction, with MATLAB R2024b-supported graphics properties.
- [ ] Pass the numerical reference tests in MATLAB R2024b without EEGLAB or
  optional toolboxes, then run a separate EEGLAB integration test on
  representative non-raw data with normal and boundary cases.
