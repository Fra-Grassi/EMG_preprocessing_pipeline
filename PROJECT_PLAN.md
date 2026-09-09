# EMG Preprocessing Pipeline: Coordination Plan

Last updated: 2026-09-09
Latest researcher-tested state: `be6537d` plus the working-tree Stage 1 BIOSIG import and persistent-diagnostics edits; representative BDF run passed, reported on 2026-09-09.

## Purpose

This is the shared implementation plan for the project. Agent 0 maintains it as the source of truth across threads, branches, and worktrees. Every agent should read this file and `CONCEPTUAL_DECISIONS.md` before proposing or implementing changes.

The current development goal remains refinement of the existing pipeline. New analytical features are out of scope unless the researcher explicitly adds them to this plan.

## Coordination protocol

- Agent 0 coordinates task boundaries, scientific decisions, integration order, and updates to this plan.
- Worker agents receive one bounded task and should use a dedicated `codex/<task-name>` branch/worktree unless Agent 0 specifies otherwise.
- Agents must not silently change preprocessing assumptions, rejection rules, output schemas, or missing-data behavior.
- Raw BDF, SET, and FDT files must never be edited or committed.
- Each handoff must report changed files, tests performed, warnings, assumptions, and unresolved questions.
- Work that touches the same MATLAB script should normally be sequenced rather than developed concurrently.
- A task is marked complete here only after review and proportionate validation. MATLAB-dependent work requires confirmation from a MATLAB installation.
- Agent 0 is responsible for integrating approved work into `main` and recording any resulting conceptual decision in `CONCEPTUAL_DECISIONS.md`.

## Status notation

- `[x]` completed and validated;
- `[ ]` not started;
- `[~]` in progress;
- `[!]` blocked by a scientific decision or external validation.

## Tier 0: completed critical corrections

These items define the current protected baseline. Later work must not regress them.

### 0.1 Remove the obsolete dyad data model

- [x] Renamed Stage 1 to `EMG_01_raw2set_shift_triggers.m`.
- [x] Removed dyad-specific settings, saving logic, and comments.
- [x] Established one raw-SET output directory and one participant-level processing path.

### 0.2 Repair Stage 1 execution errors

- [x] Replaced references to nonexistent settings fields with the fields defined in Stage 0.
- [x] Corrected the identified Stage 1 syntax errors.
- [x] Standardized the participant identifier variable as `subj_ID` within the scripts.

### 0.3 Repair Stage 2 settings and bin bookkeeping

- [x] Replaced the unscoped `epoch_length` reference with `sets.epoch_length`.
- [x] Replaced the obsolete settings-based bin-count field with the calculated `n_bins` value.
- [x] Moved known incompatible-toggle checks into a dedicated Stage 0 section.
- [x] Enabled the selected automatic artifact-rejection configuration; its thresholds remain a separate scientific decision.

### 0.4 Establish reproducible project paths

- [x] Defined project-internal paths from one inferred `sets.project_dir` using `fullfile`.
- [x] Kept `sets.rawBDF_dir` and `sets.eeglab_dir` as external, user-configured paths.
- [x] Create `raw`, `preprocessed`, and `extracted_amplitudes` only when absent; rerunning Stage 0 does not delete their contents.
- [x] Require the tracked `resources` directory to exist rather than recreating it silently.
- [x] Use `matlab.desktop.editor.getActiveFilename` in Stages 0–2 so full-script and section execution resolve the same project root in supported MATLAB releases.
- [x] Ignore generated electrophysiology data, outputs, and machine-specific settings artifacts in Git.

### 0.5 Make feature aggregation participant-safe

- [x] Use string `subject_ID` and `condition` values and the composite key `subject_ID + condition + trial_number + bin`.
- [x] Build and join the rejected-trial skeleton separately for the current participant.
- [x] Preserve rejected trials as rows with missing feature values when requested.
- [x] Accumulate only participants that have completed preprocessing and table construction.
- [x] Rewrite the cumulative feature CSV inside the participant loop, preserving a checkpoint for earlier completed participants if a later participant fails before saving.
- [x] Sort cumulative output by participant, configured condition order, trial, and bin.
- [x] Keep validation lightweight for now; broader duplicate-input and settings checks belong to Tier 1.

### 0.6 Correct and validate MAV processing

- [x] Enforce full-wave rectification for MAV.
- [x] Apply trial-wise waveform baseline correction before feature extraction.
- [x] Extract non-overlapping binned means without applying `abs` a second time.
- [x] Define standardization from retained post-stimulus observations and apply it to all bins.
- [x] Make muscle-wise and subject-pooled standardization mutually exclusive.
- [x] Standardize before optional condition-level trial averaging.
- [x] Save method-specific unstandardized columns and adjacent standardized columns.
- [x] Restore rejected rows with missing values in every MAV-derived column.
- [x] Validate deterministic calculations in MATLAB R2024b.
- [x] Validate helper-backed Stage 2 output, full-script versus section execution, and final inline equivalence.
- [x] Keep Stage 2 self-contained; retain the validated helper implementations only under `tests/helpers`.

## Tier 1: next correctness and reproducibility work

These are the recommended next tasks. They refine existing behavior rather than add analytical features.

### 1.1 Normalize event types and condition matching

- [x] Define the event representation contract in CD-11.
- [x] Convert every event type to a MATLAB character vector without altering its encoded content: numeric values use their character representation, strings convert to characters, and existing character values remain unchanged.
- [x] Remove the current Brain Vision prefix/spacing conversion and the original-value audit field logic.
- [x] Require condition triggers in Stage 0 to be entered as character vectors and explain that event types are converted to characters for EEGLAB compatibility.
- [x] Replace Stage 2's mixed numeric/character comparison with `strcmp` while preserving the existing condition-event copying logic.
- [x] Add focused deterministic tests for numeric, character, string, Brain Vision-style, and textual marker conversion.
- [x] Retain the general Stage 2 section-execution contract: each section is run once, so Section 2.4.2 receives no special duplicate-execution guard (CD-12).

Likely files: `fix_EEG_markers.m`, Stage 1, Stage 2, new tests.
Dependency note: complete before a broad trigger-shifting refactor.

### 1.2 Correct and test trigger shifting

- [x] Audit photodiode onset detection and validate the test-only reference (T1.2-A).
- [x] Audit fixed-delay and trial-specific latency application and validate the test-only reference (T1.2-B).
- [x] Fix trial-delay indexing so each matching event receives its own delay rather than repeatedly selecting the first delay.
- [x] Handle a missing photodiode channel, missing zero sample, and trials with no threshold crossing explicitly.
- [x] Confirm the sign and rounding convention used to convert milliseconds to samples (CD-13: add signed offsets using `round`).
- [x] Document EEGLAB/CleanLine dependencies and remove the `bwareafilt` dependency; representative real-data runs passed.
- [x] Preserve an auditable before/after latency record or equivalent validation output before trusting variable-delay mode.

Likely files: `shift_triggers.m`, Stage 0 settings comments/checks, Stage 1, new tests.
Scientific decision: the intended photodiode threshold and minimum-duration rule must remain researcher-controlled.

### 1.3 Add one reusable settings validator

- [ ] Validate required fields, value types, allowed strings, toggle dependencies, and vector dimensions.
- [ ] Validate condition trigger/name cardinality and EMG channel-number/name cardinality.
- [ ] Validate epoch, baseline, bin, filter, downsampling, and Nyquist relationships without changing their scientific values.
- [ ] Validate required input/resource/toolbox paths while creating only designated output directories.
- [ ] Run the validator from every stage so section-level execution does not depend on Stage 0 having just run successfully.
- [ ] Keep errors concise and actionable; avoid redundant checks inside participant loops.

Likely files: a new validator function plus Stages 0–2 and validator tests.
Coordination note: this task overlaps most entry-point scripts and should be integrated before parallel tasks modify them.

### 1.4 Harden file selection and participant identity

- [ ] Handle cancellation from each `uigetfile` call without entering a processing loop.
- [ ] Load files from the directory actually returned by the selector, or deliberately constrain selection to the configured directory and document that rule.
- [ ] Derive participant IDs from filenames with an explicit, tested naming convention rather than relying only on removal of `_raw.bdf`.
- [ ] Check for empty or duplicate participant IDs within a selected batch before preprocessing begins.
- [ ] Preserve prefixes and leading zeros by treating participant IDs as strings throughout.

Likely files: Stage 1, Stage 2, new tests where EEGLAB-independent logic can be isolated.

### 1.5 Make rejection accounting internally consistent

- [ ] Write rejection statistics only for participants completed so far, avoiding preallocated empty rows in incremental CSV checkpoints.
- [ ] Define behavior when a configured condition has zero trials, including whether its rejection percentage is missing or explicitly reported another way.
- [ ] Verify automatic-only, manual-only, combined, and disabled rejection paths.
- [ ] Confirm that saved preprocessed SET files intentionally retain flagged trials while extracted features use only retained trials.
- [ ] Reassess automatic-rejection thresholds scientifically; do not tune them merely to obtain a preferred rejection rate.

Likely files: Stage 2, Stage 0 documentation, integration tests.
Scientific decision: artifact thresholds and acceptable rejection rates belong to the researcher.

## Delegation map for Tier 1.1 and 1.2

The event and trigger-shifting work should be delegated in two waves. Wave A uses non-overlapping file ownership: the two event tasks implement the approved character contract, while trigger-shifting tasks remain isolated in new test/reference files. Wave B integrates only the validated trigger-shifting work into production. This avoids permanent helper proliferation before that behavior is trusted.

No worker in Wave A should edit a shared test runner. Each worker supplies a directly runnable MATLAB test file; Agent 0 adds or updates the unified runner during integration.

### Pre-delegation gates owned by Agent 0

#### Gate E: event representation contract — approved as CD-11

The approved contract is:

- every `EEG.event.type` value is converted to a MATLAB character vector;
- numeric `121` becomes `'121'`;
- character `'121'` remains `'121'`;
- string `"121"` becomes `'121'`;
- Brain Vision marker `'S 121'` remains `'S 121'`;
- Brain Vision marker `'S121'` remains `'S121'`;
- no prefix, spacing, leading-zero, or other encoded content is removed from an existing character or string value;
- no audit field is added;
- users enter configured trigger codes as character vectors in Stage 0;
- matching uses character comparison rather than mixed-type element-wise equality.

The representation changes only MATLAB type, not the experimenter's encoded trigger value or its meaning.

#### Gate S: trigger-shift scientific contract

Approved on 2026-09-08 (CD-13): preserve the existing direction by adding signed delays to latency, with sample offsets calculated as `round(delay_ms * srate / 1000)`. Round the offset only, preserving any fractional part of the original latency. T1.2-B can proceed under this contract.

CD-14 and CD-15 additionally approve the existing range-divisor threshold (default 4), user-configured crossing duration in milliseconds, nearest-zero anchor with positive-side tie breaking, a participant-level median mode, and median fallback for missing crossings or omitted epochs with warnings. No valid detections, missing photodiode channels, and corrected events outside recording bounds cause errors. See CONCEPTUAL_DECISIONS.md for the complete contract.

The researcher selected a default crossing duration of 20 ms. Use `ceil(duration_ms * srate / 1000)` for the positive duration's minimum sample count (11 samples at 512 Hz); retain CD-13's `round` for delay offsets. The listed Gate S decisions are resolved for implementation.

Agents may audit these choices and build parameterized reference tests in parallel, but must not silently select scientific defaults.

### Wave A: independent reference and unit-test tasks

#### Task T1.1-A: canonical marker normalization

- **Status:** Completed, integrated, and validated in MATLAB R2024b.
- **Objective:** Make `fix_EEG_markers` implement CD-11 by converting numeric and string event types to character vectors while leaving existing character content exactly unchanged.
- **Relevant files/modules:** `fix_EEG_markers.m`; new `tests/test_event_marker_normalization.m`.
- **Dependencies:** CD-11. No dependency on another implementation task.
- **Likely conflicts:** Any task editing `fix_EEG_markers.m`; the later trigger-shift integration consumes this contract but should not edit this file concurrently.
- **Validation criteria:** Deterministic tests confirm numeric-to-character and string-to-character conversion; existing numeric characters, Brain Vision markers, spacing, prefixes, leading zeros, and textual markers remain exactly unchanged; every resulting event type is a character vector. The tests should not require EEGLAB where direct struct operations suffice.

#### Task T1.1-B: adapt Stage 0 and Stage 2 to character triggers

- **Status:** Completed, integrated, and validated on a representative participant.
- **Objective:** Change the configured condition triggers to character vectors, inform users of the character conversion, and replace only the Stage 2 comparison expression while retaining the existing nested loops and event-copying behavior.
- **Relevant files/modules:** Trigger comments/value in `EMG_00_settings.m`; Section 2.4.2 in `EMG_02_preprocessing_feature_extraction.m`; a focused manual or deterministic test if it can exercise the production logic without adding a new helper.
- **Dependencies:** CD-11 and the existing one-to-one order of `sets.condition_triggers` and `sets.condition_names`. It does not depend on Task T1.1-A's code because both agents work from the approved contract.
- **Likely conflicts:** Tier 1.3 or other work editing Stage 0 or Stage 2. It does not conflict with Task T1.1-A.
- **Validation criteria:** Stage 0 stores condition triggers as character vectors; a matching character trigger receives the correct condition label; a nonmatching event receives no label; the copied label event retains the source latency and metadata; no new helper, audit field, mapping validation, duplicate-execution guard, or unrelated edge-case handling is introduced.

#### Task T1.2-A: photodiode onset-detection reference

- **Status:** Completed as an audit and parameterized test-only reference; all tests passed in the researcher's MATLAB run, reported on 2026-09-08. Agent 3 commit `2a624b4` was integrated as `9ac2f7f`. Production shifting and Gate S policy approval remain pending.
- **Objective:** Isolate the conversion of a processed photodiode epoch into one delay per trial and expose every scientific choice from Gate S rather than hiding it in EEGLAB calls.
- **Relevant files/modules:** New test-only reference logic under `tests/helpers`; new `tests/test_photodiode_delay_detection.m`; read-only audit of the variable branch in `shift_triggers.m`.
- **Dependencies:** Gate S may remain partly undecided while the agent creates parameterized tests, but implementation cannot be declared final until every policy is approved.
- **Likely conflicts:** None in Wave A if `shift_triggers.m` remains read-only. Task T1.2-C will later consume the validated reference.
- **Validation criteria:** Synthetic trials with distinct onsets return distinct delays; the sample at or nearest zero is selected deterministically; the first qualifying sample has no off-by-one error; sustained-run behavior is tested; missing crossings and invalid thresholds follow the approved policy; output length and trial order are explicit; no Image Processing Toolbox is required unless retained as an intentional dependency.

#### Task T1.2-B: latency-application reference

- **Status:** Completed as an audit and test-only reference under CD-13; the researcher reported the MATLAB test suite passing on 2026-09-08. Agent 3 commit `accfbce` was integrated unchanged as `ca9f604`. Production integration remains pending.
- **Objective:** Specify and test how scalar fixed delays and trial-specific delay vectors are applied, in order, only to matching events while producing an auditable before/after record.
- **Relevant files/modules:** New test-only reference logic under `tests/helpers`; new `tests/test_trigger_latency_application.m`; read-only audit of fixed and variable branches in `shift_triggers.m`.
- **Dependencies:** CD-11 and the direction/rounding portions of Gate S. It is independent of photodiode detection because it accepts delays as inputs.
- **Likely conflicts:** None in Wave A if `shift_triggers.m` remains read-only. Task T1.2-C will later consume the validated reference.
- **Validation criteria:** Positive, zero, and negative fixed delays follow the approved sample conversion; target and non-target character events are handled safely; distinct per-trial delays are not reset to the first value; delay/event count mismatches error before mutation; non-target latencies and event order are unchanged; the audit output matches the applied changes.

### Wave B: production integration tasks

#### Task T1.2-C: integrate and validate trigger shifting

- **Status:** Implemented and integrated as `5539508` from Agent 3's `9f4a6a1`. On 2026-09-09 the researcher reported all synthetic tests passing and Stage 1 running successfully on actual data in both variable and median modes. The researcher confirmed the current Stage 0 → Stage 1 check of the legacy-settings fallback removal passed on 2026-09-09. Targeted real EEGLAB edge cases in the acceptance guide are not individually confirmed by this report.
- **Objective:** Refactor `shift_triggers.m` around the validated onset-detection and latency-application behavior, correct per-trial indexing, make failure modes explicit, and update Stage 1/settings documentation without changing unapproved scientific choices.
- **Relevant files/modules:** `shift_triggers.m`, `EMG_01_raw2set_shift_triggers.m`, trigger-shift comments in `EMG_00_settings.m`, Tasks T1.2-A/B tests, and any final EEGLAB integration test instructions.
- **Dependencies:** Tasks T1.1-A and T1.1-B; Tasks T1.2-A and T1.2-B; all Gate S decisions. A representative photodiode dataset is needed for final EEGLAB validation.
- **Likely conflicts:** Tier 1.3 or Tier 1.4 work touching Stage 0 or Stage 1. It should not run concurrently with those integrations.
- **Validation criteria:** All reference tests pass; fixed shifting changes only selected events by the approved sample offset; variable mode maps distinct trial delays to the correct continuous events; missing photodiode channels, zero samples, crossings, and count mismatches fail according to policy; before/after evidence is inspectable; a MATLAB/EEGLAB run on representative data confirms the plots or diagnostics and resulting event latencies.

### Integration and concurrency schedule

With four total agent slots, including Agent 0:

1. Agent 0 records approved CD-11 and CD-12 and starts the Gate S decision record.
2. Run Tasks T1.1-A, T1.1-B, and T1.2-A concurrently in three worker slots.
3. Run Task T1.2-B when a worker slot becomes free; it is logically parallel with all Wave A tasks.
4. Agent 0 reviews and integrates Wave A without allowing workers to edit the shared runner or coordination documents.
5. Run Task T1.2-C after its dependencies and Gate S decisions are satisfied; no separate condition-mapping integration task is needed.
6. Agent 0 adds a unified event/trigger test runner if warranted, coordinates user-run MATLAB/EEGLAB validation, updates the decision ledger, and integrates approved commits into `main`.

### Wiki knowledge-base task

Delegate wiki preparation to a documentation-only Wiki Curator agent. This is safely separable from implementation and reduces Agent 0's context load, but scientific authority remains with the researcher and Agent 0.

- **Objective:** Transform approved conceptual material into a navigable future-wiki outline and draft pages without inventing methods or decisions.
- **Relevant files/modules:** Read-only access to `PROJECT_PLAN.md`, `CONCEPTUAL_DECISIONS.md`, relevant MATLAB comments, and tests; new output only under a dedicated `wiki_drafts/` directory unless Agent 0 specifies another location.
- **Dependencies:** The two coordination documents should be committed so the curator works from a stable baseline. Event representation may cite implemented and validated CD-11/CD-12, while trigger-shifting pages remain draft until Tier 1.2 decisions are integrated.
- **Likely conflicts:** None if the curator does not edit `PROJECT_PLAN.md`, `CONCEPTUAL_DECISIONS.md`, MATLAB code, or tests. Agent 0 should integrate conceptual updates before asking the curator to refresh drafts.
- **Validation criteria:** Every technical statement maps to a decision ID, code location, test, or explicitly labeled unresolved question; implementation detail is separated from scientific rationale; no sensitive paths/data are included; citations are not fabricated; Agent 0 and the researcher review the drafts before publication.

The authoritative information flow is:

1. `PROJECT_PLAN.md` owns task status, dependencies, and integration order.
2. `CONCEPTUAL_DECISIONS.md` owns approved scientific and engineering decisions.
3. Worker agents cite decision IDs in their handoffs and submit new issues as decision proposals rather than editing the decision ledger.
4. Agent 0 resolves proposals with the researcher, updates the ledger, and only then asks the Wiki Curator to incorporate them.
5. Wiki drafts are explanatory derivatives, never the source of truth for implementation.

## Tier 2: important maintainability and validation improvements

### 2.1 Validate channel selection and re-referencing

- [ ] Make the recording-system/channel-layout rule unambiguous, including the one-muscle BioSemi case.
- [ ] Validate channel indices before selecting or subtracting signals.
- [ ] Confirm that `chanlocs`, channel labels, and `nbchan` remain consistent after selection.
- [ ] Document the subtraction direction for each bipolar muscle pair.

### 2.2 Expand regression coverage beyond MAV

- [x] Add deterministic tests for marker normalization.
- [ ] Add automated integration coverage for condition-label creation, trigger shifting, participant-key preservation, rejected-row reconstruction, and settings validation.
- [ ] Add small synthetic integration fixtures where EEGLAB-independent testing is possible.
- [ ] Maintain explicit MATLAB R2024b execution instructions and record compatibility results for later releases when tested.

### 2.3 Improve run provenance and recoverability

- [ ] Decide how each output should identify the settings snapshot that created it.
- [ ] Record software/toolbox versions needed to reproduce a run.
- [ ] Clarify intentional overwrite behavior for SET, rejection-statistics, and feature CSV outputs.
- [ ] Preserve the current participant-level feature checkpoint behavior unless the researcher explicitly changes that decision.

### 2.4 Remove development-only overhead and stale comments

- [ ] Remove or gate full-dataset debug copies such as `EMG_bkp` once no longer needed.
- [ ] Reassess the unconditional Stage 1 pause.
- [ ] Correct stale filenames, typos, section descriptions, and output descriptions.
- [ ] Keep cleanup commits separate from scientific changes where practical.

## Tier 3: documentation and project presentation

### 3.1 Build user-facing documentation

- [ ] Create a concise README covering requirements, folder layout, configuration, stage order, and expected outputs.
- [ ] Convert `CONCEPTUAL_DECISIONS.md` into focused GitHub wiki pages after the concepts stabilize.
- [ ] Add worked examples using synthetic or non-sensitive data only.

### 3.2 Prepare a reproducible release

- [ ] Choose a public versioning convention and update the script version headers consistently.
- [ ] Add citation, license, authorship, and upstream-attribution information.
- [ ] Define a release checklist including MATLAB tests and representative EEGLAB integration runs.

## Recommended execution order

1. Tier 1.1: event normalization and matching — completed and validated.
2. Tier 1.2: trigger shifting — integrated and representative runs validated; settings-cleanup rerun passed.
3. Tier 1.3: settings validator, establishing entry-point contracts for later work.
4. Tier 1.4: file selection and participant identity.
5. Tier 1.5: rejection accounting and scientific audit.
6. Tier 2 work in small, independently reviewed units.

Agent 0 may change this order when dependencies or researcher priorities change, but should record the reason here.

## Validation baseline

On 2026-09-09 the researcher reported all synthetic suites passing and actual-data Stage 1 runs succeeding in both `variable` and `median` modes at `9f4a6a1` (integrated as `5539508`). Agent 0 reviewed the implementation and removed only the legacy-settings fallback afterward; configured runs still pass the same duration value. The researcher subsequently confirmed that quick Stage 0 → Stage 1 check passed without issues at `be6537d`. This report does not establish completion of every targeted real-data case in `tests/trigger_shift_integration_acceptance.md`.

Task T1.2-B validation was reported by the researcher on 2026-09-08: the MATLAB latency-application test suite passed at Agent 3 commit `accfbce` (integrated unchanged as `ca9f604`). Coverage includes signed and zero delays, fractional and half-sample rounding, fractional original latencies, exact character matching, distinct explicitly mapped delays, metadata preservation, mapping/count errors, and diagnostic agreement. This validates the numerical reference; production `shift_triggers.m` and EEGLAB epoch-to-event mapping still require T1.2-C integration and validation.

Task T1.2-A validation was reported by the researcher on 2026-09-08: all photodiode onset-detection reference tests passed at Agent 3 commit `2a624b4` (integrated unchanged as `9ac2f7f`). This validates the tested numerical alternatives, not production `shift_triggers.m` or approval of any Gate S policy. The audit and reference are under `tests/`; T1.2-B and T1.2-C remain outstanding.

The baseline-correction interface cleanup at commit `40672a8` was validated in MATLAB on 2026-09-07:

- the deterministic test suite passed;
- Stage 2 completed with baseline correction set to `subtraction`;
- Stage 2 completed with baseline correction set to `division`;
- Stage 2 completed with `sets.do_baseline_correction = 0` and produced the raw-MAV pathway;
- enabling baseline correction with method `none` produced the intended invalid-method error.

Tier 1.1 validation completed in MATLAB R2024b on 2026-09-07:

- the deterministic event-marker normalization tests passed;
- the Stage 0 and Stage 2 character-trigger changes passed their isolated checks;
- the combined implementation successfully processed one representative participant through all pipeline stages.

The following evidence exists at commit `f93f00a`:

- all deterministic MAV calculation and standardization tests passed in MATLAB R2024b;
- helper-backed Stage 2 output validation passed;
- helper-backed full-script and section outputs matched;
- final inline full-script and section outputs passed validation;
- final inline outputs matched the helper-backed numerical reference;
- repository static whitespace checks passed with the established Stage 2 CRLF convention.

No local MATLAB or Octave runtime is available to Agent 0 in the current Codex workspace. MATLAB-dependent changes therefore require a user-run validation handoff.
