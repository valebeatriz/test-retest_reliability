%% step0_parcellation_config.m
%
% Run first (after setup_pipeline). Saves step1_parcellation_config.mat (data
% folders, subjects, sessions, atlas) for step1_parcellation.m.

paths = project_paths();
pipeline_step = 'step1_parcellation';

%% Define subjects and sessions
% All 100 HCP subjects; the same subject list is used for every session.
all_subs = {'100307', '100408', '101107', '101309', '101915', '103111', '103414', '103818', '105014', '105115', '106016', '108828', '110411', '111312', '111716', '113619', '113922', '114419', '115320', '116524', '117122', '118528', '118730', '118932', '120111', '122317', '122620', '123117', '123925', '124422', '125525', '126325', '127630', '127933', '128127', '128632', '129028', '130013', '130316', '131217', '131722', '133019', '133928', '135225', '135932', '136833', '138534', '139637', '140925', '144832', '146432', '147737', '148335', '148840', '149337', '149539', '149741', '151223', '151526', '151627', '153025', '154734', '156637', '159340', '160123', '161731', '162733', '163129', '176542', '178950', '188347', '189450', '190031', '192540', '196750', '198451', '199655', '201111', '208226', '211417', '211720', '212318', '214423', '221319', '239944', '245333', '280739', '298051', '366446', '397760', '414229', '499566', '654754', '672756', '751348', '756055', '792564', '856766', '857263', '899885'};

sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL', 'rfMRI_REST2_LR', 'rfMRI_REST2_RL'};
all_HCP_subjects = repmat({all_subs}, 1, length(sessions));  % same subjects for every session

%% Create configuration struct
config = struct();
config.in_path          = fullfile(paths.data, 'preprocessed');
config.out_path         = fullfile(paths.data, 'derivatives', 'parcellated_data_1200');
config.atlas_path       = paths.templates;
config.pipelinelog_path = paths.logs;
config.subjects  = all_HCP_subjects;
config.sessions  = sessions;
config.pipelines = {'1200'};
config.atlases   = {'SchaeferH7400'};
config.plt = 0;

%% Save configuration file and update the config archive
save(fullfile(paths.config, [pipeline_step, '_config.mat']), 'config');
config_tracker(paths.config, pipeline_step, config);
