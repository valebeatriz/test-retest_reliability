%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STEP 2 - REORDER REGIONS BY NETWORK
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Reorders the 400 Schaefer regions into the 7 Yeo networks (Schaefer_H2N_ind.mat),
% as assumed by stage3_ICC_edge_mean.m. Run after step1_parcellation.m.
%

clear; clc;

paths = project_paths();

% All 100 HCP subjects
subs = {'100307', '100408', '101107', '101309', '101915', '103111', '103414', '103818', '105014', '105115', '106016', '108828', '110411', '111312', '111716', '113619', '113922', '114419', '115320', '116524', '117122', '118528', '118730', '118932', '120111', '122317', '122620', '123117', '123925', '124422', '125525', '126325', '127630', '127933', '128127', '128632', '129028', '130013', '130316', '131217', '131722', '133019', '133928', '135225', '135932', '136833', '138534', '139637', '140925', '144832', '146432', '147737', '148335', '148840', '149337', '149539', '149741', '151223', '151526', '151627', '153025', '154734', '156637', '159340', '160123', '161731', '162733', '163129', '176542', '178950', '188347', '189450', '190031', '192540', '196750', '198451', '199655', '201111', '208226', '211417', '211720', '212318', '214423', '221319', '239944', '245333', '280739', '298051', '366446', '397760', '414229', '499566', '654754', '672756', '751348', '756055', '792564', '856766', '857263', '899885'};

sessions = {'rfMRI_REST1_LR', 'rfMRI_REST1_RL', 'rfMRI_REST2_LR', 'rfMRI_REST2_RL'};
pipelines = {'1200'};

base_path = fullfile(paths.data, 'derivatives', 'parcellated_data_1200');
ind_path = fullfile(paths.files, 'atlases', 'Schaefer', 'Schaefer_H2N_ind.mat');

% Load the Schaefer H7400 -> canonical-network-order index map
ind_struct = load(ind_path);
ind = ind_struct.ind(:);  % ensure it's a column vector (400x1)

for i = 1:length(subs)
    for j = 1:length(sessions)
        for k = 1:length(pipelines)
            input_file = fullfile(base_path, subs{i}, sessions{j}, ...
                ['BOLD', pipelines{k}, '-parcellatedSchaeferH7400.mat']);

            if ~exist(input_file, 'file')
                fprintf('File missing: %s\n', input_file);
                continue;
            end

            data_struct = load(input_file);
            all_av = data_struct.all_av;

            if size(all_av, 1) ~= 400 || length(ind) ~= 400
                fprintf('Size mismatch: %s (Expected 400xN, Got %dx%d)\n', ...
                    input_file, size(all_av, 1), size(all_av, 2));
                continue;
            end

            % Reorder regions into canonical network order
            all_av = all_av(ind, :);

            output_file = fullfile(base_path, subs{i}, sessions{j}, ...
                ['BOLD', pipelines{k}, '-parcellatedSchaefernew7400.mat']);
            save(output_file, 'all_av');

            fprintf('Processed: %s | %s | %s\n', subs{i}, sessions{j}, pipelines{k});
        end
    end
end

disp('Step 2 complete.');
