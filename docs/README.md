# Understanding the EMG Preprocessing Pipeline

These pages are for colleagues who want to understand how the pipeline processes EMG recordings and what the resulting values mean. For installation and instructions on running the three stages, start with the [main README](../README.md).

The pipeline takes continuous recordings, extracts epochs around your events of interest, and summarises muscle activity in time bins using mean absolute value (MAV). Along the way, you choose how to reference the channels, correct event timing, reject trials, correct for baseline activity, and standardize the extracted values. Those choices affect the interpretation of the final table. The settings supplied with the pipeline are examples; you will need to adapt them to your recordings and research question.

## Where to start

The pages roughly follow the order in which you will encounter these choices:

- [Project Structure and Paths](Project-Structure-and-Paths.md): where to put your files, how settings are saved, and how to run the MATLAB scripts a section at a time.
- [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md): selecting a recorded muscle channel or calculating the difference between two electrodes.
- [Event Codes and Condition Labels](Event-Representation-and-Condition-Labels.md): matching the event codes in your recording to your experimental conditions.
- [Trigger Shifting and Diagnostics](Trigger-Shifting-and-Diagnostics.md): correcting delays between event markers and measured stimulus onset, and checking the photodiode results.
- [MAV Processing and Standardization](MAV-Processing-and-Standardization.md): how rectification, baseline correction, binning, and z scoring determine the meaning of your EMG measures.
- [Feature Tables and Rejected Trials](Participant-Safe-Feature-Outputs.md): reading the output columns, identifying trials, and interpreting missing values.

## How the stages fit together

**Stage 0** saves your settings. **Stage 1** imports the BDF recordings, optionally corrects event timing, and saves one EEGLAB dataset per participant. **Stage 2** processes those datasets and extracts the EMG measures. An EEGLAB dataset is normally saved as a `.set` file; the final feature table is a CSV file that you can take into your statistical software.

The pipeline has been tested in MATLAB R2024b. For v0.1.0, all 94 automated tests passed, alongside representative runs on recordings. Some tests use simplified replacements for EEGLAB functions to check individual calculations. These checks help establish that the processing behaves as described, but they do not cover every recording setup or software version. When applying the pipeline to a new study, inspect the signals, trial counts, and output distributions as you would with any preprocessing workflow.
