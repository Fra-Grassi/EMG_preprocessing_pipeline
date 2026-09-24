# Project Structure and Paths

The pipeline keeps imported datasets, processed datasets, and extracted EMG measures in separate folders. Your original BDF recordings can stay wherever you normally store them. This page explains where the pipeline looks for files and where to find the results.

## Stage 0 and saved settings

Stage 0 collects your choices in `sets`, MATLAB's name for the collection of settings used by the pipeline. Running Stage 0 checks those choices and saves two files in `resources/`:

- `preprocessing_settings.mat`, which Stages 1 and 2 read;
- `preprocessing_settings.txt`, a readable copy you can consult without loading the MATLAB file.

The saved settings also include when they were created and information about the software environment. Keep these files with your analysis records: they help you check which settings you saved. They may contain local paths and study information, so review them before sharing.

Editing the Stage 0 script alone does not update the settings that later stages use. **Run Stage 0 again after changing a setting.** Do the same after updating the pipeline: older development settings are not updated automatically.

## How the project directory is located

Keep the stage you are running open and active in the MATLAB Editor. The pipeline uses that script's location to find its folders. This avoids relying on MATLAB's current working directory, which can differ when you run individual sections.

You can therefore move the pipeline folder as a whole without rewriting its internal file paths. The locations of your BDF recordings and EEGLAB installation still need to be set for the computer you are using. This way of locating the project has been tested in MATLAB R2024b; later versions have not yet been confirmed.

## Where files are saved

| Folder | What you will find there |
| --- | --- |
| `raw/` | The EEGLAB SET files imported by Stage 1, plus trigger-shifting diagnostics when requested. |
| `preprocessed/` | Processed SET files for inspection and the optional trial-rejection table. |
| `extracted_amplitudes/` | The cumulative table of extracted EMG measures. |
| `resources/` | Channel-location files supplied with the pipeline and the settings saved by Stage 0. |

Stage 0 creates the three output folders if they do not exist. It leaves existing files in place. The `resources/` folder must already be present because it contains files the pipeline needs.

Later saving steps **can replace files with the same names**. There is no automatic archive of earlier results. Before processing another group of participants or trying a different configuration, choose suitable output filenames or preserve the previous files elsewhere.

## Locating recordings and EEGLAB

In Stage 0, set the paths to your BDF recordings and your EEGLAB installation. Neither needs to be inside the pipeline folder.

The input folder is also the starting point for the file-selection dialog. Stage 1 initially looks in your configured BDF folder; Stage 2 initially looks in `raw/`. You can browse elsewhere, and the pipeline will use the files you actually select. Cancelling the dialog stops the run before processing participants. If you are running sections manually, stop after cancelling and make a new selection before continuing.

## File selection and participant names

Stage 1 takes the participant ID from the BDF filename without its extension:

```text
001.bdf → '001'
```

It saves that ID as text in the dataset's subject field (`EMG.subject`). Stage 2 reads the saved ID, so renaming a SET file does not change the participant's identity. Prefixes and leading zeros are preserved.

Check that your filenames give each participant the intended, unique ID. The pipeline does not detect empty or duplicate IDs. If your naming convention needs more than removing `.bdf`, adapt the ID-extraction line in Stage 1, keeping the result as text.

There is one related detail if you customise output names: changing the raw SET suffix from `_raw` also requires changing Stage 2's `*_raw.set` file-selection filter, which determines which filenames it offers.

## Complete scripts and individual sections

You can run each stage as a complete script or use MATLAB's sections to pause and inspect intermediate results. A section is a block of code beginning with `%%` in the Editor.

Running the complete script starts with setup and proceeds in order. Running a section executes only that block; it assumes that earlier sections have already prepared the settings and data. Begin with setup and run each section once, following the completion messages.

Repeating a processing section acts on the data currently in memory. For example, it may filter an already filtered signal or add condition events a second time. If an interrupted run leaves you unsure of the current state, restart the stage from the beginning with its input data. After changing settings, rerun Stage 0 and restart the affected processing stage rather than continuing partway through.
