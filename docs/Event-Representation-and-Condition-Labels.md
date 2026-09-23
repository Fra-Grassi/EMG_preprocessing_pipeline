# Event Representation and Condition Labels

This page explains how imported EEGLAB event types are represented, how condition triggers are matched, how condition-label events are created, and why Stage 2 sections must be run once.

## Event representation

An EEGLAB event is a MATLAB structure describing an occurrence in a dataset. Its `type` field contains the event code or name, while fields such as `latency`, `duration`, and `urevent` carry timing and provenance information.

The pipeline converts supported event types to MATLAB **character vectors**—text written with single quotes—without changing the experimenter's encoded content:

| Input event type | Output event type |
| --- | --- |
| numeric `121` | character `'121'` |
| character `'121'` | character `'121'` |
| string `"121"` | character `'121'` |
| character `'S 121'` | character `'S 121'` |
| character `'S121'` | character `'S121'` |

Prefixes, spacing, leading zeros, and textual names are preserved. For example, `'001'` remains `'001'`, and `'boundary'` remains `'boundary'`. The pipeline does not treat `'121'`, `'S121'`, and `'S 121'` as equivalent.

The conversion changes MATLAB representation only. It does not reinterpret the event's experimental meaning and does not add an original-value audit field.

Stage 1 performs this conversion with [fix_EEG_markers.m](../fix_EEG_markers.m) after BIOSIG imports the BDF data and events. Other event fields are not modified by this function.

## Configured condition triggers

Users enter `sets.condition_triggers` in Stage 0 as a cell array of character vectors. Each entry must reproduce the experimenter-defined event code exactly, including any prefix, space, or leading zero. Entries in `sets.condition_names` correspond by position.

Stage 2 compares event types with configured triggers using exact character comparison. A visually similar but textually different event does not match.

This makes trigger representation consistent without imposing a new event-coding scheme. Researchers remain responsible for confirming that the configured codes correspond to the intended experimental events.

## Condition-label events

When an event type exactly matches a configured trigger, Stage 2 copies the complete event structure and appends the copy to the event list. It replaces only the copied event's `type` with the corresponding condition name. The original trigger event remains present at this point.

Because the complete event is copied first, the condition-label event retains the source latency and other metadata. EEGLAB's event-consistency check is then applied to the expanded event list.

The copied condition events become the time-locking labels used for epoching. This mechanism preserves metadata; it does not independently verify the scientific meaning or completeness of the configured trigger list.

## Why sections must be run once

Stage 2 processing sections are non-idempotent: running a section again on the same in-memory dataset can change the result a second time.

Condition-label creation intentionally has no duplicate guard. If that section is repeated, matching source triggers can be copied again. Other sections can likewise repeat filtering, baseline correction, rejection, or table construction.

When running Stage 2 by sections:

- begin with the stage setup section;
- run each section once and in order;
- use the completion messages to track execution;
- restart from a clean stage state if it is unclear which sections have already run.

## Practical implications

- Configure trigger codes as exact character vectors.
- Do not assume Brain Vision-style prefixes or spacing will be normalized away.
- Confirm the imported event values before processing a new study.
- Treat condition labels as copied source events whose `type` alone is replaced.
- Use the same exact character codes when configuring [trigger shifting](Trigger-Shifting-and-Diagnostics.md).
- Never repeat Stage 2 processing sections on the same in-memory dataset unless the stage has been deliberately restarted.

The event conversion and condition-copying behavior are covered by deterministic MATLAB tests, including numeric, character, string, Brain Vision-style, leading-zero, and textual event values.
