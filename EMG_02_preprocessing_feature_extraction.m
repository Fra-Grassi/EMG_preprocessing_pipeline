% ---------------------------------------------------------------------------------------------------------------------
% EMG Preprocessing Pipeline
% Version: 2
% author: Francesco Grassi
% date: August 2026
%
% For questions or issues, contact:
% francesco.grassi@uni-goettingen.de
%
% ---------------------------------------------------------------------------------------------------------------------
% 
% ++++ EMG_02_preprocessing_feature_extraction ++++
%
% This is a modified version of the original pipeline recommended by Rutkowska et al., 2024
% (https://github.com/TommasoGhilardi/EMG_Pipelines).
% - Baseline correction
%   Baseline correction algorithm is modified to be able to handle arbitrary portions of the pre-stimulus baseline
%   (e.g., from -3 to -2 s).
%
% Features:
%   1. Filtering
%   2. Downsampling
%   3. Signal rectification
%   4. Epoch extraction
%   5. Artefact detection and rejection
%   6. Trial-wise waveform baseline correction
%   7. Feature extraction by bins
%   8. Within-muscle or within-subject feature standardization
%   9. Trial averaging
% (See Rutkowska et al., 20204, for details)
%
% Additional Features:
% - Output data maintains original trial number (as before trial rejection).
% - Output retains both baseline-corrected and standardized feature values.
%
% Usage:
% 1. Run the script to select raw SET files (of individual participants) for processing.
%
% Requirements:
% - MATLAB
% - EEGLab Toolbox
%
% Output:
% - Processed SET files in the specified output directory.
% - Extracted features.
% - Log of rejected artefacts.
%
%% 2.1 - Toolboxes

clearvars

% Load preprocessing parameters
project_dir = fileparts(matlab.desktop.editor.getActiveFilename);
settings_file = fullfile(project_dir, 'resources', 'preprocessing_settings.mat');
load(settings_file, 'sets');

addpath(sets.eeglab_dir)  % EEGLab

eeglab; close all;  % start EEGLab and close popup windows

%% 2.2 - Select input data

% Select one or multiple raw SET datasets to process
% (datasets created in 'EMG_01_raw2set_shift_triggers.m')

[file, thissubjectpath] = uigetfile(fullfile(sets.rawSET_dir, '*_raw.set'), 'MultiSelect', 'on');  % show gui to select files

% Ensure the file names are stored as a cell array even when only one file is selected
if ischar(file)
    file = {file};
end

%% 2.3 - Prepare output variables

% Preallocate one table per participant. Each table is stored only after the
% participant has completed preprocessing and feature-table validation.
participant_feature_tables = cell(length(file), 1);

% If performing artefact detection, preallocate a cell array to store info on rejected trials.
% Array has one row per participant, with colums for:
% - Subject ID
% - Number of rejected trials across all conditions
% - Percentage of rejected trials across all conditions
% - One column with number of rejected trials per condition
% - One column with percentage of rejected trials per condition
if sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual
    reject_info = cell(length(file), 3 + length(sets.condition_names) * 2);
end

fprintf('\nOutput variables CREATED\n\n');

%% 2.4 - Main loop

% Loop through all selected dataset and apply preprocessing steps
for si = 1:length(file)
    
    %% 2.4.1 - Load dataset
    
    EMG = pop_loadset('filename', file{si}, 'filepath', sets.rawSET_dir);
    EMG_bkp = EMG;  % temporary for debugging
    
    fprintf('\nDataset loading COMPLETE\n\n');

    % Extract Subject ID
    subj_ID = EMG.subject;

    %% 2.4.2 - Add events with condition names
    % (These are added at same latency as the punchline triggers)

    n_event = length(EMG.event);  % get original event number
    for ev = 1:n_event
        for trigger = 1:length(sets.condition_triggers)
            % Check if event matches the corresponding character trigger
            if strcmp(EMG.event(ev).type, sets.condition_triggers{trigger})
                
                EMG.event(end+1) = EMG.event(ev);  % copy event at the end of the list
                EMG.event(end).latency = EMG.event(ev).latency;  % ensure it has same latency as trigger event
                EMG.event(end).type = sets.condition_names{trigger};  % add condition name
                
            end
        end
    end
    
    EMG = eeg_checkset(EMG, 'eventconsistency');     % check all events for consistency

    fprintf('\n\nAdding condition events COMPLETE\n');
    
    %% 2.4.3 - Channel selection and re-referencing
    % Extract only EMG channels.
    % If data contains two channels per muscle (BioSemi format), also re-reference channels,
    % i.e, subtract one channel from the other within each muscle pair (Ch1 - Ch2)
    
    % Check if EMG channels are in BioSemi format (one row per muscle)
    if size(sets.emg_channel_numbers, 1) > 1
        % Preallocate matrix to store re-referenced data
        reref_data = zeros(length(sets.emg_channel_names), size(EMG.data,2));
        
        % For each indicated muscle, subtract channels
        for i = 1:length(sets.emg_channel_names)
            reref_data(i, :) = EMG.data(sets.emg_channel_numbers(i, 1), :) - EMG.data(sets.emg_channel_numbers(i, 2), :);
        end
        
        % Assign re-referenced data back to EMG struct
        EMG.data = reref_data;
    else
        % If not in BioSemi format (only one row, one element per muscle), just extract EMG channels
        EMG.data = EMG.data(sets.emg_channel_numbers, :);
    end

    % Update channel number and labels
    EMG.nbchan = length(sets.emg_channel_names);

    if ~isempty(EMG.chanlocs)
        EMG.chanlocs = EMG.chanlocs(1:length(sets.emg_channel_names));
        for i = 1:length(sets.emg_channel_names)
            EMG.chanlocs(i).labels = sets.emg_channel_names{i};
        end
    end
    
    fprintf('\nChannel re-referencing COMPLETE\n\n');
    
    %% 2.4.4 - Filtering
    
    % Always remove DC offset
    EMG = pop_rmbase(EMG, [], []);
    
    % Check if main filter is on
    if sets.do_filtering_main
        
        % Based on the type of filter, assign cutoffs
        if strcmp(sets.filter_type_main, 'bandpass')
            % if bandpass, use the specified low- and high-cutoff
            low_cutoff = sets.filter_cutoff_main(1);  % lower edge of pass band
            high_cutoff = sets.filter_cutoff_main(2);  % higher edge of pass bad
        elseif strcmp(sets.filter_type_main, 'highpass')
            % if highpass, set lower edge to specified cutoff and no higher edge
            low_cutoff = sets.filter_cutoff_main;
            high_cutoff = [];
        elseif strcmp(sets.filter_type_main, 'lowpass')
            % if lowpass, set higher edge to specified cutoff and no lower edge
            low_cutoff = [];
            high_cutoff = sets.filter_cutoff_main;    
        else
            % Raise an error if the value is not valid
            error('Invalid value for filter type. It must be ''bandpass'', ''highpass'', or ''lowpass''. See p00_settings.m ''Filters'' section.');
        end
        
        % Apply filter depending on type
        EMG = pop_eegfiltnew(EMG, ...
            'locutoff', low_cutoff, ...
            'hicutoff', high_cutoff); 

    end
    
    % Check if notch filter is on
    if sets.do_filtering_notch
        % Use a tight band round cutoff frequency
        EMG = pop_eegfiltnew(EMG, ...
            'locutoff', sets.filter_cutoff_notch - 2.5, ...
            'hicutoff', sets.filter_cutoff_notch + 2.5, ...
            'revfilt', 1);  % use notch instead of band-pass
            
    end
    
    EMG = eeg_checkset(EMG);

    fprintf('\nFiltering COMPLETE\n\n');
    
    %% 2.4.5 - Downsampling
    
    % Check if downsampling in on
    if sets.do_downsampling
        EMG = pop_resample(EMG, sets.downsample_rate);

        fprintf('\nDownsampling COMPLETE\n\n');
    end

    %% 2.4.6 - Signal rectification
    
    % Check if rectification is on
    if sets.do_rectifying
        % Rectify based on method
        if strcmp(sets.rectify_method, 'abs')
            EMG.data = abs(EMG.data);
        end

        fprintf('\nSignal rectification COMPLETE\n');
    end
     
    %% 2.4.7 - Epoch data & count trials
    
    % Epoch data
    EMG = pop_epoch(EMG, sets.condition_names, sets.epoch_length, 'epochinfo', 'yes');
    
    % Remove additional triggers
    EMG = pop_selectevent(EMG, 'type', sets.condition_names, 'deleteevents', 'on');
    
    % Add a new event field keeping track of the trial number
    EMG = pop_editeventfield(EMG, 'trial_number', 1:length(EMG.event));

    fprintf('\nEpoching COMPLETE\n\n');
    
    %% 2.4.8 - Artefact detection
    
    % Check if automatic artefact detection is on
    if sets.do_artefact_detection_automatic
        
        % Automatic artefact detection on baseline ----
        
        % % Epoch data to only include baseline
        EMG_baseline = pop_epoch(EMG, sets.condition_names, [sets.epoch_length(1), 0], 'epochinfo', 'yes');
        
        % Detect artefacts in the baseline
        EMG_baseline = pop_jointprob(EMG_baseline,...
            1,...  % analyze channels (not components)
            1:length(EMG.chanlocs),...  % analyze all channels
            sets.artefact_threshold_baseline,...  % threshold within each channel
            sets.artefact_threshold_baseline,...  % threshold among all channels
            1,...
            0,...  % only flag trials, don't remove them
            0, [], 0);

        % Automatic artefact detection on trial ----

        % Epoch data to only include trial
        EMG_trial = pop_epoch(EMG, sets.condition_names, [0, sets.epoch_length(2)], 'epochinfo', 'yes');

        % Detect artefacts in trial
        EMG_trial = pop_jointprob(EMG_trial, 1, 1:length(EMG.chanlocs),...
            sets.artefact_threshold_trial,...
            sets.artefact_threshold_trial,...
            0, 0, 0, [], 0);

        % Combine flags ----

        % Assign to original EMG struct the index of trials flagged by at least one method
        EMG.reject.rejjp = EMG_baseline.reject.rejjp | EMG_trial.reject.rejjp;

        % Remove temporary structs
        clearvars EMG_baseline EMG_trial

        fprintf('\nAutomatic artefact detection COMPLETE\n\n');

    end

    % Check if manual artefact detection is on
    if sets.do_artefact_detection_manual
        
        % Assign data to EEG struct cause 'pop_rejmenu' will work only on it
        EEG = EMG;
        
        % Open GUI for manual artefact rejection.
        % Stop further code execution till GUI is closed.
        
        % --- HOW TO USE GUI ---
        % - Don't care about values set in all the menu boxes, they won't be applied
        % - Click on "Scoll Data" on top, this will open a new window
        % - In the new window trials automatically flagged are colored (probably in red-pink)
        % - Click on a flagged trial to unflag it. Click on an unflagged trial to flag it
        % - When finished:
        %    - If AT LEAST ONE CHANGE WAS MADE:
        %       - Click on " Update Marks"
        %       - A warning window will appear. Click on "Ok"
        %       - On the initial GUI, click on "Close (keep marks)"
        %   - If NO CHANGES WERE MADE:
        %       - Just close both windows by clicking on the X button

        eeglab redraw  % update EEGLab menu
        pop_rejmenu(EEG, 1);  % open main GUI
        uiwait  % halt execution of remaining code until GUI is closed
        close all
        
        % Assign modified EEG back to EMG struct
        EMG = EEG;

        fprintf('\nManual artefact detection COMPLETE\n\n');
       
    end

    if sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual
    
        % Merge automatic and manual selections
        EMG = eeg_rejsuperpose(EMG, 1, 1, 1, 1, 1, 1, 1, 1);
        
        % Count rejected trials ----
        
        n_rej_total = sum(EMG.reject.rejglobal);  % number of rejected trials across conditions
        perc_rej_total = n_rej_total/length(EMG.epoch);  % percentage of rejected trials across conditions
        
        % Number and percentage of rejected trials within each condition
        n_rej_cond = cell(1, length(sets.condition_names));  % preallocate cell to store number of rejected trials per condition
        perc_rej_cond = cell(1, length(sets.condition_names));  % preallocate cell to store percentage of rejected trials per condition
        
        % Loop through conditions
        for i = 1:length(sets.condition_names)
            
            % Number of rejected trials within one condition
            n_rej_cond{1, i} = sum(...  % sum trials...
                strcmp({EMG.event.type}, sets.condition_names{i}) & ...  % ...that belong to current condition...
                EMG.reject.rejglobal);  % ...and are flagged
            
            % Percentage of rejected trials within one condition
            perc_rej_cond{1, i} = n_rej_cond{1, i}/sum(strcmp({EMG.event.type}, sets.condition_names{i})); 
        end
        
        % Store all info for this subject
        reject_info(si, :) = [{subj_ID, n_rej_total}, n_rej_cond, {perc_rej_total}, perc_rej_cond]; 
        
        % Check if saving info is on
        if sets.do_save_trial_rejection_stats
            
            % Turn cell into table and assign column names
            reject_info_table = cell2table(reject_info,...
                'VariableNames',...
                [{'subject_ID', 'n_rejected_total'},...
                cellfun(@(x) ['n_rejected_', x], sets.condition_names, 'UniformOutput', false),...
                {'perc_rejected_total'},...
                cellfun(@(x) ['perc_rejected_', x], sets.condition_names, 'UniformOutput', false)]);
            
            % Save table
            writetable(reject_info_table, fullfile(sets.processed_dir, sets.fname_trial_rejection_stats));
            
            fprintf('\nRejected trials info SAVED\n\n');
            
        end

    end

    %% 2.4.9 - Baseline correction
    
    % Check if baseline correction is on
    if sets.do_baseline_correction

        % Correct the entire rectified waveform separately for every muscle and trial.
        % The baseline interval is left-inclusive and right-exclusive.
        baseline_method = char(sets.baseline_correction_method);

        if ~strcmp(baseline_method, 'none')
            baseline_idx = ...
                EMG.times >= sets.baseline_correction_window(1) & ...
                EMG.times < sets.baseline_correction_window(2);

            if ~any(baseline_idx)
                error('apply_mav_baseline_correction:EmptyBaseline', ...
                    'The specified baseline window contains no samples.');
            end

            baseline_amplitudes = mean(EMG.data(:, baseline_idx, :), 2);

            if strcmp(baseline_method, 'subtraction')
                EMG.data = EMG.data - baseline_amplitudes;
            elseif strcmp(baseline_method, 'division')
                EMG.data = EMG.data ./ baseline_amplitudes;
            else
                error('apply_mav_baseline_correction:InvalidMethod', ...
                    'Method must be ''none'', ''subtraction'', or ''division''.');
            end
        end

        fprintf('\nBaseline correction (method %s) COMPLETE\n\n', sets.baseline_correction_method);

    end

    %% 2.4.10 - Save preprocessed datasets

    % Next standardization steps require to work only on clean data. Therefore, here save the dataset as preprocessed so
    % far as a checkpoint.
    
    % Check if saving data is on
    if sets.do_save_preprocessed_data
        
        % Define new filename
        new_fname = [EMG.subject, sets.fname_preprocessed_data];

        % Set filename and path in EMG struct
        EMG.setname = new_fname;
        EMG.filename = [EMG.setname, '.set'];
        EMG.filepath = sets.processed_dir;

        % Save dataset as .set file
        EMG = pop_saveset(EMG, 'filename', EMG.filename, 'filepath', EMG.filepath);
        
        fprintf('\nPreprocessed dataset SAVED\n\n');
        
    end

    %% 2.4.11 - Remove flagged trials
    % Remove trials flagged by artefact detection to ensure following standardization is done only on clean data
    
    if sets.do_artefact_detection_automatic || sets.do_artefact_detection_manual
        
        % Save a copy of the original event list
        events_pre_rejection = struct2table(EMG.event);

        EMG = pop_rejepoch(EMG, EMG.reject.rejglobal, 0);
    
        fprintf('\nTrial rejection COMPLETE\n\n');
    end
    
    %% 2.4.12 - Feature extraction

    if sets.feature_extraction_bin_dur > abs(EMG.times(1))
        % Raise error if bin duration is longer than epoch baseline
        error('Specified bin duration is longer than epoch baseline!');

    end

    if ~strcmp(sets.feature_extraction_method, 'mav')
        error('Invalid feature extraction method. Currently supported value: ''mav''.');
    end

    % EMG.data is already rectified. Extract ordinary means without applying abs again.
    epoch_end_ms = sets.epoch_length(2) * 1000;
    n_post_bins = epoch_end_ms / sets.feature_extraction_bin_dur;

    if abs(n_post_bins - round(n_post_bins)) > 1e-10
        error('extract_binned_mav:IncompleteBin', ...
            'The post-stimulus epoch duration must be a multiple of the bin duration.');
    end

    n_post_bins = round(n_post_bins);
    bin_edges = [-sets.feature_extraction_bin_dur, ...
        0:sets.feature_extraction_bin_dur:epoch_end_ms];
    n_bins = n_post_bins + 1;

    n_trials = size(EMG.data, 3);
    n_channels = size(EMG.data, 1);
    feature_amplitudes = nan(n_trials, n_channels, n_bins);

    for b = 1:n_bins
        if b < n_bins
            sample_idx = EMG.times >= bin_edges(b) & EMG.times < bin_edges(b + 1);
        else
            sample_idx = EMG.times >= bin_edges(b) & EMG.times <= bin_edges(b + 1);
        end

        if ~any(sample_idx)
            error('extract_binned_mav:EmptyBin', ...
                'Bin %d contains no samples.', b);
        end

        bin_mean = mean(EMG.data(:, sample_idx, :), 2);
        feature_amplitudes(:, :, b) = reshape(...
            permute(bin_mean, [3, 1, 2]), n_trials, n_channels);
    end

    fprintf('\nFeature extraction COMPLETE\n\n');

    %% 2.4.13 - Feature standardization

    feature_amplitudes_z = [];
    standardized_feature_suffix = '';

    if sets.do_standardization_muscle
        % Estimate one reference distribution per muscle from retained post-stimulus observations.
        post_bin_idx = bin_edges(1:end-1) >= 0;
        feature_amplitudes_z = nan(size(feature_amplitudes));

        for ch = 1:size(feature_amplitudes, 2)
            reference_values = reshape(feature_amplitudes(:, ch, post_bin_idx), [], 1);
            reference_values = reference_values(isfinite(reference_values));

            if numel(reference_values) < 2
                error('standardize_mav_features:InvalidReference', ...
                    ['The muscle %d standardization reference has fewer than ', ...
                    'two finite observations.'], ch);
            end

            reference_mean = mean(reference_values);
            reference_sd = std(reference_values, 0);

            if ~isfinite(reference_sd) || reference_sd == 0
                error('standardize_mav_features:InvalidReference', ...
                    'The muscle %d standardization reference has zero or nonfinite SD.', ch);
            end

            feature_amplitudes_z(:, ch, :) = ...
                (feature_amplitudes(:, ch, :) - reference_mean) ./ reference_sd;
        end

        standardized_feature_suffix = 'MAV_z_muscle';

        fprintf('\nWithin-muscle feature standardization COMPLETE\n\n');

    elseif sets.do_standardization_subject
        % Estimate one participant reference distribution across all muscles and post-stimulus observations.
        post_bin_idx = bin_edges(1:end-1) >= 0;
        reference_values = reshape(feature_amplitudes(:, :, post_bin_idx), [], 1);
        reference_values = reference_values(isfinite(reference_values));

        if numel(reference_values) < 2
            error('standardize_mav_features:InvalidReference', ...
                ['The subject standardization reference has fewer than ', ...
                'two finite observations.']);
        end

        reference_mean = mean(reference_values);
        reference_sd = std(reference_values, 0);

        if ~isfinite(reference_sd) || reference_sd == 0
            error('standardize_mav_features:InvalidReference', ...
                'The subject standardization reference has zero or nonfinite SD.');
        end

        feature_amplitudes_z = ...
            (feature_amplitudes - reference_mean) ./ reference_sd;
        standardized_feature_suffix = 'MAV_z_subject';

        fprintf('\nWithin-subject feature standardization COMPLETE\n\n');
    end

    do_feature_standardization = ...
        sets.do_standardization_muscle || sets.do_standardization_subject;

    % Name the unstandardized measure according to the baseline-correction mode.
    if ~sets.do_baseline_correction
        unstandardized_feature_suffix = 'MAV_raw';
    elseif strcmp(sets.baseline_correction_method, 'subtraction')
        unstandardized_feature_suffix = 'MAV_difference';
    elseif strcmp(sets.baseline_correction_method, 'division')
        unstandardized_feature_suffix = 'MAV_ratio';
    else
        error('Invalid baseline correction method. It must be ''subtraction'' or ''division''.');
    end
    
    %% 2.4.14 - Trial average and store participant data
    
    % Here conditions are defined as the ones actually present in the EMG struct, not the ones specified in the settings.
    % This is to account for possible between-subject designs.
    this_condition_names = unique({EMG.event.type});

    % Preallocate cell arrays to store features and row identifiers per condition
    data_out_unstandardized = cell(1, length(this_condition_names));
    data_out_standardized = cell(1, length(this_condition_names));
    data_out_trials = cell(1, length(this_condition_names));
    data_out_bins = cell(1, length(this_condition_names));
    data_out_conditions = cell(1, length(this_condition_names));

    % Loop through conditions
    for cond = 1:length(this_condition_names)

        % Get indexes of trials belonging to current condition
        cond_idx = strcmp({EMG.event.type}, this_condition_names{cond});

        % Check if trial averaging is on
        if sets.do_trial_averaging

            % Average unstandardized features belonging to the current condition
            this_average = mean(feature_amplitudes(cond_idx, :, :), 1);
            
            % Concatenate bin data along rows and store data
            data_out_unstandardized{1, cond} = permute(this_average, [3, 2, 1]);

            if do_feature_standardization
                this_average_z = mean(feature_amplitudes_z(cond_idx, :, :), 1);
                data_out_standardized{1, cond} = permute(this_average_z, [3, 2, 1]);
            end

            % Store number of trials being averaged (repeated for number of bins)
            data_out_trials{1, cond} = repmat(sum(cond_idx), n_bins, 1);

            % Store bin number
            data_out_bins{1, cond} = (1:n_bins)';

            % Store condition name (repeated for number of bins)
            data_out_conditions{1, cond} = repmat(this_condition_names(cond), n_bins, 1);

        else
            % If not averaging, get all unstandardized trials belonging to the current condition
            this_condition = feature_amplitudes(cond_idx, :, :);
            
            % Reshape data concatenating first along bins and then along trials, and store it
            data_out_unstandardized{1, cond} = reshape(permute(this_condition, [3, 1, 2]), ...
                [size(this_condition,1)*size(this_condition,3), size(this_condition, 2)]);

            if do_feature_standardization
                this_condition_z = feature_amplitudes_z(cond_idx, :, :);
                data_out_standardized{1, cond} = reshape(permute(this_condition_z, [3, 1, 2]), ...
                    [size(this_condition_z, 1)*size(this_condition_z, 3), size(this_condition_z, 2)]);
            end

            % Store original trial numbers for current condition (each repeated for number of bins)
            data_out_trials{1, cond} = repelem([EMG.event(cond_idx).trial_number]', n_bins, 1);

            % Store bin number, repeated for each trial
            data_out_bins{1, cond} = repmat((1:n_bins)', sum(cond_idx), 1);

            % Store condition names, repeated for each trial and bin
            data_out_conditions{1, cond} = repmat(this_condition_names(cond), n_bins*sum(cond_idx), 1);

        end

    end
   
    % Build a feature table containing only the current participant
    if isempty(data_out_conditions)
        % Preserve a valid table schema when all trials were rejected
        participant_conditions = strings(0, 1);
        participant_trials = zeros(0, 1);
        participant_bins = zeros(0, 1);
        participant_unstandardized = zeros(0, length(sets.emg_channel_names));
        participant_standardized = zeros(0, length(sets.emg_channel_names));
    else
        participant_conditions = string(cat(1, data_out_conditions{:}));
        participant_trials = cat(1, data_out_trials{:});
        participant_bins = cat(1, data_out_bins{:});
        participant_unstandardized = cat(1, data_out_unstandardized{:});
        if do_feature_standardization
            participant_standardized = cat(1, data_out_standardized{:});
        else
            participant_standardized = zeros(length(participant_conditions), 0);
        end
    end

    participant_features_table = table(...
        repmat(string(subj_ID), length(participant_conditions), 1), ...
        participant_conditions, ...
        participant_trials, ...
        participant_bins, ...
        'VariableNames', {'subject_ID', 'condition', 'trial_number', 'bin'});

    % Add adjacent unstandardized and standardized feature columns per muscle
    for ch = 1:length(sets.emg_channel_names)
        unstandardized_variable = ...
            [sets.emg_channel_names{ch}, '_', unstandardized_feature_suffix];
        participant_features_table.(unstandardized_variable) = ...
            participant_unstandardized(:, ch);

        if do_feature_standardization
            standardized_variable = ...
                [sets.emg_channel_names{ch}, '_', standardized_feature_suffix];
            participant_features_table.(standardized_variable) = ...
                participant_standardized(:, ch);
        end
    end

    feature_variable_names = participant_features_table.Properties.VariableNames;

    % Include rejected trials if specified
    if sets.do_save_rejected_trial_rows
        
        % Define all expected bins independently of how many clean trials remain
        bins = (1:n_bins)';

        % Create complete trial X bin skeleton from EMG struct BEFORE trial rejection
        prerej_trial_table = events_pre_rejection(:, {'type', 'trial_number'});

        % Rename 'type' to match the participant feature table
        prerej_trial_table.Properties.VariableNames{'type'} = 'condition';

        % Make sure condition has the same datatype
        prerej_trial_table.condition = string(prerej_trial_table.condition);

        % Repeat every trial once for each bin
        full_trial_table = prerej_trial_table(repelem((1:height(prerej_trial_table))', n_bins), :);

        % Add bin number
        full_trial_table.bin = repmat(bins, height(prerej_trial_table), 1);

        % Add subject ID
        full_trial_table.subject_ID = repmat(string(subj_ID), height(full_trial_table), 1);

        % Merge clean trials onto the complete pre-rejection skeleton
        participant_features_table_full = outerjoin(...
            full_trial_table, ...
            participant_features_table, ...
            "Keys", {'subject_ID', 'condition', 'trial_number', 'bin'}, ...
            "MergeKeys", true, ...
            "Type", 'left');

        % Reorder columns
        participant_features_table = participant_features_table_full(:, ...
            feature_variable_names);

    end

    % Store the current participant only after table construction completes
    participant_feature_tables{si} = participant_features_table;

    % Concatenate all participants completed so far
    checkpoint_features_table = vertcat(participant_feature_tables{1:si});

    % Preserve the configured condition order, including between-subject designs
    condition_order = string(sets.condition_names);
    checkpoint_features_table.condition = categorical(...
        checkpoint_features_table.condition, ...
        condition_order, ...
        cellstr(condition_order), ...
        'Ordinal', true);

    checkpoint_features_table = sortrows(checkpoint_features_table, ...
        {'subject_ID', 'condition', 'trial_number', 'bin'});
    checkpoint_features_table.condition = string(checkpoint_features_table.condition);

    % Send confirmation message
    if sets.do_trial_averaging
        fprintf('\nTrial averaging COMPLETE\n\n');
    end

    fprintf('\nStoring extracted features COMPLETE\n\n')
    
    %% 2.4.15 - Save feature data to file
    
    % Check if saving features is on
    if sets.do_save_features_amplitudes

        % Save all participants completed so far as a recovery checkpoint
        feature_output_path = fullfile(sets.amplitudes_dir, sets.fname_feature_amplitudes);
        writetable(checkpoint_features_table, feature_output_path);

        fprintf('\nFeature amplitudes SAVED for %d completed participant(s)\n\n', si);
        
    end

end
