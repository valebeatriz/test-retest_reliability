%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 5 - CONNECTOME-LEVEL ICC
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ICC between each subject's own vectorized test and retest connectomes (one
% value per subject; stage3 instead averages per-edge ICC across subjects).
% Requires data_FCs from stage1b_transform_FC_fisher.m.

n_subj = size(data_FCs, 2);
n_roi = size(data_FCs{1}, 1);  % 400

%% Vectorize the upper triangle of each subject's test/retest FC matrices
mask_ut = triu(true(n_roi, n_roi), 1);
num_connections = sum(mask_ut(:));  % 79,800 unique connections for 400 nodes

FCs_test = zeros(n_subj, num_connections);
FCs_retest = zeros(n_subj, num_connections);

for s = 1:n_subj
    matrix_s1 = data_FCs{s}(:, :, 1);
    matrix_s2 = data_FCs{s}(:, :, 2);

    FCs_test(s, :) = matrix_s1(mask_ut)';
    FCs_retest(s, :) = matrix_s2(mask_ut)';
end

%% Per-subject ICC between their own test and retest connectome
ICC_individual_FC = zeros(1, n_subj);

for s = 1:n_subj
    % 'M' for the ICC function expects one row per edge (object of
    % measurement) and one column per session (measurement/"judge").
    data_for_icc_subj = [FCs_test(s, :)' FCs_retest(s, :)'];

    rows2delete_subj = isnan(sum(data_for_icc_subj, 2));
    data_for_icc_subj(rows2delete_subj, :) = [];

    if ~isempty(data_for_icc_subj) && size(data_for_icc_subj, 1) > 1
        [r, ~, ~, ~, ~, ~, ~] = ICC(data_for_icc_subj, 'A-1');
        ICC_individual_FC(s) = r;
    else
        warning('Not enough valid data for ICC calculation for subject %d', s);
        ICC_individual_FC(s) = NaN;
    end
end
