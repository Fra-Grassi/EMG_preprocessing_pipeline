function [corrected_events, diagnostics] = apply_trigger_delays_reference( ...
        events, target_types, delay_ms, srate, target_event_indices)
%APPLY_TRIGGER_DELAYS_REFERENCE Test-only latency application under CD-13.
%   EVENTS is a plain struct vector with character-row type and finite double
%   scalar latency (samples) fields. Other fields are copied unchanged.
%   TARGET_TYPES is a cell vector of character rows, matched exactly.
%   Four arguments: DELAY_MS must be scalar; shift every matching event.
%   Five arguments: DELAY_MS(k) belongs to EVENTS(TARGET_EVENT_INDICES(k)).
%   The mapping must identify every matching target exactly once, in any
%   supplied order. A scalar is NOT broadcast in this mapped form.
%   Mapping identity must be established by the caller from epoch provenance;
%   equal counts and matching types cannot prove scientific correspondence.
%   Incomplete mappings are rejected as outside this reference's precondition;
%   this does not select a production policy for omitted boundary epochs.
%
%   CD-13: offset = round(delay_ms * srate / 1000), ties away from zero;
%   corrected latency = original latency + offset. Only offsets are rounded.
%   DIAGNOSTICS is a separate table, ordered by the supplied mapping (or event
%   order in fixed mode). No fields are added to EVENTS. No sorting, clipping,
%   epoch processing, or dataset-boundary policy is performed here.

if ~isstruct(events) || (~isvector(events) && ~isempty(events)) || ...
        ~all(isfield(events, {'type', 'latency'}))
    error('apply_trigger_delays_reference:InvalidEvents', ...
        'events must be a struct vector with type and latency fields.');
end
if ~iscell(target_types) || (~isvector(target_types) && ~isempty(target_types)) || ...
        ~all(cellfun(@(x) ischar(x) && isrow(x), target_types))
    error('apply_trigger_delays_reference:InvalidTargets', ...
        'target_types must be a cell vector of character rows.');
end
validateattributes(srate, {'double'}, {'real', 'finite', 'scalar', 'positive'});
validateattributes(delay_ms, {'double'}, {'real', 'finite'});
if ~isvector(delay_ms) && ~isempty(delay_ms)
    error('apply_trigger_delays_reference:InvalidDelays', ...
        'delay_ms must be scalar or a vector.');
end

is_target = false(numel(events), 1);
for event_index = 1:numel(events)
    if ~ischar(events(event_index).type) || ~isrow(events(event_index).type)
        error('apply_trigger_delays_reference:InvalidEvents', ...
            'Event types must be character rows under CD-11.');
    end
    validateattributes(events(event_index).latency, {'double'}, ...
        {'real', 'finite', 'scalar'});
    is_target(event_index) = any(strcmp(events(event_index).type, target_types));
end
matched_indices = find(is_target);

if nargin == 4
    if ~isscalar(delay_ms)
        error('apply_trigger_delays_reference:MappingRequired', ...
            'Trial-specific delays require explicit target_event_indices.');
    end
    target_event_indices = matched_indices;
    delays = repmat(delay_ms, numel(matched_indices), 1);
else
    if ~isnumeric(target_event_indices) || ~isreal(target_event_indices) || ...
            (~isvector(target_event_indices) && ~isempty(target_event_indices))
        error('apply_trigger_delays_reference:InvalidMapping', ...
            'Mapping must be a vector of event indices.');
    end
    target_event_indices = double(target_event_indices(:));
    if any(~isfinite(target_event_indices)) || ...
            any(target_event_indices ~= fix(target_event_indices)) || ...
            any(target_event_indices < 1 | target_event_indices > numel(events)) || ...
            numel(unique(target_event_indices)) ~= numel(target_event_indices)
        error('apply_trigger_delays_reference:InvalidMapping', ...
            'Mapping indices must be valid and unique.');
    end
    if numel(delay_ms) ~= numel(target_event_indices)
        error('apply_trigger_delays_reference:CountMismatch', ...
            'Provide exactly one delay per mapped event; no scalar broadcast.');
    end
    if ~isequal(sort(target_event_indices), matched_indices)
        error('apply_trigger_delays_reference:TargetMappingMismatch', ...
            'Mapping must cover exactly the selected target events.');
    end
    delays = delay_ms(:);
end

original_latency = reshape([events(target_event_indices).latency], [], 1);
sample_offset = round(delays * srate / 1000);
corrected_latency = original_latency + sample_offset;
validateattributes(corrected_latency, {'double'}, {'finite'});
event_type = reshape({events(target_event_indices).type}, [], 1);
diagnostics = table(target_event_indices, event_type, delays, ...
    original_latency, sample_offset, corrected_latency, 'VariableNames', ...
    {'event_index', 'event_type', 'delay_ms', 'original_latency', ...
    'sample_offset', 'corrected_latency'});

% All count, mapping and numerical checks precede output event mutation.
corrected_events = events;
for mapping_row = 1:numel(target_event_indices)
    corrected_events(target_event_indices(mapping_row)).latency = ...
        corrected_latency(mapping_row);
end
end
