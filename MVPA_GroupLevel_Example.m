% Dot Probe MVPA group-level analysis
% author: zeguo.qiu@uq.net.au

%% Step1: Prepare group data
subject_list = [data_path 'subject_list.txt']; % load subject data
readSub = fopen(subject_list);
S = textscan(readSub,'%s');
subject_cell = S{1};
fclose(readSub);

excludebaseline = 0; % exclude baseline or not
trialtype_names = {'visibility','tasktype'}; % set trialtype of interest;

for h = [2]%1:length(trialtype_names)
    res_cell = cell([size(subject_cell, 1) 1]);
    for i = 1:length(subject_cell) % subject
        subject_id = subject_cell{i};
        file_names = [subject_id '_' trialtype_names{h} '.mat']; % get data files
        load(fullfile(output_path, file_names));
        
        if excludebaseline == 1
            baseline = res.a.fdim.values{1} < 0;
            res = cosmo_dim_prune(cosmo_slice(res, ~baseline, 2));
        end
        
        res_cell{i} = res;
        % for one-sample t-test against h0/chance level
        res_cell{i}.sa.chunks = i;  % each subject is independent from all other subjects
        res_cell{i}.sa.targets = 1; % set to the same condition
    end
    
    res_group = cosmo_stack(res_cell);
    
    %% Step2: Prepare group analysis parameters
    nbrhood = cosmo_cluster_neighborhood(res_group); % set neighborhood for feature clustering
    args = struct();
    args.niter = 10000; % number of permutations
    args.h0_mean = 0.5; % chance level accuracy for n-class classification
    args.cluster_stat = 'tfce'; % cluster statistics for multiple correction
    args.null = []; % use default sign-based permutation approach
    args.nproc = 6;
    
    %% Step3: Run group analysis
    res_stat = cosmo_montecarlo_cluster_stat(res_group, nbrhood, args);
    
    %% Step4: Save dataset and results
    if excludebaseline == 1
        save([output_path 'group_' trialtype_names{h} '_corr.mat'], 'res_group', 'res_stat');
    else
        save([output_path 'group_' trialtype_names{h} '.mat'], 'res_group', 'res_stat');
    end
end