# Task T1.2-B handoff

Work began on clean branch `codex/t12-photodiode-reference` at `2a624b4`.
The local production `shift_triggers.m` matches main at `9957258`. No branch
update was necessary for this isolated reference. CD-13 supplied by the
researcher supersedes the older direction/rounding discussion in this branch's
coordination documents and photodiode audit. Those files remain unchanged.

## Application audit

In `shift_triggers.m`, lines 161--170 compute a fixed offset with `ceil` and
add it to matching events. Lines 129--130 and 153--154 do the same for variable
delays. Addition agrees with CD-13; `ceil` does not. At 500 Hz, -1 ms currently
becomes zero samples, whereas CD-13 requires -1 sample. At 1000 Hz, +0.2 ms
currently becomes +1 sample, whereas CD-13 requires zero. Original fractional
latencies must remain fractional: add the rounded offset without rounding the sum.

Lines 122 and 148 reset the trial counter for every event, so all matches use
delay 1. Moving the counter alone will not establish epoch/event identity.
The epoched event list can contain multiple targets within one epoch; omitted
epochs can make the retained trial sequence differ from continuous targets.
The current loops check neither mapping identity nor cardinality before mutation.

Line 56 assumes numeric targets through `arrayfun(@num2str, ...)`, incompatible
with the configured cell-of-character contract. The mixed `ismember` expressions
at lines 125--126, 149--150 and 167--168 are not reliable scalar exact-character
tests. In particular, a multi-character input can produce a nonscalar first
operand for `||`. Production must use exact whole-code matching under CD-11.
The existing latency assignments themselves leave other fields unchanged, but
the function returns no separate per-event before/after record. Its plots and
delay-range summary do not establish correct continuous-event application.

## Reference interface

```matlab
% Fixed: broadcast one delay to every exact matching target.
[out, audit] = apply_trigger_delays_reference(events, {'121'}, 20, 500);
% Mapped: delay k belongs to event mapping(k), regardless of event order.
[out, audit] = apply_trigger_delays_reference( ...
    events, {'121'}, [30, -10], 500, [5, 1]);
```

The helper accepts a plain struct vector (type/latency plus arbitrary metadata),
a cell vector of character targets, double delays in ms and double sample rate.
Fixed mode requires a scalar. Mapped mode requires one finite delay per unique
valid event index, covering exactly the matching target set. A scalar does not
broadcast in mapped mode. All checks precede output mutation. Diagnostics are a
separate table containing event index/type, delay, original latency, rounded
offset and corrected latency, in mapping order. Output events retain their
original shape, order, types, metadata and field set, even if latencies cross.

The complete-mapping requirement defines the accepted input to this numerical
reference; it does not determine what production should do about omitted epochs.
The caller must establish mapping provenance independently. Even a valid
permutation of matching event indices can be scientifically wrong if paired
with another trial's delay. Tests deliberately supply a nonchronological mapping
to ensure the helper honors explicit identity rather than inferring sequence.
No EEGLAB calls, optional toolboxes, graphics or external datasets are required.

## Validation and MATLAB instructions

MATLAB/Octave is unavailable here; no runtime pass is claimed. Static review
checked function/file names, local helper path setup/restoration, expected
hand-calculated offsets and latencies, and validation before mutation.
`git diff --check` must pass for the committed additions.

From the repository root in MATLAB R2024b:

```matlab
results = runtests(fullfile('tests', 'test_trigger_latency_application.m'));
table(results)
assertSuccess(results)
```

No additional setup is required. The suite covers signed/zero fixed delays,
half-integer ties in both directions, fractional offsets and original latencies,
exact prefixed/spaced/leading-zero codes, distinct mapped delays, event and
metadata preservation, mapping/count errors, and diagnostic agreement.

## Remaining T1.2-C requirements

- Apply CD-11 exact matching and CD-13 addition/offset rounding in production.
- Establish retained-epoch-to-continuous-event identity before applying delays;
  retain an inspectable mapping and before/after record outside event fields.
- Obtain researcher decisions for threshold, sustained duration, zero-time
  anchor, missing/zero-range crossings, and omitted boundary epochs. The helper
  accepts finite resolved delays only; it cannot resolve T1.2-A status values.
- Validate corrected latencies against actual dataset bounds and check EEGLAB
  consistency during integration. This kernel lacks a dataset length and does
  not clip, reject, or sort corrected events based on dataset boundaries.
- Retain useful EEGLAB preprocessing, event handling and diagnostic operations;
  perform representative integration validation after the policies are approved.

Only the new helper, test file and this handoff belong to this change. Production,
coordination documents, previous tests, shared runners and wiki drafts are untouched.
