# EMG Preprocessing Pipeline

This repository contains a MATLAB pipeline for preprocessing surface electromyography (EMG) data with EEGLAB and extracting mean absolute value (MAV) features.

The pipeline is organized into three scripts:

1. **Stage 0** defines and checks the analysis settings.
2. **Stage 1** imports BDF recordings, optionally corrects trigger timing, and saves EEGLAB SET files.
3. **Stage 2** preprocesses the EMG signals, marks or rejects trials, and extracts MAV features.

The current version is **v0.1.0**.

## What you need

- **MATLAB.** The pipeline was developed and validated with MATLAB R2024b. Other releases may work, but have not yet been tested.
- **[EEGLAB](https://sccn.ucsd.edu/eeglab/).**
- The EEGLAB **[BIOSIG](https://eeglab.org/others/EEGLAB_Extensions.html)** plugin, used to import BDF files and their events.
- The EEGLAB **[CleanLine](https://eeglab.org/plugins/cleanline/)** plugin if you want to estimate trigger delays from a photodiode signal.
- The EEGLAB **FIRfilt** plugin if filtering is enabled.

EEGLAB plugins can be installed through the EEGLAB extension manager. MATLAB, EEGLAB, and the plugins are not included in this repository.

## Getting started

### 1. Download the pipeline

Download the repository from GitHub or clone it with Git. Keep the folder structure unchanged.

Your raw BDF files can be stored anywhere on your computer or network. Stage 0 will ask you to provide their location. The original BDF files are only read by the pipeline and are not modified.

### 2. Configure Stage 0

Open [`EMG_00_settings.m`](EMG_00_settings.m) in the MATLAB Editor. Section 0.2 contains all settings that users are expected to edit.

At minimum, replace these example values:

```matlab
sets.study_name = 'example_study';
sets.rawBDF_dir = 'EDIT_PATH_TO_RAW_BDF_FILES';
sets.eeglab_dir = 'EDIT_PATH_TO_EEGLAB';
```

Then review the remaining settings carefully, including:

- recording layout and EMG channels;
- condition triggers and condition names;
- trigger-shifting method;
- filtering and downsampling;
- epoch and baseline windows;
- automatic and manual trial rejection;
- MAV bin duration and standardization;
- output filenames and saving options.

Keep `EMG_00_settings.m` open in the MATLAB Editor and run the complete script. You may also run Sections 0.1–0.4 once, in order.

Stage 0 checks the settings and creates these project folders when they do not already exist:

- `raw/`
- `preprocessed/`
- `extracted_amplitudes/`

It also saves the settings as both a MATLAB file and a readable text file under `resources/`.

### 3. Run Stage 1

Open and run [`EMG_01_raw2set_shift_triggers.m`](EMG_01_raw2set_shift_triggers.m). Select one or more BDF recordings when prompted.

Stage 1:

- imports the recordings and their events through BIOSIG;
- converts event codes to MATLAB character values without changing the codes themselves;
- optionally corrects selected trigger times using a fixed delay or a photodiode signal;
- saves one raw EEGLAB SET dataset per participant in `raw/`.

Participant IDs are taken from the BDF filename. For example, `001.bdf` produces participant ID `'001'`, preserving the leading zeros. If your files use another naming convention, adapt this step before processing your study.

When photodiode-based trigger shifting is used, inspect the diagnostic figure for each participant before continuing. The figure remains open so that you can evaluate the detected delays.

### 4. Run Stage 2

Open and run [`EMG_02_preprocessing_feature_extraction.m`](EMG_02_preprocessing_feature_extraction.m). Select the raw SET files created by Stage 1.

Depending on the Stage 0 settings, Stage 2 can:

- select individual EMG channels or calculate bipolar channels;
- filter, downsample, rectify, and epoch the EMG data;
- identify trials for automatic and/or manual rejection;
- apply trial-wise baseline correction;
- extract MAV features in time bins;
- standardize features within each muscle or across the participant;
- average retained trials by condition;
- save preprocessed SET datasets, rejection statistics, and feature tables.

Stage 2 saves progress after each participant. If a later participant produces an error, results already written for earlier participants remain available.

## Output folders

| Folder | Contents |
| --- | --- |
| `resources/` | Channel-location files and the settings saved by Stage 0. |
| `raw/` | Raw SET datasets created by Stage 1 and, when requested, trigger-shifting diagnostics. |
| `preprocessed/` | Optional preprocessed SET datasets and trial-rejection statistics. |
| `extracted_amplitudes/` | The cumulative MAV feature table. |

Stage 0 never deletes existing folder contents. However, later stages can replace an existing output if the same filename is used again. When processing different participant groups on separate occasions, choose output filenames or make backups appropriate for your workflow.

If rejected trials are retained in the final feature table, their identifying information remains present but their MAV values are missing. Missing values do not mean zero muscle activity.

## Choosing appropriate settings

The values supplied in Stage 0 **are examples, not recommended settings for every dataset**. Researchers remain responsible for choosing and reporting settings that are appropriate for their recordings and research questions.

In particular, artifact-rejection thresholds should be selected after inspecting the quality and distribution of the data. The pipeline does not determine scientifically appropriate thresholds automatically.

For MAV extraction, the implemented order is:

```text
rectification
→ trial-wise waveform baseline correction
→ MAV extraction in time bins
→ standardization using retained post-stimulus observations
→ optional averaging by condition
```

Changing this order changes the meaning of the resulting features. The reasoning behind this workflow is explained in the [conceptual documentation](docs/README.md).

## Running scripts by section

The three stages can be run as complete scripts or one MATLAB section at a time. Section-level execution is useful for inspecting intermediate results, but the sections must be run once and in order. Repeating a processing section on the same in-memory dataset can apply the operation twice and produce incorrect output.

Always keep the stage being run open in the MATLAB Editor. The pipeline uses the active script to locate the project folder.

## Further documentation

The [conceptual documentation](docs/README.md) explains the main processing decisions in more detail:

- [project structure and paths](docs/Project-Structure-and-Paths.md);
- [EMG channel selection and bipolar re-referencing](docs/EMG-Channel-Selection-and-Re-referencing.md);
- [event codes and condition labels](docs/Event-Representation-and-Condition-Labels.md);
- [trigger shifting and diagnostics](docs/Trigger-Shifting-and-Diagnostics.md);
- [MAV processing and standardization](docs/MAV-Processing-and-Standardization.md);
- [feature tables and rejected trials](docs/Participant-Safe-Feature-Outputs.md).

## Citation and license

This project is adapted and expanded from [`TommasoGhilardi/EMG_Pipelines`](https://github.com/TommasoGhilardi/EMG_Pipelines) and the following publication:

> Rutkowska, J. M., Ghilardi, T., Vacaru, S. V., van Schaik, J. E., Meyer, M., Hunnius, S., & Oostenveld, R. (2024). Optimal processing of surface facial EMG to identify emotional expressions: A data-driven approach. *Behavior Research Methods, 56*, 7331–7344. <https://doi.org/10.3758/s13428-024-02421-4>

If you use this repository, please also consult [`CITATION.cff`](CITATION.cff). The code and documentation are released under the [Creative Commons Attribution 4.0 International License](LICENSE). Additional acknowledgments and resource provenance are listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## For developers

The remaining sections are intended for people who want to modify, test, or contribute to the pipeline. Researchers who only want to run the pipeline do not need them.

### Repository structure

| Path | Purpose |
| --- | --- |
| [`validate_settings.m`](validate_settings.m) | Checks the settings required by each stage. |
| [`shift_triggers.m`](shift_triggers.m) | Implements fixed and photodiode-based trigger correction. |
| [`fix_EEG_markers.m`](fix_EEG_markers.m) | Converts imported event codes to character values. |
| [`writeSetsToTxt.m`](writeSetsToTxt.m) | Writes the readable settings snapshot. |
| [`tests/`](tests) | MATLAB tests, controlled EEGLAB substitutes, and validation handoffs. |
| [`docs/`](docs) | Researcher-facing explanations of implemented concepts. |
| [`CONCEPTUAL_DECISIONS.md`](CONCEPTUAL_DECISIONS.md) | Technical decision record. |
| [`PROJECT_PLAN.md`](PROJECT_PLAN.md) | Development history and coordination record. |

`CONCEPTUAL_DECISIONS.md` and `PROJECT_PLAN.md` support transparency and continued development. They are not instructions for running the pipeline.

### Private settings during development

Maintainers who need to process private study data can copy `EMG_00_settings.m` to `EMG_00_settings_local.m`. The local filename is excluded from Git and can contain machine-specific paths and study settings.

Keep the local copy in the repository root so that project-folder detection continues to work. If the public Stage 0 script changes, update the local copy manually. There is no separate local-settings loader: both scripts save the same settings files used by Stages 1 and 2.

Never commit the local Stage 0 copy or generated settings files because they may contain private paths or study information.

### Validation status

The deterministic tests and representative pipeline runs have been reported passing in MATLAB R2024b. This includes representative Stage 1 runs with variable and median trigger shifting, Stage 0 and Stage 2 runs under the explicit channel-selection contract, and the lightweight settings and SET provenance checks across all three stages.

Some tests use synthetic data or controlled replacements for individual EEGLAB functions. These tests verify calculations and pipeline organization, but do not prove compatibility with every MATLAB, EEGLAB, plugin, recording layout, or dataset. Representative runs remain necessary when applying the pipeline to a new study.

### Running the tests

From the repository root in MATLAB R2024b:

```matlab
addpath(pwd);
results = runtests('tests', 'IncludeSubfolders', true);
disp(results);
assertSuccess(results);
```

The tests use synthetic fixtures and temporary output files. The Markdown handoffs under [`tests/`](tests) describe additional acceptance checks and the limits of individual test suites.

### Contributing and reporting problems

Use the repository's [GitHub issue tracker](https://github.com/Fra-Grassi/EMG_preprocessing_pipeline/issues) for reproducible bug reports and focused proposals.

When reporting a problem, include:

- MATLAB, EEGLAB, and plugin versions;
- the pipeline stage and section;
- relevant non-sensitive settings;
- the complete warning or error message;
- a minimal reproducible example when possible.

Do not upload participant data or private paths. Contributions should not silently change scientific assumptions, rejection rules, missing-data handling, or output meanings. Explain and test any proposed change that affects them.
