%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STEP 3 - SHORTER VOLUME COUNTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Saves the first 900, 600 and 300 volumes of each reordered 1200-volume
% timeseries (used by step4_RUN_ALL_truncation.m). Run after step2 has
% reindexed all four sessions.

paths = project_paths();

input_base = fullfile(paths.data, 'derivatives', 'parcellated_data_1200');
output_bases = {
    fullfile(paths.data, 'derivatives', 'parcellated_data_900'), 900;
    fullfile(paths.data, 'derivatives', 'parcellated_data_600'), 600;
    fullfile(paths.data, 'derivatives', 'parcellated_data_300'), 300
};

% All 100 HCP subjects
subs = {'100307', '100408', '101107', '101309', '101915', '103111', '103414', '103818', ...
        '105014', '105115', '106016', '108828', '110411', '111312', '111716', '113619', ...
        '113922', '114419', '115320', '116524', '117122', '118528', '118730', '118932', ...
        '120111', '122317', '122620', '123117', '123925', '124422', '125525', '126325', ...
        '127630', '127933', '128127', '128632', '129028', '130013', '130316', '131217', ...
        '131722', '133019', '133928', '135225', '135932', '136833', '138534', '139637', ...
        '140925', '144832', '146432', '147737', '148335', '148840', '149337', '149539', ...
        '149741', '151223', '151526', '151627', '153025', '154734', '156637', '159340', ...
        '160123', '161731', '162733', '163129', '176542', '178950', '188347', '189450', ...
        '190031', '192540', '196750', '198451', '199655', '201111', '208226', '211417', ...
        '211720', '212318', '214423', '221319', '239944', '245333', '280739', '298051', ...
        '366446', '397760', '414229', '499566', '654754', '672756', '751348', '756055', ...
        '792564', '856766', '857263', '899885'};

sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL', 'rfMRI_REST2_LR', 'rfMRI_REST2_RL'};

for i = 1:length(subs)
    sub = subs{i};
    for j = 1:length(sessions)
        sess = sessions{j};
        input_file = fullfile(input_base, sub, sess, 'BOLD1200-parcellatedSchaefernew7400.mat');

        if ~isfile(input_file)
            fprintf('Missing file: %s\n', input_file);
            continue;
        end

        data = load(input_file);
        all_av_full = data.all_av;  % 400 x 1200

        for k = 1:size(output_bases, 1)
            out_base = output_bases{k, 1};
            n_timepoints = output_bases{k, 2};

            out_dir = fullfile(out_base, sub, sess);
            if ~exist(out_dir, 'dir')
                mkdir(out_dir);
            end

            all_av = all_av_full(:, 1:n_timepoints);
            out_file = fullfile(out_dir, sprintf('BOLD%d-parcellatedSchaefernew7400.mat', n_timepoints));
            save(out_file, 'all_av');
        end
    end
end

disp('Step 3 complete.');
