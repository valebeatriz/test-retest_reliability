%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% step4_RUN_ALL_scrubbing.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% For every (subjects x volumes x session type) combination, runs
% num_internal_iterations draws. Each draw picks random subjects and a random
% non-contiguous subset of volumes (always including the first and last) from the
% full 1200-volume series, then runs stages 1-5 and stores the results.
%
% Requires step1 and step2 (parcellated_data_1200).
%
%% Adapts code from:
% FC matrices: https://github.com/isesteves/multilevel-fingerprinting_migraine/tree/main
% Fingerprinting: https://github.com/eamico/Clinical_fingerprinting
% Discriminability: https://github.com/RXRodriguez98/DiscriminabilityMATLAB/tree/main

clear all;
clc;

paths = project_paths();

%% --- Configuration ---
subject_number_options = [10, 20, 50, 80];
volumes_number_options = [300, 600, 900, 1200];
num_internal_iterations = 100;
session_types = {'INTER', 'INTRA'};

all_HCP_master_subjects = {'100307', '100408', '101107', '101309', '101915', '103111', '103414', '103818', '105014', '105115', '106016', '108828', '110411', '111312', '111716', '113619', '113922', '114419', '115320', '116524', '117122', '118528', '118730', '118932', '120111', '122317', '122620', '123117', '123925', '124422', '125525', '126325', '127630', '127933', '128127', '128632', '129028', '130013', '130316', '131217', '131722', '133019', '133928', '135225', '135932', '136833', '138534', '139637', '140925', '144832', '146432', '147737', '148335', '148840', '149337', '149539', '149741', '151223', '151526', '151627', '153025', '154734', '156637', '159340', '160123', '161731', '162733', '163129', '176542', '178950', '188347', '189450', '190031', '192540', '196750', '198451', '199655', '201111', '208226', '211417', '211720', '212318', '214423', '221319', '239944', '245333', '280739', '298051', '366446', '397760', '414229', '499566', '654754', '672756', '751348', '756055', '792564', '856766', '857263', '899885'};

input_base_path = fullfile(paths.data, 'derivatives', 'parcellated_data_1200');
config_path = paths.config;
pipeline_step = 'step2_sFC_Pearson';
output_base_path = fullfile(paths.data, 'derivatives', 'ICC_Idiff_Discr');
if ~exist(output_base_path, 'dir')
    mkdir(output_base_path);
end

%% --- Main Loop ---
for current_subject_number = subject_number_options
  for current_volumes_number = volumes_number_options
    for stype = 1:length(session_types)
      current_type_session = session_types{stype};

      % Determine base session types
      if strcmp(current_type_session, 'INTER')
        base_sessions = {'rfMRI_REST1_LR', 'rfMRI_REST2_LR', 'rfMRI_REST1_RL', 'rfMRI_REST2_RL'};
      elseif strcmp(current_type_session, 'INTRA')
        base_sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL'};
      end

      fprintf('\n--- Subjects=%d | Volumes=%d | Type=%s ---\n', ...
        current_subject_number, current_volumes_number, current_type_session);

      base_scrub_path = fullfile(paths.data, 'derivatives', sprintf('parcellated_data_%d_scrubbing', current_volumes_number));
      results = repmat(struct(), 1, num_internal_iterations);

      for z = 1:num_internal_iterations
        fprintf('Iteration %d/%d...\n', z, num_internal_iterations);
        rng('shuffle');
        idx = randperm(length(all_HCP_master_subjects), current_subject_number);
        subjects = all_HCP_master_subjects(idx);

        session_info = struct('subject', {}, 'session1_indices', {}, 'session2_indices', {}, 'session1_type', {}, 'session2_type', {});

        % For INTER, we need to build custom session assignments
        if strcmp(current_type_session, 'INTER')
          subject_sessions_list = cell(current_subject_number, 2);  % Store session names
        end

        for i = 1:current_subject_number
          subj = subjects{i};

          % Determine which sessions this subject should use
          if strcmp(current_type_session, 'INTRA')
            subject_sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL'};
          elseif strcmp(current_type_session, 'INTER')
            if mod(i, 2) == 1  % Odd subjects
              subject_sessions = {'rfMRI_REST1_LR', 'rfMRI_REST2_RL'};
            else  % Even subjects
              subject_sessions = {'rfMRI_REST1_RL', 'rfMRI_REST2_LR'};
            end
          end

          sessions = cell(1, 2); sess_idxs = cell(1, 2);

          for s = 1:2
            sess_name = subject_sessions{s};
            infile = fullfile(input_base_path, subj, sess_name, 'BOLD1200-parcellatedSchaefernew7400.mat');
            assert(exist(infile, 'file') == 2, ['Missing ' infile]);
            load(infile, 'all_av');
            % Always include the first and last volume; randomly
            % subsample the rest ("scrubbing" -- non-contiguous subset).
            fixed = [1, 1200];
            remaining = setdiff(2:1199, fixed);
            rand_idxs = randsample(remaining, current_volumes_number - 2);
            selected = sort([fixed, rand_idxs]);
            sessions{s} = all_av(:, selected);
            sess_idxs{s} = selected;
          end

          filename = sprintf('BOLD%d-parcellatedSchaefernew7400.mat', current_volumes_number);
          flat_dir = fullfile(base_scrub_path, subj);

          sess1_name = subject_sessions{1};
          sess2_name = subject_sessions{2};

          % Create directories
          for d = {sess1_name, sess2_name}
              mkdir(fullfile(flat_dir, d{1}));
          end

          % Save data to session-named folders
          all_av = sessions{1};
          save(fullfile(flat_dir, sess1_name, filename), 'all_av');

          all_av = sessions{2};
          save(fullfile(flat_dir, sess2_name, filename), 'all_av');

          session_info(i) = struct( ...
            'subject', subj, ...
            'session1_indices', sess_idxs{1}, ...
            'session2_indices', sess_idxs{2}, ...
            'session1_type', subject_sessions{1}, ...
            'session2_type', subject_sessions{2});

          % Store session names for INTER config building
          if strcmp(current_type_session, 'INTER')
            subject_sessions_list{i, 1} = sess1_name;
            subject_sessions_list{i, 2} = sess2_name;
          end
        end

        % Build config structure for INTER AFTER processing all subjects
        if strcmp(current_type_session, 'INTER')
          all_HCP_subjects_config = {};
          all_sessions = {};
          % First pass: all subjects' first session
          for i = 1:current_subject_number
            all_HCP_subjects_config{end+1} = {subjects{i}};
            all_sessions{end+1} = subject_sessions_list{i, 1};
          end
          % Second pass: all subjects' second session
          for i = 1:current_subject_number
            all_HCP_subjects_config{end+1} = {subjects{i}};
            all_sessions{end+1} = subject_sessions_list{i, 2};
          end
        end

        %% --- Configure Pipeline ---
        config = struct();
        config.in_path = base_scrub_path;
        config.out_path = fullfile(paths.data, 'derivatives', sprintf('sFC_Pearson_%d_scrubbing', current_volumes_number));
        config.pipelinelog_path = paths.logs;

        % Handle config.subjects and config.sessions based on session type
        if strcmp(current_type_session, 'INTER')
          config.subjects = all_HCP_subjects_config;
          config.sessions = all_sessions;
        else  % INTRA
          config.subjects = repmat({subjects}, 1, 2);
          config.sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL'};
        end

        config.Nsubjects = current_subject_number * 2;
        config.pipelines = {num2str(current_volumes_number)};
        config.session_type = {current_type_session};
        config.atlases = {'Schaefernew7400'};
        config.atlases_Nareas = 400;
        config.TR = 0.72;
        config.nr_windows = 1;
        config.include_areas = 1:400;
        config.include_Nareas = 400;
        config.order_bysubject = 1:(current_subject_number * 2);

        save(fullfile(config_path, [pipeline_step '_config.mat']), 'config');
        config_tracker(config_path, pipeline_step, config);

        %% --- Run Fingerprinting Pipeline ---
        try
            disp('    Stage 1 - Connectivity Matrix');
            run(fullfile(paths.scripts, 'stage1_sFC_Pearson_scrubbing.m'));

            disp('    Stage 1b - Transform matrix');
            run(fullfile(paths.scripts, 'stage1b_transform_FC_fisher.m'));

            disp('    Stage 2 - Fingerprinting');
            run(fullfile(paths.scripts, 'stage2_FC_fingerprint.m'));

            close all;

            disp('    Stage 3 - Edge-level ICC');
            run(fullfile(paths.scripts, 'stage3_ICC_edge_mean.m'));

            disp('    Stage 4 - Discriminability');
            run(fullfile(paths.scripts, 'stage4_discriminability.m'));

            disp('    Stage 5 - Connectome-level ICC');
            run(fullfile(paths.scripts, 'stage5_ICC_connectome_level.m'));

        catch ME
          warning('Pipeline error in iter %d: %s', z, ME.message);
        end

        %% Store Results
        if exist('Idiff', 'var')
            results(z).Idiff = Idiff;
        else
            results(z).Idiff = [];
        end

        if exist('Iself', 'var')
            results(z).Iself = Iself;
        else
            results(z).Iself = [];
        end

        if exist('sr_mean', 'var')
            results(z).sr_mean = sr_mean;
        else
            results(z).sr_mean = [];
        end

        if exist('discr_value', 'var')
            results(z).discr_value = discr_value;
        else
            results(z).discr_value = [];
        end

        if exist('network_icc_means', 'var')
            results(z).network_icc_means = network_icc_means;
        else
            results(z).network_icc_means = [];
        end

        if exist('ICC_individual_FC', 'var')
            results(z).ICC_individual = ICC_individual_FC;
        else
            results(z).ICC_individual = [];
        end

        if exist('subjects', 'var')
            if iscell(subjects) && ~isempty(subjects)
                results(z).subjects = subjects;
            end
        else
            results(z).subjects = {};
        end

        results(z).session_info = session_info;  % added for reproducibility

        % Delete only top-level subject folders (e.g. 100307, 105014, etc.)
        % -- frees disk space between iterations since each iteration
        % writes a fresh randomly-subsampled copy of the data.
        subject_id_pattern = '^\d{6}$';

        all_entries = dir(base_scrub_path);
        all_entries = all_entries([all_entries.isdir]);  % Only directories

        for k = 1:length(all_entries)
            folder_name = all_entries(k).name;

            if ismember(folder_name, {'.', '..'})
                continue;
            end

            if ~isempty(regexp(folder_name, subject_id_pattern, 'once'))
                folder_to_delete = fullfile(base_scrub_path, folder_name);
                try
                    rmdir(folder_to_delete, 's');
                    %fprintf('Deleted folder: %s\n', folder_to_delete);
                catch ME
                    warning('Could not delete %s: %s', folder_to_delete, ME.message);
                end
            end
        end
      end
      %% --- Save Aggregated Results ---
      out_fname = fullfile(output_base_path, sprintf('%dsubs_%dvol_%s_SCRUBBING.mat', current_subject_number, current_volumes_number, current_type_session));
      save(out_fname, 'results');
      %fprintf('Results saved to %s\n', out_fname);

    end
  end
end

fprintf('All runs and pipeline processing complete.');
