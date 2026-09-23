# EMG Preprocessing Pipeline: Conceptual Documentation

These pages explain the scientific and technical behavior of the EMG Preprocessing Pipeline for researchers who want to understand what the pipeline does and how to interpret its outputs. They complement the operational instructions in the project [`README.md`](../README.md).

The documentation focuses on implemented behavior. It does not prescribe settings for a new study: channel choices, timing parameters, artifact-rejection thresholds, and other scientific settings remain the researcher's responsibility.

## Topics

- [Project Structure and Paths](Project-Structure-and-Paths.md) explains configuration, project and external paths, output directories, file selection, and MATLAB script-versus-section execution.
- [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md) explains single-channel and bipolar modes, source-channel ordering, output labels, and channel metadata.
- [Event Representation and Condition Labels](Event-Representation-and-Condition-Labels.md) explains exact event-code preservation, condition matching, copied condition events, and safe section execution.
- [Trigger Shifting and Diagnostics](Trigger-Shifting-and-Diagnostics.md) explains fixed, trial-specific, and participant-median latency correction, photodiode detection, fallback behavior, and diagnostic interpretation.
- [MAV Processing and Standardization](MAV-Processing-and-Standardization.md) explains rectification, waveform baseline correction, binning, standardization reference populations, optional averaging, and feature naming.
- [Participant-Safe Feature Outputs](Participant-Safe-Feature-Outputs.md) explains participant identity, row keys, rejected-trial representation, cumulative checkpoints, missing values, and the wide feature table.

## Pipeline overview

The repository contains three MATLAB stages:

1. **Stage 0 — configuration.** [`EMG_00_settings.m`](../EMG_00_settings.m) defines the processing configuration, resolves project directories, validates the settings, and saves both a MATLAB settings structure and a readable text snapshot in `resources/`.
2. **Stage 1 — acquisition import.** [`EMG_01_raw2set_shift_triggers.m`](../EMG_01_raw2set_shift_triggers.m) imports selected BDF recordings through BIOSIG, preserves event codes as character text, optionally corrects trigger latencies, records the filename stem as the participant ID, and saves one raw EEGLAB SET dataset per participant.
3. **Stage 2 — preprocessing and feature extraction.** [`EMG_02_preprocessing_feature_extraction.m`](../EMG_02_preprocessing_feature_extraction.m) selects or derives muscle channels, performs the configured signal processing and epoching, identifies rejected trials, calculates MAV-derived features, optionally standardizes and averages them, and writes cumulative rejection and feature outputs.

An **EEGLAB SET dataset** is electrophysiological data stored in EEGLAB's dataset structure and normally saved as a `.set` file. A **MATLAB section** is a separately runnable block beginning with `%%`; sections can be useful for inspection, but processing sections must be run once and in order.

The v0.1.0 release was validated with the complete MATLAB R2024b test suite (94/94 tests passing) and representative pipeline runs. This does not establish compatibility with every MATLAB, EEGLAB, or plugin version, recording layout, or dataset.
