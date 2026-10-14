function paths = project_paths()
%PROJECT_PATHS Central definition of every directory the pipeline uses.
%
%   PATHS = PROJECT_PATHS() returns a struct of directories, resolved
%   automatically so the pipeline works regardless of where the repo is
%   checked out on disk.
%
%   CODE layout is fixed and detected from this file's own location:
%       <root>/code/config/    config-generating scripts
%                              (step1_parcellation_config_reg.m,
%                               step2_sFC_Pearson_config.m)
%       <root>/code/scripts/   everything else (this file included)
%
%   DATA layout is NOT part of the code repository (it's large and
%   subject-specific). By default it is assumed to live at <root>/data,
%   but you can point it anywhere by setting the environment variable
%   FINGERPRINTING_DATA_ROOT before starting MATLAB, e.g. in bash:
%       export FINGERPRINTING_DATA_ROOT=/imaging/correia/bv01/HCP/derivatives_reg_root
%   Under paths.data the pipeline expects/creates (see README.md):
%       preprocessed/                     step1 input
%       derivatives_reg/parcellated_data*/   step1/1b/1c output
%       derivatives_reg/parcellated_data_<N>_scrubbing|_segment/  per-iteration slices
%       derivatives_reg/sFC_Pearson*/     step2 output
%       derivatives_reg/ICC_Idiff_Discr/  RUN_ALL_MULTIPLE_*.m aggregated results
%       logs/pipeline_logs/               log files
%
%   TEMPLATES and FILES hold atlas/parcellation reference files, also
%   overridable via FINGERPRINTING_TEMPLATES_ROOT / FINGERPRINTING_FILES_ROOT:
%       templates/                        atlas volumes used by parcellation()
%       files/atlases/Schaefer/Schaefer_H2N_ind.mat   reindexing map (step1b)
%
%   Usage: call setup_pipeline() once per MATLAB session (from the repo
%   root) before running any step; that puts this file on the path so
%   every script -- in code/config or code/scripts -- can call
%   project_paths() regardless of its own location.

    this_file    = mfilename('fullpath');   % .../code/scripts/project_paths
    scripts_dir  = fileparts(this_file);    % .../code/scripts
    code_dir     = fileparts(scripts_dir);  % .../code
    project_root = fileparts(code_dir);     % repo root

    paths.root    = project_root;
    paths.code    = code_dir;
    paths.config  = fullfile(code_dir, 'config');
    paths.scripts = scripts_dir;

    paths.data      = get_env_or_default('FINGERPRINTING_DATA_ROOT',      fullfile(project_root, 'data'));
    paths.templates = get_env_or_default('FINGERPRINTING_TEMPLATES_ROOT', fullfile(project_root, 'templates'));
    paths.files      = get_env_or_default('FINGERPRINTING_FILES_ROOT',     fullfile(project_root, 'files'));

    paths.logs = fullfile(paths.data, 'logs', 'pipeline_logs');
end

function value = get_env_or_default(env_name, default_value)
    value = getenv(env_name);
    if isempty(value)
        value = default_value;
    end
end
