# Review Notes for Agent 0 and the Researcher

This file records inconsistencies and ambiguities encountered while tracing the wiki drafts to the decision ledger, planning record, production code, and tests. It does not resolve them or propose new pipeline behavior.

## 1. Coordination-document header baselines are older than their event-validation content

- **Files and sections:** [CONCEPTUAL_DECISIONS.md, header](../CONCEPTUAL_DECISIONS.md); [PROJECT_PLAN.md, header and Validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Decision IDs:** CD-11 and CD-12.
- **What is unclear:** Both headers say they were last updated on 2026-08-31 and apply to commit `f93f00a`, but both documents now include the later Tier 1.1 event-handling integration; `PROJECT_PLAN.md` also records its validation on 2026-09-07. The assigned wiki baseline is commit `3786055` (`Record validated event handling integration`).
- **Why it matters:** A reader could conclude that the authoritative documents do not cover the event-handling implementation they now describe.
- **Question:** Should the header date and validated-baseline commit in both coordination documents be updated to the event-integration baseline, or are the older values intended to refer only to the MAV validation baseline?

## 2. A deferred-decision bullet can be read as contradicting the approved event contract

- **File and section:** [CONCEPTUAL_DECISIONS.md, Decisions intentionally deferred](../CONCEPTUAL_DECISIONS.md#decisions-intentionally-deferred).
- **Decision ID:** CD-11.
- **What is unclear:** The deferred list includes “a canonical event-marker representation across acquisition systems,” while CD-11 now requires all supported event types to use MATLAB character vectors and precisely defines preservation of acquisition-specific encoded content. “Canonical representation” may mean either the now-settled MATLAB data type or a still-deferred cross-system semantic mapping.
- **Why it matters:** Future documentation could incorrectly state either that the character-vector contract remains unresolved or that acquisition-specific encodings are intended to be normalized to one common value.
- **Question:** Does this deferred item refer specifically to a possible semantic mapping across acquisition systems, distinct from the implemented character-vector representation in CD-11?

## 3. The Stage 1 feature header still says events are converted from string to numeric

- **File and section:** [`EMG_01_raw2set_shift_triggers.m`, header “Features” list](../EMG_01_raw2set_shift_triggers.m).
- **Decision ID:** CD-11.
- **What appears inconsistent:** The header says “Conversion of events from string to numeric,” but Section 1.3.2 and [`fix_EEG_markers.m`](../fix_EEG_markers.m) convert numeric and string event types to character vectors while preserving existing character content.
- **Why it matters:** This is a user-visible comment in the Stage 1 entry script and describes the opposite representation from the validated contract.
- **Question:** May the Stage 1 header be corrected in a later code-documentation cleanup commit to describe character-vector conversion?

## 4. Trigger-shift marker comments still describe numeric trigger configuration

- **Files and sections:** [`EMG_00_settings.m`, Trigger shift](../EMG_00_settings.m); [`shift_triggers.m`, inputs and trigger conversion](../shift_triggers.m); [PROJECT_PLAN.md, Tier 1.2](../PROJECT_PLAN.md#12-correct-and-test-trigger-shifting).
- **Decision ID:** No trigger-shifting decision ID exists; CD-11 governs event representation.
- **What is unclear:** Stage 0 describes `sets.shift_markers` as a numeric vector, while condition triggers are now configured as character vectors under CD-11. The current trigger-shifting function still contains mixed numeric/character conversion and comparison paths. Tier 1.2 explicitly leaves trigger shifting unresolved.
- **Why it matters:** A user could infer a finalized trigger-marker input contract from comments even though the scientific and engineering behavior is pending review.
- **Question:** Until the trigger-shifting contract is approved, should these comments be explicitly labeled as legacy/pending rather than read as settled configuration guidance?

## 5. The plan still lists marker-normalization tests as future Tier 2 work

- **File and section:** [PROJECT_PLAN.md, Tier 2.2](../PROJECT_PLAN.md#22-expand-regression-coverage-beyond-mav), compared with [Tier 1.1](../PROJECT_PLAN.md#11-normalize-event-types-and-condition-matching) and the [Validation baseline](../PROJECT_PLAN.md#validation-baseline).
- **Decision ID:** CD-11.
- **What appears inconsistent:** Tier 2.2 says to add tests for marker normalization, but [`tests/test_event_marker_normalization.m`](../tests/test_event_marker_normalization.m) exists and Tier 1.1 records those deterministic tests as completed and validated.
- **Why it matters:** The plan gives conflicting status for an already integrated test area.
- **Question:** Is the Tier 2 item intended to request additional integration coverage beyond the existing deterministic marker-normalization test, or is “marker normalization” obsolete in that list?

## 6. The production baseline-correction block recognizes `none`, but output naming does not

- **Files and sections:** [`EMG_02_preprocessing_feature_extraction.m`, Sections 2.4.9 and 2.4.13](../EMG_02_preprocessing_feature_extraction.m); [`EMG_00_settings.m`, Baseline correction](../EMG_00_settings.m); [`apply_mav_baseline_correction.m`](../tests/helpers/apply_mav_baseline_correction.m).
- **Decision IDs:** CD-05 and CD-09.
- **What is unclear:** The Stage 2 correction block recognizes a method named `none`, matching the test helper, but Stage 0 documents only `subtraction` and `division`. Later Stage 2 output naming treats raw output only as `do_baseline_correction == 0` and errors on any enabled method other than subtraction or division.
- **Why it matters:** It is ambiguous whether `none` is intended as a valid production method, a test-helper convenience, or obsolete inline reference logic. The wiki therefore describes the no-correction state only as baseline correction being disabled.
- **Question:** Is the `none` branch in the enabled production correction block intentionally retained, or should only the disabled toggle represent no baseline correction?
