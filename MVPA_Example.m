% Dot Probe MVPA
% author: zeguo.qiu@uq.net.au

cd
addpath
eeglab
ft_defaults
group_path = '';
data_path = [group_path 'EEGsets\'];
output_path = [group_path 'EEGsets\Output\'];

%% Step1: Prepare CoSMoMVPA data structure
config = cosmo_config(); % set configuration
cosmo_check_external('-tic'); % reset citation list

% load data
trialtype_fn = fullfile(data_path,'DotProbeMVPA.xlsx'); % load trial type data
trialtable = readtable(trialtype_fn, 'Sheet', 'Sheet1', 'ReadVariableNames', true, 'ReadRowNames', false);

subject_list = [data_path 'subject_list.txt']; % load subject data
readSub = fopen(subject_list);
S = textscan(readSub,'%s');
subject_cell = S{1};
fclose(readSub);

flip_list = [data_path 'flip_electrodes.txt']; % load flipped electrode
readFlp = fopen(flip_list);
F = textscan(readFlp,'%d %d %s');
flip_new_order = F{2};
fclose(readFlp);

load([data_path 'montageCSD.mat']) % % load surface Laplacian data; return variable 'G', 'H', 'montage'

% set parameters
Laplacian = 1; % apply spatial filter or nor
smoothing = 1; % perform temporal somtthing/filtering or not
spatialflip = 0; % flip electrodes or not
radialsvm = 1; % use radial kernel for svm or not; customised function cosmo_classify_libsvm_radial.m needed
trimdata = 1; % use subsets of electrodes or not
trialtype_names = 'tasktype'; % set trialtype of interest

for i = 1:length(subject_cell) % subject
    subject_id = subject_cell{i};
    subject_path = data_path;

    EEG = pop_loadset('filename',[subject_id '.set'], 'filepath', subject_path);
    EEG = pop_select(EEG, 'nochannel', 65:69);

    if Laplacian
        EEG = pop_reref(EEG, 38,'keepref','on'); % re-reference to Fz; average reference is not suitable for CSD transformation
        EEG.data = eeglabCSD(EEG,G,H);
    end

    %try
    switch trialtype_names % identify suitable trials based on classifier target values
        case 'visibility'
            trialtype_idx = trialtable.visibility ~= 0;
        case 'tasktype'
            trialtype_idx = trialtable.tasktype ~= 0;
    end

    workidx = trialtable.PID == str2double(subject_id) & trialtype_idx;
    worktable = trialtable(workidx,:);

    eeg_data = [];

    if spatialflip == 1
        for k = [0 1 2] % cue (0-NA, 1-left, 2-right)
            outputidx = find(worktable.faceSide == k); % remember to use the right -side variable!!!
            inputidx = worktable{worktable.faceSide == k,'epochNo'};
            eeg_data(outputidx,:,:) = permute(EEG.data(:,:,inputidx), [3 1 2]);
            if k == 2
                [~, flipsort] = sort(flip_new_order);
                for m = outputidx
                    eeg_data(outputidx,:,:) = eeg_data(outputidx, flipsort,:);
                end
            end
        end
    else
        inputidx = worktable.epochNo;
        eeg_data = permute(EEG.data(:,:,inputidx), [3 1 2]);
    end

    if smoothing
        eeg_data = smoothdata(eeg_data, 3, "gaussian", 5); % Gaussian window with length = 5
    end

    ds_tl = cosmo_flatten(eeg_data, {'chan','time'}, {{EEG.chanlocs.labels},[EEG.times]});

    switch trialtype_names
        case 'visibility'
            ds_tl.sa.targets = worktable.visibility;
            index2label = {'subliminal','supraliminal'};
        case 'tasktype'
            ds_tl.sa.targets = worktable.tasktype;
            index2label = {'irrelevant','relevant'};
    end

    if length(unique(ds_tl.sa.targets))<2 % skip when only one trial type
        continue
    end

    ds_tl.sa.labels = cellfun(@(x)index2label(x),num2cell(ds_tl.sa.targets));
    ds_tl.sa.chunks = (1:size(ds_tl.samples,1))'; % indicate independence between all trials
    cosmo_check_dataset(ds_tl); % check CoSMoMVPA data structure
    
    if trimdata == 1
        channels = {'P3','P4','P5','P6','P7','P8','P9','P10','PO3','PO4','PO7','PO8','O1','O2','Oz','POz'};
        mask = cosmo_dim_match(ds_tl, 'chan', channels);
        ds_tl = cosmo_dim_prune(cosmo_slice(ds_tl, mask, 2));
    end
            
    cosmo_check_dataset(ds_tl);

    %% Step2: Prepare MVPA parameters
    % set measure
    measure = @cosmo_crossvalidation_measure; % cross-validation classification

    % set classifier
    if radialsvm == 1
        classifier = @cosmo_classify_libsvm_radial; % libsvm with radial kernel '-t 2'
    else
        classifier = @cosmo_classify_libsvm; % libsvm with radial kernel '-t 0'
    end

    % set chunks
    nchunks = 10; % for 10-fold cross-validation
    ds_tl.sa.chunks = cosmo_chunkize(ds_tl,nchunks);

    % set partitions
    partitions = cosmo_nchoosek_partitioner(ds_tl, 1); % together with n-chunks, do n-fold leave-one-fold-out cross validation
    partitions = cosmo_balance_partitions(partitions, ds_tl);

    % set temporal neighborhood
    time_radius = 2; % 5 timepoints (1 centre + 2 per side) in each searchlight
    time_nbrhood = cosmo_interval_neighborhood(ds_tl, 'time', 'radius', time_radius);

    % set parallel threads
    nproc = 6; % when Matlab parallel processing toolbox is available; local logical processors = 6

    % parse measure arguments
    args = struct();
    args.classifier = classifier;
    args.partitions = partitions;
    args.nproc = nproc;

    %% Step3: Run MVPA
    res = cosmo_searchlight(ds_tl, time_nbrhood, measure, args);

    %% Step4: Save dataset and results
    save([output_path subject_id '_' trialtype_names '.mat'], 'ds_tl', 'res');

    %catch
     %   continue % jump to next iteration when there is an error
    %end
end
