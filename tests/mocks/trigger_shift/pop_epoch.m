function [EEG, accepted] = pop_epoch(EEG, types, window, varargin)
% Accepted positions intentionally refer to candidates, not original events.
global TRIGGER_SHIFT_TEST
options = struct(varargin{:});
TRIGGER_SHIFT_TEST.requested_indices = options.eventindices;
TRIGGER_SHIFT_TEST.requested_types = types;
TRIGGER_SHIFT_TEST.sorted_types = {EEG.event.type};
EEG.times = TRIGGER_SHIFT_TEST.times;
EEG.data = reshape(TRIGGER_SHIFT_TEST.data', 1, numel(EEG.times), []);
EEG.trials = size(TRIGGER_SHIFT_TEST.data, 1);
EEG.pnts = numel(EEG.times);
accepted = TRIGGER_SHIFT_TEST.accepted;
end
