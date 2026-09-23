# EMG Preprocessing Pipeline

This repository contains a MATLAB and EEGLAB pipeline for preprocessing surface electromyography (EMG) recordings and extracting mean-absolute-value-derived (MAV-derived) features. It supports explicit single-channel or bipolar EMG signals, optional trigger-latency correction, artifact marking and rejection, trial-wise waveform baseline correction, binned feature extraction, participant-level standardization, optional condition averaging, and participant-safe cumulative outputs.

The pipeline was adapted and expanded from [`TommasoGhilardi/EMG_Pipelines`](https://github.com/TommasoGhilardi/EMG_Pipelines) and the workflow described by Rutkowska et al. (2024). See [Attribution and third-party material](#attribution-and-third-party-material).

## Validation status and limits

Deterministic tests and representative pipeline runs have been reported passing in MATLAB R2024b. Representative evidence includes Stage 1 runs with variable and median trigger shifting and Stage 0/Stage 2 runs under the explicit channel-selection contract. The test suite also exercises calculations and orchestration with synthetic data and controlled substitutes for selected EEGLAB operations.

This evidence does not establish compatibility with every MATLAB or EEGLAB version, every plugin release, recording layout, or dataset. The lightweight settings and SET provenance fields have also passed their focused MATLAB checks and representative Stage 0, Stage 1, and Stage 2 runs. Review warnings, diagnostics, intermediate SET files, and output tables for every new dataset.

The settings in Stage 0 are examples and configuration interfaces, not universal scientific defaults. In particular, artifact-rejection thresholds must be selected by the researcher for each dataset according to data quality and the research question.

## Requirements

- MATLAB. The recorded validation baseline is MATLAB R2024b; other releases are not claimed as validated.
- [EEGLAB](https://sccn.ucsd.edu/eeglab/) for dataset import, manipulation, epoching, artifact handling, and SET input/output.
- EEGLAB [BIOSIG](https://eeglab.org/others/EEGLAB_Extensions.html) plugin for BDF import in Stage 1.
- EEGLAB CleanLine plugin when photodiode-based `'variable'` or `'median'` trigger shifting is enabled.
- EEGLAB FIRfilt plugin, providing `pop_eegfiltnew`, when the configured main or notch filtering is enabled.

EEGLAB and its plugins are external dependencies and are not included in this repository. No broad version-compatibility claim is made; record the versions used for each analysis.

## Installation

1. Clone or download this repository.
2. Install MATLAB, EEGLAB, and the plugins required by the processing options you will use.
3. Keep the repository structure intact and open the relevant pipeline script in the MATLAB Editor before running it. The active Editor file is used to locate the project.
4. Configure and run Stage 0 before either later stage.

Do not place participant BDF, SET, FDT, or generated output files under version control. The repository's [`.gitignore`](.gitignore) excludes the conventional pipeline outputs and generated settings files.

## Repository layout

| Path | Purpose |
| --- | --- |
| [`EMG_00_settings.m`](EMG_00_settings.m) | Stage 0: configure, validate, and save settings. |
| [`EMG_01_raw2set_shift_triggers.m`](EMG_01_raw2set_shift_triggers.m) | Stage 1: import BDF recordings, normalize events, optionally shift triggers, and save raw SET datasets. |
| [`EMG_02_preprocessing_feature_extraction.m`](EMG_02_preprocessing_feature_extraction.m) | Stage 2: preprocess EMG and write SET, rejection, and feature outputs. |
| [`validate_settings.m`](validate_settings.m) | Shared stage-specific settings validation. |
| [`shift_triggers.m`](shift_triggers.m) | Fixed and photodiode-based event-latency correction. |
| [`resources/`](resources) | Tracked channel-location resources and ignored generated settings snapshots. |
| [`tests/`](tests) | Deterministic MATLAB tests, controlled substitutes, references, and validation handoffs. |
| [`wiki_drafts/`](wiki_drafts) | Conceptual explanations of implemented behavior and validation boundaries. |
| `raw/` | Ignored Stage 1 SET and trigger-diagnostic outputs; created when absent. |
| `preprocessed/` | Ignored Stage 2 SET checkpoints and rejection statistics; created when absent. |
| `extracted_amplitudes/` | Ignored Stage 2 feature tables; created when absent. |

The source BDF directory and EEGLAB installation remain outside the repository and are configured in Stage 0.

## Configure Stage 0 without publishing private paths

Ordinary users may edit the tracked [`EMG_00_settings.m`](EMG_00_settings.m) directly. In the coordinated public release, replace `'example_study'`, `'EDIT_PATH_TO_RAW_BDF_FILES'`, and `'EDIT_PATH_TO_EEGLAB'` with the study name and local external paths, then review every processing setting in Section 0.2. Do not assume that the example channel indices, trigger codes, timing windows, thresholds, or output names apply to another study.

Maintainers and contributors who need private machine- or study-specific values may instead copy the tracked script to `EMG_00_settings_local.m`, which is already ignored by Git, and edit and run that root-level copy. This is only a private copy of Stage 0; there is no alternate settings loader. Keep it at the repository root so project-root inference remains correct, and manually synchronize any future public Stage 0 changes that are relevant to the private copy.

Both approaches save the same ignored files:

- `resources/preprocessing_settings.mat`, consumed by Stages 1 and 2;
- `resources/preprocessing_settings.txt`, a readable snapshot.

Never commit the ignored local Stage 0 copy or either generated settings file. They can contain private paths and study-specific configuration.

## Workflow

### 1. Stage 0 — settings

Open the tracked or ignored local Stage 0 script in the MATLAB Editor. Edit Section 0.2, then run the complete script, or run Sections 0.1–0.4 once in order. Stage 0:

- derives project-internal paths from the active script;
- creates `raw/`, `preprocessed/`, and `extracted_amplitudes/` only when absent;
- validates the current settings;
- saves the ignored MAT and text settings snapshots in `resources/`.

Rerunning Stage 0 does not delete existing outputs, but later save operations can overwrite files with the same configured names.

### 2. Stage 1 — BDF to raw SET

Open and run [`EMG_01_raw2set_shift_triggers.m`](EMG_01_raw2set_shift_triggers.m). Select one or more BDF files. Stage 1 imports them through BIOSIG, represents event types as exact character vectors, optionally corrects selected event latencies, and saves one raw SET dataset per input file under `raw/`.

The BDF filename stem is the participant ID: `001.bdf` becomes text ID `'001'`. Prefixes and leading zeros are preserved. Filename correctness and uniqueness are the user's responsibility. If another study uses a different naming convention, adapt the documented Stage 1 ID-extraction line while keeping IDs as text.

When trigger shifting is enabled, Stage 1 also writes a participant-level diagnostics MAT file. Photodiode modes leave diagnostic figures open for inspection.

### 3. Stage 2 — preprocessing and feature extraction

Open and run [`EMG_02_preprocessing_feature_extraction.m`](EMG_02_preprocessing_feature_extraction.m). Select the Stage 1 `*_raw.set` files. Depending on the saved settings, Stage 2 can produce:

- preprocessed SET checkpoints in `preprocessed/`, saved before flagged trials are removed for feature estimation;
- a cumulative rejection-statistics CSV in `preprocessed/`, checkpointed after each participant's rejection accounting;
- a cumulative wide feature CSV in `extracted_amplitudes/`, checkpointed after each participant's feature table is complete.

Feature rows use `subject_ID + condition + trial_number + bin` as their composite key. If rejected rows are restored, their identifiers remain present and every MAV-derived value is missing—not zero.

MATLAB sections are non-idempotent: running a processing section twice on the same in-memory dataset can alter the result again. Start with the stage entry section, run sections once in order, and use completion messages as execution cues.

## Scientific configuration responsibility

Before processing a dataset, document and justify at least the channel mode and indices, condition triggers, trigger-shifting method and parameters, filters, resampling, epoch and baseline windows, artifact-rejection thresholds, bin duration, standardization mode, trial averaging, and missing-row policy.

The implemented MAV order is rectification → trial-wise waveform baseline correction → retained-trial binning → post-stimulus-derived standardization → optional averaging. Changing that order or any scientific meaning requires a separate decision and validation; it is not a routine configuration edit.

## Tests

From the repository root in MATLAB R2024b:

```matlab
addpath(pwd);
results = runtests('tests', 'IncludeSubfolders', true);
disp(results);
assertSuccess(results);
```

The tests use synthetic fixtures and temporary outputs; several suites substitute controlled functions for selected EEGLAB behavior. Passing them does not replace a representative run with the intended MATLAB, EEGLAB, plugin, settings, and recording configuration. Relevant acceptance boundaries are documented in the Markdown handoffs under [`tests/`](tests).

## Conceptual documentation

Start with the [knowledge-base index](wiki_drafts/Home.md), then use the focused pages for:

- [project structure and paths](wiki_drafts/Project-Structure-and-Paths.md);
- [EMG channel selection and re-referencing](wiki_drafts/EMG-Channel-Selection-and-Re-referencing.md);
- [event representation and condition labels](wiki_drafts/Event-Representation-and-Condition-Labels.md);
- [trigger shifting and diagnostics](wiki_drafts/Trigger-Shifting-and-Diagnostics.md);
- [MAV processing and standardization](wiki_drafts/MAV-Processing-and-Standardization.md);
- [participant-safe feature outputs](wiki_drafts/Participant-Safe-Feature-Outputs.md).

These pages explain implemented decisions; [`CONCEPTUAL_DECISIONS.md`](CONCEPTUAL_DECISIONS.md) and [`PROJECT_PLAN.md`](PROJECT_PLAN.md) remain the authoritative decision and status records.

## Contributions and issues

Use the repository's [GitHub issue tracker](https://github.com/Fra-Grassi/EMG_preprocessing_pipeline/issues) for reproducible bug reports and focused proposals. Include the MATLAB, EEGLAB, and plugin versions; the pipeline stage; relevant non-sensitive settings; the exact warning or error; and the smallest reproducible example possible. Do not attach participant data or private paths.

Contributions should preserve raw-data safety, avoid silent scientific changes, include focused tests where practical, and explain any effect on outputs or assumptions.

## Attribution and third-party material

This project is adapted and expanded from [`TommasoGhilardi/EMG_Pipelines`](https://github.com/TommasoGhilardi/EMG_Pipelines), which declares CC BY 4.0. The upstream authors do not maintain or endorse this repository. See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) for the upstream article, modification summary, external dependencies, and channel-coordinate provenance.

The supporting article is:

> Rutkowska, J. M., Ghilardi, T., Vacaru, S. V., van Schaik, J. E., Meyer, M., Hunnius, S., & Oostenveld, R. (2024). Optimal processing of surface facial EMG to identify emotional expressions: A data-driven approach. *Behavior Research Methods, 56*, 7331–7344. <https://doi.org/10.3758/s13428-024-02421-4>

For this repository, use [`CITATION.cff`](CITATION.cff). Questions may also be directed to the author contact retained in the script headers: `francesco.grassi@uni-goettingen.de`.

## License

This repository is released under the [Creative Commons Attribution 4.0 International License](LICENSE) (`CC-BY-4.0`) for material the licensor has authority to license. Third-party software and materials retain their own terms; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
