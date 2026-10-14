%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STEP 1 - PARCELLATION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Parcellates each subject's preprocessed functional data with the atlas in
% step1_parcellation_config.mat and saves the mean timeseries per region (all_av).
% Run after step0_parcellation_config.m.

clear
clc

disp('>>>>>>> Step 1 - Parcellation of preprocessed functional data');

paths = project_paths();
config_file = fullfile(paths.config, 'step0_parcellation_config.mat');

config_details = dir(config_file);
if isempty(config_details)
    error('Config file not found: %s\nRun step0_parcellation_config.m first.', config_file);
end
disp(['--- Step 1 - Config file last modified on ', datestr(config_details.date)]);

% Load configuration settings
config = load(config_file);
config = config.config;  % Extract the structure from the loaded file

% Access script-specific parameters
parcellation_inpath = config.in_path;
parcellation_outpath = config.out_path;
parcellation_atlas_path = config.atlas_path;
pipelinelog_path = config.pipelinelog_path;

subjects = config.subjects;
sessions = config.sessions;
pipeline_list = config.pipelines;
atlas_list = config.atlases;

plt = config.plt;

managefolders(pipelinelog_path, 'create');
parcellation_log_filename = fullfile(pipelinelog_path, ['step1_parcellation-log_', datestr(now, 'yyyymmdd-HHMMSS'), '.txt']);

for ses = 1:length(sessions)
    session = sessions{ses};
    session_subjects = subjects{1, ses};

    for s = 1:length(session_subjects)
        subject = session_subjects{s};

        for p = 1:length(pipeline_list)
            pipeline = pipeline_list{p};

            % Expected preprocessing output structure:
            %   <in_path>/<subject>/<session>/<session>_hpf_clean_smooth.nii.gz
            img_path = fullfile(parcellation_inpath, subject, session, [session, '_hpf_clean_smooth.nii.gz']);

            if ~exist(img_path, 'file')
                warning('File not found: %s', img_path);
                logCustom(['WARNING: File not found - ', img_path], parcellation_log_filename);
                continue;
            end

            % Load functional image (gunzip to a temp .nii, load, then
            % delete the unzipped copy to save disk space).
            gunzip(img_path);
            unzipped_path = img_path(1:end-3);  % strip the '.gz'
            data_load = load_untouch_nii(unzipped_path);
            delete(unzipped_path);

            funcimg = data_load.img;

            for a = 1:length(atlas_list)
                atlas = atlas_list{a};

                out_folder = fullfile(parcellation_outpath, subject, session);
                outpath_av_nonzero = fullfile(out_folder, ['BOLD', pipeline, '-parcellated', atlas, '.mat']);
                outpath_av_all     = fullfile(out_folder, ['BOLDall-', pipeline, '-parcellated', atlas, '.mat']);
                outpath_percent    = fullfile(out_folder, ['percent-', pipeline, '-parcellated', atlas, '.mat']);

                parcellation_log_msg = ['------ ', atlas, ' Parcellation for: ', subject, '_', session, ' with pipeline ', pipeline];
                disp(parcellation_log_msg);
                logCustom(parcellation_log_msg, parcellation_log_filename);

                [all_av_allvoxels, all_av, percentage_included] = parcellation(parcellation_atlas_path, atlas, funcimg, plt);

                managefolders(out_folder, 'create');
                save(outpath_av_nonzero, 'all_av', '-mat');
                save(outpath_av_all, 'all_av_allvoxels', '-mat');
                save(outpath_percent, 'percentage_included', '-mat');
            end
        end
    end
end

disp('Step 1 complete.');
