# Project Structure and Paths

This page explains how the pipeline locates the repository, separates project-owned outputs from external inputs, and behaves when MATLAB scripts are run as complete files or as individual sections.

## Stage 0 and saved settings

Stage 0 collects the researcher's choices in a MATLAB structure named `sets`. It defines internal directories, validates the configuration, records lightweight environment information, and writes two files under `resources/`:

- `preprocessing_settings.mat`, which Stages 1 and 2 load;
- `preprocessing_settings.txt`, which provides a readable record of the same settings.

Settings saved by older development versions are not updated automatically. After updating the pipeline or changing a setting, run the current Stage 0 again before running later stages.

Channel configuration is described separately in [EMG Channel Selection and Re-referencing](EMG-Channel-Selection-and-Re-referencing.md#configuration-in-stage-0).

## How the project directory is located

Stages 0–2 infer the project directory from the active script in the MATLAB Editor rather than from MATLAB's current working directory. This supports both complete-script and section-level execution, where the current working directory may not be the repository.

The relevant stage script must therefore be open and active when its setup section runs. Internal paths are constructed with MATLAB's `fullfile` function, which uses the platform-appropriate path separator.

This behavior has been validated in MATLAB R2024b. Compatibility with later releases should be checked rather than assumed.

## Project-owned directories

| Directory               | Role                                                                                                            |
| ----------------------- | --------------------------------------------------------------------------------------------------------------- |
| `raw/`                  | Raw EEGLAB SET datasets created by Stage 1 and, when trigger shifting is enabled, trigger-diagnostic MAT files. |
| `preprocessed/`         | Stage 2 SET checkpoints and the optional trial-rejection statistics table.                                      |
| `extracted_amplitudes/` | Cumulative feature-amplitude tables written by Stage 2.                                                         |
| `resources/`            | Channel-location resources and generated settings snapshots.                                                    |

Stage 0 creates `raw/`, `preprocessed/`, and `extracted_amplitudes/` only when they are absent. Rerunning Stage 0 does not delete existing files.

This does not provide output versioning. Later save operations can overwrite an existing file when the configured filename is reused. Researchers should preserve outputs from distinct processing occasions in an appropriate external archive or versioned analysis workflow.

The `resources/` directory is different: it contains required files and must already exist. Stage 0 raises an error rather than constructing an empty replacement.

## External paths

Two paths remain outside the repository:

- the directory containing source BDF recordings;
- the local EEGLAB installation.

Both are configured in Stage 0. Raw recordings and toolbox installations are machine- or study-specific resources, so the pipeline does not assume they are stored within the repository.

Stages 1 and 2 use the saved settings and `fullfile` to locate inputs and outputs. Stage 1 writes imported datasets to `raw/`. Stage 2 initially offers `raw/` in its file selector, saves inspection checkpoints and rejection statistics to `preprocessed/`, and writes feature tables to `extracted_amplitudes/`.

## File selection and participant names

The configured input directory is the starting location for the Stage 1 or Stage 2 file dialog. Users may browse to another directory; the pipeline loads from the directory returned by the dialog. Cancelling the dialog stops that run before participant processing. During section-level execution, stop after cancellation and make a new selection before continuing.

Stage 1 uses the raw BDF filename stem as the participant ID:

```text
001.bdf → '001'
```

The text value is saved in `EMG.subject`. Stage 2 uses that saved value rather than parsing the SET filename, so prefixes and leading zeros remain intact even if the SET file is renamed.

Filename correctness and uniqueness are the researcher's responsibility. The pipeline does not check for empty or duplicate participant IDs. If a study uses another naming convention, adapt the ID-extraction line in Stage 1 while keeping the result as text. If the raw SET suffix is changed from `_raw`, also adapt Stage 2's `*_raw.set` selection filter.

## Complete scripts and individual sections

A complete-script run executes the sections in their written order after clearing the relevant workspace variables. Running one MATLAB section executes only that block and depends on state created by earlier sections.

Project-root inference makes both execution styles locate the same repository, but it does not make sections independent or repeatable. Stage 2 processing is non-idempotent: running a section twice on the same in-memory dataset can apply a transformation twice or duplicate condition events.

When running by sections:

- begin with the stage's setup section;
- run each section once and in order;
- use completion messages to track what has already run;
- restart the stage after changing settings or after an interrupted run whose in-memory state is uncertain.

## Practical implications

- Keep the relevant stage script active in the MATLAB Editor during setup.
- Configure the external BDF and EEGLAB paths for the current machine.
- Treat generated settings and outputs as analysis records that may contain private paths or study information.
- Expect normal save operations to replace files with the same configured names.
- Read participant identifiers as text in downstream software so leading zeros are preserved.
