# Event Codes and Condition Labels

To extract epochs, the pipeline needs to know which event codes mark your events of interest. Stage 0 is where you associate those codes with condition names. Getting this correspondence right matters: the pipeline can match the codes you provide, but it cannot determine what they meant in your experiment.

## How imported event codes are stored

After importing a BDF file, Stage 1 stores event codes as text. In MATLAB, the form used here is called a *character vector* and is written with single quotes, such as `'121'`.

This conversion accommodates recordings whose event codes arrive as numbers or different types of text:

| Imported value | Value used by the pipeline |
| --- | --- |
| Number `121` | `'121'` |
| Text `'121'` or `"121"` | `'121'` |
| `'S 121'` | `'S 121'` |
| `'S121'` | `'S121'` |

Existing text is kept exactly as recorded. Spaces, prefixes, and leading zeros remain, so `'001'` stays `'001'`. Named events such as `'boundary'` also keep their names. Only the way MATLAB stores the code changes; the event's timing and other information remain untouched.

## Matching codes to conditions

Enter your codes in `sets.condition_triggers` and the corresponding names in `sets.condition_names`. For example:

```matlab
sets.condition_triggers = {'121', '221'};
sets.condition_names = {'condition_A', 'condition_B'};
```

The first code belongs to the first name, the second code to the second name, and so on. The names in this example are placeholders for your conditions.

**Matching is exact.** `'121'`, `'S121'`, and `'S 121'` are three different codes. The pipeline does not remove Brain Vision-style prefixes or spaces to make them match. Before processing a new study, inspect the imported event codes and reproduce them exactly in Stage 0, using single quotes.

The same rule applies when choosing which markers to use for [trigger shifting](Trigger-Shifting-and-Diagnostics.md).

## What happens to the events in Stage 2

For each matching trigger, Stage 2 adds a copy of that event and gives the copy your condition name. For example, an event named `'121'` gets a corresponding event named `'condition_A'` at the same time. The original trigger is still present at this point.

The copy keeps the original event's latency and other associated information. EEGLAB then checks the event list for consistency. These named copies are the events used to time-lock the epochs; renaming a copy does not shift the epoch's reference time.

This explains why you may see both a trigger code and a condition name at the same latency when inspecting the events after this step.

## Run each section once

If you run Stage 2 one section at a time, execute each section once and in order, beginning with setup. Repeating the condition-label section adds another set of copies. Likewise, repeating a later processing section can apply filtering or baseline correction again to data that have already been processed.

Use the completion messages to keep track of where you are. If you are unsure which steps have run, restart the stage from the beginning with the input dataset rather than continuing with uncertain intermediate results. [Project Structure and Paths](Project-Structure-and-Paths.md#complete-scripts-and-individual-sections) explains section execution in more detail.

Automated MATLAB tests check the event-code conversion and condition copies, including spaces, prefixes, leading zeros, and preservation of timing information. They do not check that your chosen codes identify the intended events in your study.
