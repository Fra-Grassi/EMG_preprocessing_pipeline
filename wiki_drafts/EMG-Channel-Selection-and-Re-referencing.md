# EMG Channel Selection and Re-referencing

This page explains how Stage 0 channel settings define the muscle signals produced in Stage 2 Section 2.4.3. It describes the explicit `single` and `bipolar` contract approved in CD-19.

## Conceptual rationale

The same channel-number array can express different intentions. For example, `[3 4]` could mean two independent source channels or one pair whose difference represents a muscle. `sets.emg_reference_mode` makes that choice explicit, so Stage 2 does not infer it from the array's shape. A single pair is therefore a valid one-muscle bipolar configuration.

Channel re-referencing operates on recorded signals before filtering, rectification, and feature extraction. It is separate from the later muscle-wise or subject-pooled z scoring described in [MAV Processing and Standardization](MAV-Processing-and-Standardization.md). Choosing a channel reference mode does not choose a feature-standardization mode.

## User configuration in Stage 0

Configure these three settings together in the current `EMG_00_settings.m`:

| Setting | Meaning |
| --- | --- |
| `sets.emg_reference_mode` | Exactly `'single'` or `'bipolar'`, written as a MATLAB character vector with single quotes. |
| `sets.emg_channel_numbers` | Positive integer source-channel indices: a nonempty row or column vector in single mode, or a matrix with exactly two columns in bipolar mode. |
| `sets.emg_channel_names` | A nonempty row cell array of character vectors containing one muscle label per output channel, in the intended output order. |

Indices are MATLAB **one-based** positions in the loaded dataset: `1` means its first recorded channel. They are positions rather than channel labels. Check the loaded recording's channel order when adapting these examples; the example numbers do not identify electrodes for every recording.

### Single mode

Single mode selects one recorded source channel per output muscle without subtraction:

```matlab
sets.emg_reference_mode = 'single';
sets.emg_channel_numbers = [4 2];
sets.emg_channel_names = {'CS', 'OO'};
```

The first output is source channel 4 labeled `CS`; the second is source channel 2 labeled `OO`. A column vector `[4; 2]` gives the same output order. There must be one name for each selected index; one selected channel with one name is also valid.

### Bipolar mode

Each row defines one muscle as **first configured channel minus second configured channel**. The current Stage 0 example is:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4; 5 6; 7 8];
sets.emg_channel_names = {'CS', 'OO', 'ZM'};
```

The outputs, in order, are channel 3 minus channel 4 labeled `CS`, channel 5 minus channel 6 labeled `OO`, and channel 7 minus channel 8 labeled `ZM`. Each row needs one name. Reversing the two indices in a pair reverses that derived signal's sign at this step.

For one bipolar muscle, use one two-column row and one name:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4];
sets.emg_channel_names = {'ZM'};
```

This produces one signal, channel 3 minus channel 4, labeled `ZM`. A two-row column vector `[3; 4]` is not a bipolar pair because bipolar mode requires two columns.

### Configuration checks and current settings

The shared settings validator checks the mode, positive finite integer indices, mode-specific shape, and matching number of names in Stage 0 and at Stage 2 entry. It does not choose electrodes or infer the intended mode for the researcher.

Create and save settings with the current Stage 0 before running later stages. A saved development settings file missing `sets.emg_reference_mode` is not supported: the pipeline neither supplies a default mode nor falls back to interpreting the number of rows. Reconfigure and rerun Stage 0 rather than relying on an older settings file (CD-16).

## Output behavior and metadata

Single-mode output follows the configured vector order; bipolar output follows matrix row order. `sets.emg_channel_names` supplies labels in that same order. Stage 2 keeps the signal array (`EMG.data`), channel count (`EMG.nbchan`), and channel-location entries (`EMG.chanlocs`) consistent with those outputs while retaining sample and trial dimensions. Later feature columns use those muscle names and their configured order, as described in [Participant-Safe Feature Outputs](Participant-Safe-Feature-Outputs.md#wide-table-organization).

In single mode, each output retains the selected source channel's metadata, including any spatial information, while its label is replaced with the configured muscle name. This follows the selected source indices even when they are reordered or nonconsecutive.

In bipolar mode, each output is a derived differential signal. Its channel-location entry contains only the configured muscle label. It does not inherit either electrode's spatial location, because neither source location represents the derived signal. If source channel locations are entirely empty, both modes can still produce label-only entries.

## Checks against the loaded dataset

Stage 0 cannot determine which channels a subsequently loaded recording contains. Before selecting or subtracting signals, Stage 2 therefore checks that every configured index is within the loaded data's channel count. It also checks that a nonempty channel-location array covers every selected source index, in either mode. Entirely empty channel locations are allowed; incomplete nonempty locations cause an error.

Either failure stops this section before it changes the dataset. Check the source-channel order, channel count, metadata, and Stage 0 configuration before continuing. When running by sections, start with the stage entry section and run each section once in sequence; see [Project Structure and Paths](Project-Structure-and-Paths.md#complete-scripts-and-individual-sections).

## Validation evidence

The researcher reported that the settings-validator and focused channel-selection tests passed in MATLAB R2024b on 2026-09-22, together with a representative Stage 0/Stage 2 run producing the expected output. This is recorded evidence, not a new MATLAB run performed for this documentation update.

The focused tests execute the production channel-selection section with synthetic data. They check single-mode row and column vectors, configured order and source metadata, multi-muscle and one-muscle bipolar subtraction, first-minus-second direction, labels, channel count, sample/trial dimensions, empty locations, and failures for unavailable indices or insufficient nonempty locations before dataset changes. The settings tests separately cover mode, shape, and name-count validation.

## Limitations

The reported tests and representative run do not establish compatibility with other MATLAB versions or validate every recording layout. These examples explain the interface; they do not establish the scientific suitability of a channel or electrode pair for another dataset. Index uniqueness is not enforced by this contract. CD-19 does not change feature calculations, rejection rules, or the output schema.

## Traceability

- **Decisions:** [CD-19](../CONCEPTUAL_DECISIONS.md#emg-channel-selection-and-re-referencing-cd-19) defines channel handling; [CD-16](../CONCEPTUAL_DECISIONS.md#current-settings-contract-cd-16) requires current settings; [CD-10](../CONCEPTUAL_DECISIONS.md#decision-register) defines entry-point validation.
- **Production files and sections:** [`EMG_00_settings.m`, EMG channels](../EMG_00_settings.m); [`validate_settings.m`, channel rules](../validate_settings.m); [`EMG_02_preprocessing_feature_extraction.m`, Section 2.4.3](../EMG_02_preprocessing_feature_extraction.m).
- **Tests and recorded validation:** [`test_channel_selection.m`](../tests/test_channel_selection.m), [`test_validate_settings.m`](../tests/test_validate_settings.m), the [channel-selection handoff](../tests/channel_selection_handoff.md), and [PROJECT_PLAN.md, validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Current implementation status:** CD-19 is implemented, with researcher-reported MATLAB R2024b validation on 2026-09-22.
