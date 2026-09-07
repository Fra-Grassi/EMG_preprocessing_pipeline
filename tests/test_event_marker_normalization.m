function tests = test_event_marker_normalization
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
tests_dir = fileparts(mfilename('fullpath'));
project_dir = fileparts(tests_dir);
testCase.TestData.original_path = path;
addpath(project_dir);
end

function teardownOnce(testCase)
path(testCase.TestData.original_path);
end

function testNumericMarkerBecomesCharacter(testCase)
EEG = marker_fixture({121});

normalized_EEG = fix_EEG_markers(EEG);

verifyEqual(testCase, normalized_EEG.event.type, '121');
verifyTrue(testCase, ischar(normalized_EEG.event.type));
verifyTrue(testCase, isrow(normalized_EEG.event.type));
end

function testCharacterAndStringMarkersNormalize(testCase)
EEG = marker_fixture({'121', "121", "S 121"});

normalized_EEG = fix_EEG_markers(EEG);

verifyEqual(testCase, {normalized_EEG.event.type}, {'121', '121', 'S 121'});
verifyTrue(testCase, ischar(normalized_EEG.event(1).type));
verifyTrue(testCase, ischar(normalized_EEG.event(2).type));
verifyTrue(testCase, ischar(normalized_EEG.event(3).type));
end

function testEncodedCharacterContentRemainsUnchanged(testCase)
original_types = {'S 121', 'S121', '001', 'boundary', 'condition_a'};
EEG = marker_fixture(original_types);

normalized_EEG = fix_EEG_markers(EEG);

verifyEqual(testCase, {normalized_EEG.event.type}, original_types);
end

function testEverySupportedOutputTypeIsACharacterVector(testCase)
EEG = marker_fixture({121, '121', "121", 'S 121', 'S121', '001', 'boundary'});

normalized_EEG = fix_EEG_markers(EEG);

for i = 1:numel(normalized_EEG.event)
    verifyTrue(testCase, ischar(normalized_EEG.event(i).type));
    verifyTrue(testCase, isrow(normalized_EEG.event(i).type));
end
end

function testUnrelatedEventFieldsRemainUnchanged(testCase)
EEG = marker_fixture({121, "S 121", 'boundary'});
events_before_normalization = EEG.event;
original_field_names = fieldnames(events_before_normalization);

normalized_EEG = fix_EEG_markers(EEG);

verifyEqual(testCase, fieldnames(normalized_EEG.event), original_field_names);
verifyEqual(testCase, rmfield(normalized_EEG.event, 'type'), ...
    rmfield(events_before_normalization, 'type'));
end

function testCompletionMessage(testCase)
EEG = marker_fixture({121});

output_text = evalc('fix_EEG_markers(EEG);');

verifyEqual(testCase, output_text, ...
    sprintf('\nAll event markers have been converted to char\n\n'));
end

function EEG = marker_fixture(event_types)
n_events = numel(event_types);
event_template = struct( ...
    'type', '', ...
    'latency', 0, ...
    'duration', 0, ...
    'urevent', 0, ...
    'custom_label', '');
events = repmat(event_template, 1, n_events);

for i = 1:n_events
    events(i).type = event_types{i};
    events(i).latency = i * 101.5;
    events(i).duration = i - 1;
    events(i).urevent = n_events - i + 1;
    events(i).custom_label = sprintf('event_%d', i);
end

EEG = struct('event', events);
end
