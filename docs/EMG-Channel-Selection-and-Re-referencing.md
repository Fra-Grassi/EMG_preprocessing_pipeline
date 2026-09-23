# EMG Channel Selection and Re-referencing

Before processing the EMG, you need to tell the pipeline which recorded channels belong to each muscle. You can keep individual channels as recorded, or calculate a bipolar signal by subtracting one electrode channel from another. This happens at the start of Stage 2, before filtering and rectification.

## Why the reference mode is explicit

A list such as `[3 4]` is ambiguous on its own: it could mean “keep channels 3 and 4” or “subtract channel 4 from channel 3.” The setting `sets.emg_reference_mode` tells the pipeline which operation you intend. This also lets you process just one bipolar muscle without it being mistaken for two separate channels.

Re-referencing concerns the recorded waveforms. Later [feature standardization](MAV-Processing-and-Standardization.md) concerns the MAV values extracted from those waveforms. You choose these two steps separately.

## Configuration in Stage 0

The three channel settings work together:

| Setting | What to enter |
| --- | --- |
| `sets.emg_reference_mode` | `'single'` to keep individual channels, or `'bipolar'` to subtract pairs. Use single quotes. |
| `sets.emg_channel_numbers` | The positions of the channels in your recording, arranged as in the examples below. |
| `sets.emg_channel_names` | A muscle name for each resulting signal, in the same order. Use braces and single quotes as shown below. |

MATLAB counts channels from **1**: channel 1 is the first channel in the loaded recording. These numbers refer to positions in the dataset, not necessarily the numbers printed on your electrodes or used in their labels. Check the recording's channel order before copying the examples.

### Keeping individual channels

Use `'single'` when you want to select recorded channels without subtracting them:

```matlab
sets.emg_reference_mode = 'single';
sets.emg_channel_numbers = [4 2];
sets.emg_channel_names = {'CS', 'OO'};
```

Here, the first output signal is channel 4, named `CS`, and the second is channel 2, named `OO`. The pipeline follows your order rather than sorting the channel numbers. You can also write the numbers vertically, as `[4; 2]`, with the same result. To keep just one channel, enter one number and one name.

### Calculating bipolar signals

Use `'bipolar'` to define a pair of channels for each muscle. Each row gives **the first channel minus the second channel**:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4; 5 6; 7 8];
sets.emg_channel_names = {'CS', 'OO', 'ZM'};
```

The semicolons separate rows. This example produces three signals: channel 3 minus channel 4 (`CS`), channel 5 minus channel 6 (`OO`), and channel 7 minus channel 8 (`ZM`). Reversing a pair reverses the sign of its signal at this step.

For **one bipolar muscle**, use one pair and one name:

```matlab
sets.emg_reference_mode = 'bipolar';
sets.emg_channel_numbers = [3 4];
sets.emg_channel_names = {'ZM'};
```

This gives channel 3 minus channel 4, named `ZM`. Keep both numbers on the same row: `[3; 4]` would make two rows with one number each, which is not a valid bipolar configuration.

## Checks before processing

Stage 0 checks that you have entered a recognised mode, positive whole-number channel positions, the right arrangement of numbers, and one name per resulting muscle signal. After changing these settings, run Stage 0 again to save them. Settings from older development versions are not filled in automatically; use the current Stage 0 script.

Stage 2 also checks the recording itself. For example, requesting channel 8 from a dataset with only six channels stops processing with an error. If channel-location information is present, it must include all selected channels. An entirely empty set of locations is allowed, but a partially populated one that does not reach the requested channels causes an error. Both checks happen before channel selection changes the dataset.

These checks cannot tell whether you have chosen the correct electrodes for your muscle. Repeated channel numbers are also allowed, so check your entries for accidental duplication.

## Output order and channel metadata

The order of your selected channels, or of your bipolar pairs, becomes the order of the muscle signals. The names in `sets.emg_channel_names` label those signals and are later used in the feature table.

For an individual channel, the pipeline keeps the information associated with that source channel, including its location when available, and replaces its label with your muscle name. For a bipolar signal, it stores the muscle label only. A difference between two electrodes cannot be assigned either electrode's location as though it were a recording from that point. If the source has no channel locations, single-mode outputs also receive labels only.

Channel selection leaves the number of samples and trials unchanged. Automated tests and a representative Stage 0/Stage 2 run passed in MATLAB R2024b on 2026-09-22, including tests of single channels, one- and multiple-muscle bipolar configurations, subtraction direction, and channel information. Other MATLAB versions and recording layouts have not all been tested.

For the resulting table layout, see [Feature Tables and Rejected Trials](Participant-Safe-Feature-Outputs.md#wide-table-organization).
