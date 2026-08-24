% shift_triggers() - Shift EEG triggers by a constant or variable delay.
%
%   EEGout = shift_triggers(EEGin, epoch_trigger, trigger_shift, ...)
%   shifts triggers in the EEG data either by a constant delay or by a
%   variable delay based on changes detected in a photodiode signal.
%
%   INPUTS:
%       - EEGin: Input EEG dataset structure (EEGLab format).
%       - epoch_trigger: Array of trigger types to be shifted (e.g., [1, 2]).
%       - trigger_shift: Specifies the shift type:
%           * 'variable': Uses a photodiode signal to determine the delay
%                         (requires the 'epoch_window' input).
%           * Numeric value: Constant delay in milliseconds to shift all
%                           specified triggers.
%       - epoch_window (optional): A 2-element vector [start, end] in seconds,
%                                 specifying the time window around triggers
%                                 for photodiode analysis. Required when
%                                 'trigger_shift' is set to 'variable'.
%       - signal_threshold (optional): Numeric value indicating the
%                                      proportion of the photodiode signal
%                                      range to consider as proper
%                                      response. Defaults to 4, meaning
%                                      1/4 of the signal range.
%
%   OUTPUT:
%       - EEGout: Output EEG dataset structure with updated trigger latencies.
%
%   USAGE:
%       % Constant delay of 10 ms:
%       EEGout = shift_triggers(EEGin, [1, 2], 10);
%
%       % Variable delay using photodiode signal, default threshold:
%       EEGout = shift_triggers(EEGin, [1, 2], 'variable', [-0.2, 0.8]);
%
%       % Variable delay using photodiode signal, custom threshold:
%       EEGout = shift_triggers(EEGin, [1, 2], 'variable', [-0.2, 0.8], 5);
%
%   NOTES:
%       - The function processes the photodiode channel ('Erg1'/'photodiode') for variable
%         delay calculation. Ensure this channel exists in your dataset.
%       - For constant shifts, the delay is applied uniformly to all specified
%         triggers.
%       - If photodiode_threshold is provided, it adjusts the proportion
%         of the photodiode range considered as response (e.g., 5 means
%         1/5th of the range).
%
%   See also: pop_epoch, pop_rmbase, pop_cleanline
%
% Author: Annika Ziereis, annika.ziereis@uni-goettingen.de
% Modified by: Francesco Grassi, francesco.grassi@uni-goettingen.de

function EEGout = shift_triggers(EEGin, epoch_trigger, trigger_shift, varargin)

    % Convert triggers to char
    % (both for using with 'pop_epoch()' and to deal with EEG.event.type stored as char).
    epochtriggerstringarray = arrayfun(@num2str, epoch_trigger, 'UniformOutput', 0);

    % varargin to handle optional inputs like epoch_window
    if ischar(trigger_shift) && strcmp(trigger_shift, 'variable')
        % Check for optional 'epoch_window' input
        if nargin < 4 || isempty(varargin{1})
            error('When trigger_shift is "variable", the epoch_window input is required.');
        end
        epoch_window = varargin{1};

        % Set photodiode threshold (default is 4, corresponding to 1/4 of the range)
        if nargin < 5 || isempty(varargin{2})
            signal_threshold = 4;
        else
            signal_threshold = varargin{2};
        end
        
        % Process for variable delay using photodiode signal
        samplingrate = EEGin.srate;
        
        % Get photodiode array
        % - For BioSemi: channel 'Erg1'
        % - For Brain Vision: channel 'photodiode'
        if ismember('Erg1', {EEGin.chanlocs.labels})
            photodiode_chan = {'Erg1'};
        elseif ismember('photodiode', {EEGin.chanlocs.labels})
            photodiode_chan = {'photodiode'};
        end
        diode = pop_select(EEGin, 'channel', photodiode_chan);
        
        % Reduce 50Hz noise
        diode = pop_cleanline(diode, 'bandwidth', 2, 'chanlist', 1, ...
            'computepower', 0, 'linefreqs', 50, 'newversion', 0, ...
            'normSpectrum', 0, 'p', 0.01, 'pad', 2, 'plotfigures', 0, ...
            'scanforlines', 1, 'sigtype', 'Channels', 'taperbandwidth', 2, ...
            'tau', 100, 'verb', 1, 'winsize', 4, 'winstep', 2);
        
        % Epoch around diode stimulus onset
        diode = pop_epoch(diode, epochtriggerstringarray, epoch_window, 'epochinfo', 'yes');
        diode = pop_rmbase(diode, [-29 0] ,[]);
        diode.data = abs(diode.data);
        diode = pop_rmbase(diode, [-29 0] ,[]);
        diode = eeg_checkset(diode);
        
        % For comparison
        diodebefore = pop_epoch(diode, epochtriggerstringarray, epoch_window, 'epochinfo', 'yes');
        diodedat2plotbefore = permute(diodebefore.data(1,:,:), [2,3,1]);
        
        % Shift triggers based on detected delays
        delays = [];
        for trial = 1:length(diode.data(1,1,:))
            tp0 = find(diode.times == 0);
            thistrial = diode.data(1,tp0:end, trial);
            threshold = range(thistrial)/signal_threshold;
            above_threshold = (thistrial >= threshold);
            minAcceptableLength = 10; % arbitrary
            % Find spans that are long enough.
            isLongEnough = bwareafilt(above_threshold, [minAcceptableLength, inf]);
            idx = find(isLongEnough == 1, 1);
            delays(end+1) = diode.times(tp0+idx);
        end
        
        uniquedelays = unique(delays);
        fprintf('Delay range: %d ms', round(range(uniquedelays), 1));
        
        for index = 1 : length(diode.event)
            thistrialhelper = 0;
            % Only shift visual stimuli (here epoch_trigger)
            % (These can be either numerical or char)
            if ismember(diode.event(index).type, epoch_trigger) || ...
                    ismember(diode.event(index).type, epochtriggerstringarray)
                thistrialhelper = thistrialhelper + 1 ;
                thisdelay = delays(thistrialhelper);
                shift = ceil((samplingrate/1000)*thisdelay);
                diode.event(index).latency = diode.event(index).latency + shift;
            end

        end
        
        diodeafter = pop_epoch( diode, epochtriggerstringarray, [-0.02 0.02], 'epochinfo', 'yes');
        diodedat2plot = permute(diodeafter.data(1,:,:),[2,3,1]);
        
        % Plot photodiode data before and after shifting triggers
        figure;
        subplot(2,1,1);
        plot(diodebefore.times, diodedat2plotbefore,'k', 'Color',[0 0.5 0 0.3]);
        subplot(2,1,2);
        plot(diodeafter.times, diodedat2plot,'k','Color',[0.5 0 0 0.3]); hold on ; grid on; grid minor; title('photodiode epoched');
        hold off;

        % Now change EEG triggers (careful: it's the continuous dataset)
        for index = 1 : length(EEGin.event)
            thistrialhelper = 0;
            if ismember(EEGin.event(index).type, epoch_trigger) || ...
                    ismember(EEGin.event(index).type, epochtriggerstringarray)
                thistrialhelper = thistrialhelper + 1 ;
                thisdelay = delays(thistrialhelper);
                shift = ceil((samplingrate/1000)*thisdelay);
                EEGin.event(index).latency = EEGin.event(index).latency + shift;
            end

        end
        
        disp('Visual stimulus trigger shifted by variable value');

    elseif isnumeric(trigger_shift)
        % Constant delay shift
        samplingrate = EEGin.srate;
        shift = ceil((samplingrate/1000)*trigger_shift);
        for i = 1:length(EEGin.event)
            % (Events might be either numeric or char)
            if ismember(EEGin.event(i).type, epoch_trigger) || ...
                    ismember(EEGin.event(i).type, epochtriggerstringarray)               
                EEGin.event(i).latency = EEGin.event(i).latency + shift;
            end
        end
        disp('Visual stimulus trigger shifted by fixed value');
    else
        error('Invalid value for trigger_shift. Use "variable" or a numeric value.');
    end
    
    EEGout = EEGin;

end