%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 1b - FISHER Z-TRANSFORM AND TEST/RETEST PAIRING
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Splits the Pearson FC matrices into test (first half) and retest (second half),
% Fisher Z-transforms them (atanh) and stores each subject's pair as data_FCs
% (regions x regions x [test, retest]). Called by the step4_RUN_ALL scripts.

paths = project_paths();

config = load(fullfile(paths.config, 'step2_sFC_Pearson_config.mat'));
config = config.config;

pipeline = config.pipelines{1};
session_type = config.session_type{1};
outpath = config.out_path;

sFC_Pearson_path = fullfile(outpath, ['Pearson-results-Schaefernew7400-', pipeline, '-bysubject.mat']);
load(sFC_Pearson_path, 'FC_all_bysubject');

num_subjects = config.Nsubjects / 2;
data_FCs = cell(1, num_subjects);

for i = 1:num_subjects
    test_FC = FC_all_bysubject(:, :, i);              % test session FC (Pearson r)
    retest_FC = FC_all_bysubject(:, :, i + num_subjects);  % retest session FC (Pearson r)

    test_FC = atanh(test_FC);      % Fisher Z-transform (Pearson r -> z)
    retest_FC = atanh(retest_FC);

    data_FCs{i} = cat(3, test_FC, retest_FC);
end

output_filename = [pipeline, '_', session_type, '_FC_', num2str(num_subjects), 'subs.mat'];
intermediate_dir = fullfile(paths.data, 'derivatives', 'fingerprint_intermediate');
if ~exist(intermediate_dir, 'dir')
    mkdir(intermediate_dir);
end
sFC_Pearson_new = fullfile(intermediate_dir, output_filename);
save(sFC_Pearson_new, 'data_FCs');
