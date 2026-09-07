# EMG Preprocessing Pipeline Knowledge Base

This draft knowledge base explains the conceptual and engineering choices that are already approved and validated in the EMG preprocessing pipeline. It is written for researchers who understand EMG analysis but do not necessarily know the internal MATLAB and EEGLAB implementation.

These pages are explanatory derivatives, not project specifications. The authoritative sources are [CONCEPTUAL_DECISIONS.md](../CONCEPTUAL_DECISIONS.md) for approved behavior, [PROJECT_PLAN.md](../PROJECT_PLAN.md) for implementation status and future work, and the production MATLAB code and tests for evidence of actual behavior.

## What this knowledge base is—and is not

The pages describe why established behavior exists, how it is represented in the implementation, and what that behavior means for users and downstream analysis. They are not instructions for installing software, configuring a new study, or running the pipeline from beginning to end. A future user guide or README will cover those operational tasks.

Planned or unresolved behavior is not presented here as finalized. In particular, CD-10 describes a future settings validator and is not implemented. Trigger shifting has no approved conceptual decision yet, so a definitive trigger-shifting page is intentionally absent. The current Stage 1 script can invoke existing trigger-shifting code, but its scientific and engineering contract remains pending.

## Draft pages

- [Project Structure and Paths](Project-Structure-and-Paths.md) explains Stage 0, project-root discovery, internal and external paths, directory creation, and MATLAB script-versus-section execution.
- [Participant-Safe Feature Outputs](Participant-Safe-Feature-Outputs.md) explains participant identity, row keys, rejected-trial reconstruction, cumulative checkpoints, missing values, and the wide feature table.
- [MAV Processing and Standardization](MAV-Processing-and-Standardization.md) explains the validated mean-absolute-value workflow, binning, standardization reference populations, averaging order, and output columns.
- [Event Representation and Condition Labels](Event-Representation-and-Condition-Labels.md) explains character-based event types, exact trigger comparison, copied condition events, and the non-idempotent Stage 2 section contract.

## Pipeline at a glance

The repository is organized around three MATLAB stages:

1. **Stage 0—configuration.** [`EMG_00_settings.m`](../EMG_00_settings.m) defines preprocessing settings, resolves project-internal directories, checks known incompatible setting combinations, and saves both a MATLAB settings structure and a readable text snapshot in `resources/`.
2. **Stage 1—acquisition import.** [`EMG_01_raw2set_shift_triggers.m`](../EMG_01_raw2set_shift_triggers.m) imports selected BDF acquisition files into EEGLAB's SET dataset format, converts event types to character vectors without rewriting their encoded content, can invoke the existing optional trigger-shifting step, attaches participant metadata, and saves one raw SET dataset per participant.
3. **Stage 2—preprocessing and feature output.** [`EMG_02_preprocessing_feature_extraction.m`](../EMG_02_preprocessing_feature_extraction.m) selects EMG channels, performs configured signal processing and epoching, flags and removes rejected trials for feature estimation, calculates MAV-derived features, standardizes them when requested, optionally averages retained trials by condition, and writes participant-safe cumulative output.

An **EEGLAB SET dataset** is MATLAB data stored in EEGLAB's dataset structure and normally saved as a `.set` file. A **MATLAB section** is a separately runnable block beginning with `%%`; running sections provides flexibility but does not make repeated execution safe.

## Traceability

- **Decisions:** [CD-01 through CD-09 and CD-11 through CD-12](../CONCEPTUAL_DECISIONS.md#decision-register) are represented as implemented behavior. CD-10 is identified only as an approved future direction.
- **Production files:** [`EMG_00_settings.m`](../EMG_00_settings.m), [`EMG_01_raw2set_shift_triggers.m`](../EMG_01_raw2set_shift_triggers.m), [`EMG_02_preprocessing_feature_extraction.m`](../EMG_02_preprocessing_feature_extraction.m), and [`fix_EEG_markers.m`](../fix_EEG_markers.m).
- **Tests and validation:** [deterministic MAV tests](../tests/run_mav_tests.m), [event-marker normalization tests](../tests/test_event_marker_normalization.m), and the recorded [validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Current status:** The documented decisions are implemented and recorded as validated. Settings validation (CD-10) and trigger-shifting decisions remain future or unresolved work.
