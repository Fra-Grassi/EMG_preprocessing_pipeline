# Event Representation and Condition Labels

This page explains the implemented contract for representing imported EEGLAB event types, matching condition triggers, creating condition-label events, and running Stage 2 sections safely.

## Conceptual rationale

An EEGLAB event is a MATLAB structure describing an occurrence in a dataset. Its `type` field contains the event code or name, while fields such as `latency`, `duration`, and `urevent` carry timing and provenance metadata.

CD-11 standardizes the MATLAB representation of `EEG.event.type` without standardizing away the experimenter's encoded content. Every supported event type becomes a MATLAB **character vector**—text written with single quotes—while prefixes, spacing, leading zeros, and textual names remain intact. Representation changes; experimental meaning does not.

The contract is exact:

| Input event type | Output event type |
| --- | --- |
| numeric `121` | character `'121'` |
| character `'121'` | character `'121'` |
| string `"121"` | character `'121'` |
| character `'S 121'` | character `'S 121'` |
| character `'S121'` | character `'S121'` |

For example, `'001'` remains `'001'`, and a textual event such as `'boundary'` remains `'boundary'`. The pipeline does not strip a prefix, normalize spaces, remove leading zeros, or map a text name to a number. It also adds no field containing the original value, because CD-11 explicitly chose not to add an original-value audit field.

This conversion is performed by [`fix_EEG_markers.m`](../fix_EEG_markers.m) during Stage 1 after BDF import. Numeric values use their character representation, MATLAB string values are converted to character vectors, and existing character content is left unchanged. Other event fields are not modified by this function.

## Configured condition triggers

Users enter `sets.condition_triggers` in Stage 0 as a cell array of character vectors. Each trigger must reproduce the experimenter-defined code exactly, including any prefix, space, or leading zero. The configured condition names occupy corresponding positions in `sets.condition_names`.

Stage 2 Section 2.4.2 compares each existing event type to each configured trigger with exact character comparison using `strcmp`. Thus `'121'`, `'S121'`, and `'S 121'` are three different values. The representation contract makes the comparison type consistent; it does not reinterpret these values as equivalent.

## Copying condition-label events

When an event type exactly matches a configured trigger, Stage 2 copies the complete matching event structure and appends the copy to the event list. It then replaces only the copied event's `type` with the corresponding condition name. The original trigger event remains present at this point.

Because the complete event is copied before its type is replaced, the condition-label event retains the source event's latency and other metadata fields. The code also explicitly assigns the same latency. EEGLAB's event-consistency check is then run on the expanded event list.

These copied condition events become the time-locking labels used for epoching. This page documents the implemented mapping mechanism only; it does not establish any new condition semantics or validate a new trigger list.

## Non-idempotent Stage 2 sections

CD-12 records the existing execution contract: Stage 2 sections are non-idempotent. **Non-idempotent** means that running a step a second time on the same in-memory dataset can change the result again rather than leaving it unchanged.

Section 2.4.2 intentionally has no duplicate-label guard. If it is rerun on the same in-memory event structure, matching source triggers can be copied again. Other Stage 2 transformations can likewise change data when repeated. This is not evidence that duplicate condition events should be accepted in a finished dataset; it means the user is responsible for executing each section once in sequence.

Every Stage 2 section emits a completion message after its work. A user running the pipeline section by section should use those messages as execution cues and run each section once. The project-root setup supports section execution, but it does not make repeated section execution safe.

## User-facing implications

- Configure trigger codes as character vectors and copy their encoded content exactly.
- Do not assume Brain Vision-style prefixes or spacing will be removed.
- Expect exact comparison: visually similar but textually different codes do not match.
- Treat copied condition events as full event copies whose `type` alone is replaced with the condition name.
- When running Stage 2 by sections, execute each section once and use the completion output to track progress.
- Do not treat trigger shifting as finalized. Its scientific and implementation contract is still pending and is deliberately outside this page.

## Traceability

- **Decisions:** [CD-11 and CD-12](../CONCEPTUAL_DECISIONS.md#event-representation-contract).
- **Production files and sections:** [`fix_EEG_markers.m`](../fix_EEG_markers.m); [`EMG_00_settings.m`, Conditions and Triggers](../EMG_00_settings.m); [`EMG_01_raw2set_shift_triggers.m`, Section 1.3.2](../EMG_01_raw2set_shift_triggers.m); [`EMG_02_preprocessing_feature_extraction.m`, Section 2.4.2](../EMG_02_preprocessing_feature_extraction.m).
- **Tests and recorded validation:** [`test_event_marker_normalization.m`](../tests/test_event_marker_normalization.m) verifies conversions, preserved encoded content, unchanged unrelated fields, and the completion message; [PROJECT_PLAN.md, Tier 1.1 and validation baseline](../PROJECT_PLAN.md#11-normalize-event-types-and-condition-matching) records isolated character-trigger checks and representative-participant integration validation.
- **Current implementation status:** CD-11 and CD-12 are implemented and validated. Trigger shifting has no approved decision ID and is not documented as settled.
