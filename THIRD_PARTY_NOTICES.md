# Third-Party Notices and Attribution

This file records upstream sources, external dependencies, and bundled-resource provenance for the EMG Preprocessing Pipeline. It does not replace the license terms supplied by the original rights holders.

## Upstream EMG pipeline and article

This project is adapted and expanded from [`TommasoGhilardi/EMG_Pipelines`](https://github.com/TommasoGhilardi/EMG_Pipelines), which declares the Creative Commons Attribution 4.0 International license (`CC BY 4.0`).

The related publication is:

> Rutkowska, J. M., Ghilardi, T., Vacaru, S. V., van Schaik, J. E., Meyer, M., Hunnius, S., & Oostenveld, R. (2024). Optimal processing of surface facial EMG to identify emotional expressions: A data-driven approach. *Behavior Research Methods, 56*, 7331–7344. <https://doi.org/10.3758/s13428-024-02421-4>

Substantial repository-specific modifications include removal of the earlier dyad-oriented data model; reproducible project-root and settings validation; exact character event handling; tested fixed, trial-specific, and participant-median trigger correction with diagnostics; explicit single and bipolar EMG channel handling; participant-safe output keys and checkpoints; corrected and deterministically tested MAV baseline, binning, standardization, and missing-row behavior; and lightweight settings and SET provenance metadata.

These modifications are maintained in this repository. They do not imply that the upstream repository authors or publication authors maintain, approve, or endorse this project.

## EEGLAB and plugins

MATLAB, EEGLAB, BIOSIG, CleanLine, FIRfilt, and any other EEGLAB plugins are external dependencies. They are not redistributed in this repository and retain their own copyright notices and license terms. Users are responsible for obtaining compatible installations and complying with those terms.

## BioSemi coordinate-derived resources

The bundled files [`resources/chanloc_biosemi_64.elp`](resources/chanloc_biosemi_64.elp) and [`resources/chanloc_biosemi_128.ced`](resources/chanloc_biosemi_128.ced) were generated internally by converting coordinate information from BioSemi's general workbook [`Cap_coords_all.xls`](http://www.biosemi.com/download/Cap_coords_all.xls) into repository-specific, EEGLAB-compatible forms.

BioSemi's [headcap page](https://www.biosemi.com/headcap.htm) describes the electrode-position coordinates of its standard headcaps as downloadable and links to the general workbook. BioSemi has not been represented here as licensing that workbook under CC BY 4.0, and BioSemi does not endorse this repository.

The repository maintainer treats these internally generated format conversions as project resources covered by the repository's CC BY 4.0 license. The BioSemi link is retained to document the source of the underlying coordinate values; users are not asked to cite BioSemi separately when using these converted files.
