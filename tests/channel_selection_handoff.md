# Tier 2.1 channel-selection handoff

## Problem addressed

Stage 2 previously inferred channel handling from the number of rows in
`sets.emg_channel_numbers`. A one-row value such as `[3 4]` was therefore
interpreted as two independent channels even when the researcher intended one
bipolar muscle. The same section also copied the first output-count entries of
`EMG.chanlocs`, rather than the metadata belonging to the selected channels,
and it did not check loaded channel bounds before indexing the dataset.

## Implemented CD-19 contract

- `sets.emg_reference_mode = 'single'` selects the configured source channels
  without subtraction. The channel-number setting may be a row or column
  vector. Selected source metadata is preserved, except that labels are
  replaced by the configured muscle names.
- `sets.emg_reference_mode = 'bipolar'` requires one two-column row per output
  muscle and calculates `first channel - second channel`. A one-row pair is a
  valid one-muscle configuration. Derived channel locations contain configured
  labels only and do not inherit either source electrode's spatial metadata.
- Stage 2 checks configured indices against `size(EMG.data, 1)` before changing
  `EMG`. Empty source `chanlocs` are supported. Nonempty but insufficient
  `chanlocs` cause a clear error before mutation.
- After successful handling, `EMG.data`, `EMG.nbchan`, `EMG.chanlocs`, and
  output labels describe the same channels, with sample and trial dimensions
  retained.
- The Stage 0 example remains a three-muscle bipolar configuration and now
  declares that mode explicitly.

No compatibility fallback was added for settings saved by older development
runs (CD-16). No index-uniqueness rule was added. Feature extraction, rejection,
trigger processing, output schemas, and source data are unchanged.

## Deterministic MATLAB R2024b checks

Run from the repository root:

```matlab
settings_results = runtests(fullfile('tests', 'test_validate_settings.m'));
assertSuccess(settings_results);

channel_results = runtests(fullfile('tests', 'test_channel_selection.m'));
assertSuccess(channel_results);
```

The focused channel suite evaluates the exact production text between Stage 2
Sections 2.4.3 and 2.4.4. It covers:

- single-mode row and column vectors;
- selected channel order and source metadata preservation;
- multi-muscle and one-muscle bipolar subtraction;
- explicit first-minus-second direction;
- channel count, labels, and time/trial dimensions;
- empty source channel locations;
- out-of-range data indices;
- insufficient nonempty channel locations;
- unchanged `EMG` after either data-dependent failure.

The validator suite covers missing or invalid modes, string rather than
character modes, invalid mode-specific shapes, name-count mismatches, valid
single-mode orientations, and valid one-muscle bipolar configuration.

Then run the Code Analyzer:

```matlab
checkcode('EMG_00_settings.m', '-id');
checkcode('validate_settings.m', '-id');
checkcode('EMG_02_preprocessing_feature_extraction.m', '-id');
checkcode(fullfile('tests', 'test_validate_settings.m'), '-id');
checkcode(fullfile('tests', 'test_channel_selection.m'), '-id');
```

Expected result: both test result arrays contain only passing tests. Review any
Code Analyzer messages; no new warning is expected from the changed code.

MATLAB and EEGLAB were unavailable in the implementation environment, so these
commands remain researcher-run acceptance checks.

The researcher reported on 2026-09-22 that both MATLAB R2024b suites passed and
that Stage 0 and Stage 2 completed on representative data with the expected
output. The only Code Analyzer message identified an obsolete suppression in
`test_validate_settings.m`; it was removed without executable changes in
`6cea1ed`. A targeted post-cleanup analyzer rerun remains to be confirmed.

## Representative EEGLAB acceptance

1. In Stage 0, keep the current three-row channel setting and
   `sets.emg_reference_mode = 'bipolar'`; run Stage 0 and confirm validation
   succeeds.
2. Run a representative participant through Stage 2 Section 2.4.3.
3. Confirm that `EMG.nbchan` is three, labels are `CS`, `OO`, and `ZM`, and each
   output trace is respectively channels `3-4`, `5-6`, and `7-8`.
4. Continue the participant through the existing Stage 2 workflow and confirm
   the expected preprocessed SET and feature CSV are produced.
5. If a recording with independent per-muscle channels is available, repeat
   with `sets.emg_reference_mode = 'single'` and a vector of source indices;
   verify the configured order and source metadata are retained.

## Assumptions and boundaries

- The stage-entry validator is responsible for mode, shape, integer-index, and
  name-count validation (CD-10). Section 2.4.3 adds only checks that depend on
  the loaded dataset.
- Channel indices remain MATLAB one-based indices. Their uniqueness is not a
  pipeline rule under the approved scope.
- A nonempty `EMG.chanlocs` array is expected to cover every selected source
  index. An empty array means spatial metadata are unavailable and is allowed.
- Bipolar channel locations intentionally contain labels only because neither
  source electrode location represents the derived differential signal.
- The production calculation remains inline and introduces no helper
  dependency.
