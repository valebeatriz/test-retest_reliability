%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 1 - PEARSON FC (SCRUBBING VARIANT)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Band-pass filters (0.01-0.1 Hz) each region's timeseries and computes the
% Pearson FC matrix per subject/session. Always recomputes, since the volumes
% are resampled in every iteration.
%
% Called by step4_RUN_ALL_scrubbing.m. 
%
%fprintf('>>>>>>> Stage 1 - Computation of sFC using Pearson correlation\n');

paths = project_paths();

% Load config structure
config = load(fullfile(paths.config, 'step2_sFC_Pearson_config.mat'));
config = config.config;

% Parameters
sFC_inpath = config.in_path;
sFC_outpath = config.out_path;
pipelinelog_path = config.pipelinelog_path;
subjects = config.subjects;
sessions = config.sessions;
pipeline_list = config.pipelines;
session_type = config.session_type;
atlas_list = config.atlases;
include_ind = config.include_areas;
N_areas_list = config.include_Nareas;
N_subjects = config.Nsubjects;
TR = config.TR;
N_windows = config.nr_windows;
order_bysubject = config.order_bysubject;
sFC_log_filename = fullfile(pipelinelog_path, ['step2_sFC_Pearson-log_', datestr(now, 'yyyy-mm-dd'), '.txt']);

% Band-pass filter settings (0.01-0.1 Hz)
fnq = 1 / (2 * TR);
flp = .01; fhi = .1;
Wn = [flp / fnq, fhi / fnq];
[bfilt, afilt] = butter(2, Wn);

for a = 1:length(atlas_list)
    atlas = atlas_list{a};
    N_areas = N_areas_list(a);

    for p = 1:length(pipeline_list)
        pipeline = pipeline_list{p};

        % Collect every subject/session input filename
        auxfilenames = cell(length(sessions), 1);
        for k = 1:length(sessions)
            kfiles = subjects{k};
            files = cellfun(@(x) fullfile(sFC_inpath, x, sessions{k}, ['BOLD', pipeline, '-parcellated', atlas, '.mat']), kfiles, 'UniformOutput', false);
            auxfilenames{k, 1} = files;
        end
        filenames = [auxfilenames{:}];

        FC_all = zeros(N_areas, N_areas, N_subjects);

        for s = 1:length(filenames)
            data_in = filenames{s};
            [path_parts, ~, ~] = fileparts(data_in);
            tokens = split(path_parts, filesep);
            subj = tokens{end-1};
            sess = tokens{end};

            subject_fc_path = fullfile(paths.data, 'derivatives', 'sFC_Pearson_scrubbing', subj, [sess, '_', pipeline]);
            if ~exist(subject_fc_path, 'dir')
                mkdir(subject_fc_path);
            end
            subject_fc_file = fullfile(subject_fc_path, ['PearsonFC-', atlas, '.mat']);

            load_BOLD = load(data_in);
            BOLD_aux = load_BOLD.all_av;
            BOLD = BOLD_aux(include_ind, :);
            BOLD = BOLD - mean(BOLD, 2);
            BOLD_filt = zeros(size(BOLD));
            for seed = 1:N_areas
                BOLD_filt(seed, :) = filtfilt(bfilt, afilt, BOLD(seed, :));
            end
            FC = corr(BOLD_filt');
            save(subject_fc_file, 'FC');
            %fprintf('[SAVED] %s\n', subject_fc_file);

            FC_all(:, :, s) = FC;

            log_msg = ['------ sFC Pearson for: ', data_in];
            %disp(log_msg);
            logCustom(log_msg, sFC_log_filename);
        end

        filenames_bysubject = filenames(order_bysubject);
        FC_all_bysubject = FC_all(:, :, order_bysubject);

        managefolders(sFC_outpath, 'create');

        save(fullfile(sFC_outpath, ['Pearson-results-', atlas, '-', pipeline, '-bysubject.mat']), ...
            'N_subjects', 'filenames_bysubject', 'N_areas', 'FC_all_bysubject');
    end
end
