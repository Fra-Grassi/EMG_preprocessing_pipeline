# EMG Preprocessing Pipeline Knowledge Base

This draft knowledge base explains the conceptual and engineering choices that are already approved and validated in the EMG preprocessing pipeline. It is written for researchers who understand EMG analysis but do not necessarily know the internal MATLAB and EEGLAB implementation.

These pages are explanatory derivatives, not project specifications. The authoritative sources are [CONCEPTUAL_DECISIONS.md](../CONCEPTUAL_DECISIONS.md) for approved behavior, [PROJECT_PLAN.md](../PROJECT_PLAN.md) for implementation status and future work, and the production MATLAB code and tests for evidence of actual behavior.

## What this knowledge base is—and is not

The pages describe why established behavior exists, how it is represented in the implementation, and what that behavior means for users and downstream analysis. They are not instructions for installing software, configuring a new study, or running the pipeline from beginning to end. See the project [`README.md`](../README.md) for those operational tasks.

Planned or unresolved behavior is not presented here as finalized. The shared settings validator (CD-10), file-selection and participant-identity behavior (CD-17), rejection-accounting checkpoints (CD-18), and explicit EMG channel-selection contract (CD-19) are implemented, with researcher-reported validation recorded in the plan. Trigger shifting is documented because CD-13 through CD-16 define its approved and integrated behavior; the validation evidence and its limits are stated explicitly on that page. The case in which every configured condition has zero trials remains unresolved beyond CD-18's rule for an individually absent condition.

## Draft pages

- [Project Structure and Paths](Project-Structure-and-Paths.md) explains Stage 0, project-root discovery, internal and external paths, directory creation, and MATLAB script-versus-section execution.
- [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md) explains explicit single and bipolar modes, Stage 0 examples including one-muscle bipolar, output order, source metadata, loaded-dataset checks, and validation limits.
- [Participant-Safe Feature Outputs](Participant-Safe-Feature-Outputs.md) explains participant identity, row keys, rejected-trial reconstruction, the distinct rejection-statistics and feature checkpoints, missing values, and the wide feature table.
- [MAV Processing and Standardization](MAV-Processing-and-Standardization.md) explains the validated mean-absolute-value workflow, binning, standardization reference populations, averaging order, and output columns.
- [Event Representation and Condition Labels](Event-Representation-and-Condition-Labels.md) explains character-based event types, exact trigger comparison, copied condition events, and the non-idempotent Stage 2 section contract.
- [Trigger Shifting and Diagnostics](Trigger-Shifting-and-Diagnostics.md) explains fixed, trial-specific, and participant-median latency correction; photodiode detection; fallback behavior; diagnostics; and validation evidence.

## Pipeline at a glance

The repository is organized around three MATLAB stages:

1. **Stage 0—configuration.** [`EMG_00_settings.m`](../EMG_00_settings.m) defines preprocessing settings, resolves project-internal directories, validates the complete configuration through the shared settings validator, and saves both a MATLAB settings structure and a readable text snapshot in `resources/`.
2. **Stage 1—acquisition import.** [`EMG_01_raw2set_shift_triggers.m`](../EMG_01_raw2set_shift_triggers.m) imports selected BDF acquisition files and events through the BIOSIG plugin, converts event types to character vectors without rewriting their encoded content, optionally applies the approved trigger-shifting workflow, records the raw filename stem as a text participant ID, and saves one raw SET dataset per participant. When shifting is enabled, it also saves a separate diagnostics file; photodiode-mode figures remain open for inspection.
3. **Stage 2—preprocessing and feature output.** [`EMG_02_preprocessing_feature_extraction.m`](../EMG_02_preprocessing_feature_extraction.m) loads the selected SET datasets and their saved participant IDs, selects source EMG channels in single mode or derives first-minus-second signals in bipolar mode, performs configured signal processing and epoching, flags and removes rejected trials for feature estimation, calculates MAV-derived features, standardizes them when requested, optionally averages retained trials by condition, and writes separate cumulative rejection-statistics and feature checkpoints at their respective completion points.

An **EEGLAB SET dataset** is MATLAB data stored in EEGLAB's dataset structure and normally saved as a `.set` file. A **MATLAB section** is a separately runnable block beginning with `%%`; running sections provides flexibility but does not make repeated execution safe.

## Traceability

- **Decisions:** [CD-01 through CD-19](../CONCEPTUAL_DECISIONS.md#decision-register) are represented as implemented or integrated behavior, subject to the validation limits stated on the individual pages.
- **Production files:** [`EMG_00_settings.m`](../EMG_00_settings.m), [`EMG_01_raw2set_shift_triggers.m`](../EMG_01_raw2set_shift_triggers.m), [`shift_triggers.m`](../shift_triggers.m), [`EMG_02_preprocessing_feature_extraction.m`](../EMG_02_preprocessing_feature_extraction.m), and [`fix_EEG_markers.m`](../fix_EEG_markers.m).
- **Tests and validation:** [deterministic MAV tests](../tests/run_mav_tests.m), [event-marker normalization tests](../tests/test_event_marker_normalization.m), [condition-label tests](../tests/test_condition_label_creation.m), [Stage 1 trigger-shift integration tests](../tests/test_stage1_trigger_shift_integration.m), [file-selection and identity tests](../tests/test_file_selection_identity.m), [rejection-accounting tests](../tests/test_rejection_accounting.m), [production trigger-shifting tests](../tests/test_shift_triggers_production.m), [settings-validator tests](../tests/test_validate_settings.m), [channel-selection tests](../tests/test_channel_selection.m), and the recorded [validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Current status:** Tier 1 implementation tasks and Tier 2.1 channel selection are marked complete in `PROJECT_PLAN.md`; the researcher-reported checks and their limits are recorded there. The researcher reported the channel-selection and settings-validator tests and a representative Stage 0/Stage 2 run passing in MATLAB R2024b on 2026-09-22. CD-10 validates settings at each stage entry. Automatic-rejection thresholds remain choices for the researcher to make for each dataset, not a pending pipeline-wide implementation decision.
