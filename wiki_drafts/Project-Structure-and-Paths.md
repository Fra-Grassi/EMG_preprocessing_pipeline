# Project Structure and Paths

This page explains how the pipeline locates its repository, organizes project-owned files, and behaves when MATLAB scripts are run as complete files or as individual sections.

## Conceptual rationale

Stage 0 is the pipeline's configuration stage. It collects the researcher's processing choices in a `sets` MATLAB structure, defines the project-owned directories used by later stages, checks the incompatible setting combinations currently covered by the implementation, and saves the settings to `resources/` in both machine-readable and human-readable forms.

The central path decision in CD-01 is that project-internal paths are anchored to the actual Stage script rather than MATLAB's current working directory. This matters because the pipeline is used both by running a complete script and by running individual MATLAB Editor sections. During section execution in the validated MATLAB R2024b environment, the working directory can refer to a temporary Editor location. A path derived from `pwd` could therefore point outside the project even though the correct script is open.

Instead, Stages 0–2 use the active MATLAB Editor filename to infer the project directory. The relevant stage must consequently be open and active in the Editor when its path-setup section runs. Later MATLAB releases are not claimed as validated merely because the same behavior is expected.

MATLAB's `fullfile` function is used to join the inferred project directory with folder and file names. `fullfile` supplies the appropriate path separator and avoids dependence on a hand-written platform-specific path string. The stages therefore do not rely on the process working directory for project-owned files.

## Standard project-owned directories

Stage 0 assigns the following repository-internal locations:

| Directory | Role |
| --- | --- |
| `raw/` | Raw EEGLAB SET datasets created by Stage 1 and, when trigger shifting is enabled, participant-level trigger diagnostics MAT files. |
| `preprocessed/` | Stage 2 SET checkpoints and the optional trial-rejection statistics table. |
| `extracted_amplitudes/` | Cumulative feature-amplitude tables written by Stage 2. |
| `resources/` | Tracked channel-location resources plus generated settings snapshots. |

The first three are output directories. Stage 0 creates each one only when it is absent. It does not remove an existing directory or delete its contents, so rerunning Stage 0 does not erase previously processed files. This protection does not imply versioned outputs: later save operations can replace a file that has the same configured filename, as the Stage 0 saving comments explicitly warn.

`resources/` is different. It contains files required by the pipeline and must already exist; Stage 0 raises an error rather than silently constructing an empty replacement.

## Paths that remain external

Two locations are deliberately not inferred as repository-owned directories:

- the directory containing source BDF acquisition files;
- the local EEGLAB installation.

Both are user-configured in Stage 0. Raw acquisition data and a toolbox installation are machine- or study-environment resources, not properties of the repository. The wiki therefore describes their roles without embedding any local filesystem value.

Stages 1 and 2 load the saved settings from `resources/`, then use `fullfile` for settings files, selected input patterns, channel-location resources, and outputs. Stage 1 saves imported datasets under `raw/`; when trigger shifting is enabled, it saves a diagnostics MAT file beside each corresponding SET dataset. Stage 2 initially offers `raw/` in its selector, saves preprocessed SET checkpoints and rejection statistics under `preprocessed/`, and writes feature tables under `extracted_amplitudes/`.

## Selecting files and adapting participant names

Use the current Stage 0 as the main place to configure paths, processing choices, and output suffixes (CD-16). In Stages 1 and 2, the configured input folder is the file dialog's starting location. You can browse elsewhere: each stage loads from the folder returned by the dialog. Cancel stops the current run before any participant is processed or saved. When running Editor sections, stop after cancellation and select files again before continuing; the cancelled selection is emptied so the participant loop has no files to process.

For this project, name raw files `001.bdf`, `002.bdf`, and so on. Stage 1 Section 1.3.5 uses `fileparts` to take the filename without its extension, so `001.bdf` sets `EMG.subject` to character `'001'`. The configured `sets.fname_raw_data` suffix is then appended to form the SET name. Stage 2 uses the saved `EMG.subject`, preserving the leading zeros even if the SET file is renamed. Filename correctness is the user's responsibility; the stages do not check for empty or duplicate participant IDs.

For another project's naming convention, adapt the ID extraction line in Stage 1 Section 1.3.5 and keep the result as text. Configure the output suffix in Stage 0; if it differs from `_raw`, also adapt Stage 2 Section 2.2's `*_raw.set` selection filter. There is no additional Stage 0 naming option or generic filename parser.

This implemented behavior is recorded in CD-17 and follows CD-02's text-identity rule. On 2026-09-18, the researcher reported the file-selection and identity tests and acceptance checks passing, including batch selection and processing; see the [file-selection handoff](../tests/file_selection_identity_handoff.md). This validation does not turn filename correctness into an automatic check.

## Complete scripts and individual sections

A complete-script run executes a stage's sections in their written order after the script's initial workspace clearing. A section-level run executes only the selected block and depends on the required variables and in-memory EEGLAB dataset having been created by earlier sections.

Project-root inference is designed to resolve the same repository location in either mode, provided the appropriate Stage script is active in the MATLAB Editor. It does not make sections independent or repeatable. Stage 2 is intentionally non-idempotent under CD-12: applying a section twice to the same in-memory dataset can change the result. Section-level users must execute each section once and treat its completion message as the cue that the step has already run.

This page explains that execution contract; it is not a run guide. In particular, it does not imply that a later section can safely be started without the state produced by earlier sections.

## User-facing implications

- Keep the Stage script being executed open and active when its setup section determines the project directory.
- Moving the repository carries its internal structure with it because internal paths are derived rather than hard-coded.
- Configure the BDF source and EEGLAB locations for the current machine; do not expect them inside the repository.
- Rerunning Stage 0 preserves existing directory contents, but saving a later output under an existing configured filename may overwrite that file.
- When using MATLAB sections, run each Stage 2 section once and follow the completion messages.

## Traceability

- **Decisions:** [CD-01](../CONCEPTUAL_DECISIONS.md#project-path-resolution-and-section-execution) governs paths; [CD-17](../CONCEPTUAL_DECISIONS.md#file-selection-and-participant-identity-cd-17) governs selection and text identity; [CD-10](../CONCEPTUAL_DECISIONS.md#decision-register) governs entry-point validation. Section execution also follows [CD-12](../CONCEPTUAL_DECISIONS.md#event-representation-contract), and separate trigger diagnostics follow [CD-15](../CONCEPTUAL_DECISIONS.md#median-shifting-and-fallback-cd-15).
- **Production files and sections:** [`EMG_00_settings.m`, Sections 0.1 and 0.4](../EMG_00_settings.m); [`EMG_01_raw2set_shift_triggers.m`, Sections 1.1–1.3](../EMG_01_raw2set_shift_triggers.m); [`EMG_02_preprocessing_feature_extraction.m`, Sections 2.1–2.4.15](../EMG_02_preprocessing_feature_extraction.m).
- **Tests and recorded validation:** [`compare_mav_outputs.m`](../tests/compare_mav_outputs.m) supports complete-script versus section-output comparison; [`test_file_selection_identity.m`](../tests/test_file_selection_identity.m) covers selector paths, cancellation, and ID handling; [`test_validate_settings.m`](../tests/test_validate_settings.m) covers the shared validator. [PROJECT_PLAN.md, Tier 0.4 and validation baseline](../PROJECT_PLAN.md#04-establish-reproducible-project-paths) records the validation status.
- **Current implementation status:** CD-01, CD-10, and CD-17 are implemented and validated as recorded in the plan; CD-15's separate trigger-diagnostics output is integrated. The shared validator checks settings at each stage entry without modifying settings or creating folders. Stage 0 Section 0.2 contains only user settings and comments; Section 0.3 calls the validator.
