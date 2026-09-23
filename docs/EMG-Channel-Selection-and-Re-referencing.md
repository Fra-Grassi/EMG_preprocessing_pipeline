# EMG Channel Selection and Re-referencing

This page explains how Stage 0 channel settings define the muscle signals produced in Stage 2.

## Why the reference mode is explicit

The same channel-number array can express different intentions. For example, `[3 4]` could mean two independent recorded channels or one pair whose difference represents a muscle. The setting `sets.emg_reference_mode` makes that choice explicit instead of asking Stage 2 to infer it from the array shape.

Channel selection and bipolar subtraction occur before filtering, rectification, and feature extraction. This operation is separate from later muscle-wise or subject-pooled feature standardization; choosing a channel reference mode does not choose a standardization mode.

## Configuration in Stage 0

Configure these three settings together:

| Setting | Meaning |
| --- | --- |
| `sets.emg_reference_mode` | Exactly `'single'` or `'bipolar'`. |
| `sets.emg_channel_numbers` | Positive integer source-channel indices: a row or column vector in single mode, or a matrix with exactly two columns in bipolar mode. |
| `sets.emg_channel_names` | One muscle label per output channel, in the intended output order. |

Channel indices are MATLAB **one-based positions** in the loaded dataset: `1` means the first recorded channel. They are positions, not channel labels. Confirm the channel order in each recording before adapting the examples below.

### Single mode

Single mode selects one recorded source channel per output muscle without subtraction:

```matlab
sets.emg_reference_mode = 'single';
sets.emg_channel_numbers = [4 2];
sets.emg_channel_names = {'CS', 'OO'};
```

The first output is source channel 4 labeled `CS`; the second is source channel 2 labeled `OO`. A column vector such as `[4; 2]` gives the same output order. One selected channel with one name is valid.

### Bipolar mode

In bipolar mode, each row defines one muscle as **first configured channel minus second configured channel**:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4; 5 6; 7 8];
sets.emg_channel_names = {'CS', 'OO', 'ZM'};
```

The outputs are channel 3 minus 4 labeled `CS`, channel 5 minus 6 labeled `OO`, and channel 7 minus 8 labeled `ZM`. Reversing the indices reverses the derived signal's sign at this step.

A one-muscle bipolar configuration uses one two-column row and one name:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4];
sets.emg_channel_names = {'ZM'};
```

A column vector `[3; 4]` is not a bipolar pair because bipolar mode requires two columns.

## Validation before processing

The settings validator checks:

- that the mode is `'single'` or `'bipolar'`;
- that all indices are positive finite integers;
- that the channel-number array has the required shape for the mode;
- that the number of muscle names matches the number of output channels.

Stage 2 then performs checks that require the loaded dataset. Every configured index must exist in `EMG.data`. If channel-location metadata are present, they must cover every selected source index. Entirely absent channel locations are allowed; incomplete nonempty metadata cause an error before the dataset is changed.

The validator does not select electrodes, infer the intended reference mode, or assess whether a channel pair is scientifically appropriate. Those choices remain the researcher's responsibility.

Settings saved before the explicit reference-mode field was introduced are not supported. Reconfigure and rerun the current Stage 0 rather than relying on an older settings file.

## Output order and channel metadata

Single-mode output follows the configured vector order. Bipolar output follows matrix row order. `sets.emg_channel_names` supplies labels in the same order, and later feature columns use those names.

In single mode, each output retains the selected source channel's metadata, including spatial information when present, while its label is replaced with the configured muscle name.

In bipolar mode, each output is a derived differential signal. Its channel-location entry contains the configured muscle label but does not inherit either source electrode's spatial location, because neither source location alone represents the derived signal.

Stage 2 keeps the signal array, channel count, channel-location entries, and output labels consistent while preserving the sample and trial dimensions.

## Validation scope and limitations

The channel-selection behavior is covered by deterministic MATLAB R2024b tests and representative Stage 0/Stage 2 runs. The tests include reordered and nonconsecutive single channels, multi-muscle and one-muscle bipolar subtraction, first-minus-second direction, empty or insufficient channel metadata, and out-of-range indices.

This validation does not establish compatibility with every recording layout or prove that an electrode choice is suitable for a new study. Duplicate source indices are not rejected automatically.

Related output organization is described in [Participant-Safe Feature Outputs](Participant-Safe-Feature-Outputs.md#wide-table-organization), and later feature standardization is described in [MAV Processing and Standardization](MAV-Processing-and-Standardization.md).
