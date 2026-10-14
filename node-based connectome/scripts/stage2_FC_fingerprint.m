%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 2 - FINGERPRINTING (DIFFERENTIAL IDENTIFIABILITY)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Adapted from Sorrentino et al. (2021), NeuroImage, doi.org/10.1016/j.neuroimage.2021.118253
% https://github.com/eamico/Clinical_fingerprinting
%
% Builds the identifiability matrix (Amico & Goñi, 2018) from test vs. retest FC:
% diagonal = Iself, off-diagonal = Iothers. Also computes Idiff, the success rate
% and the edge-wise ICC.
%
% Requires data_FCs (1 x N_subjects cell, each regions x regions x [test, retest])
% from stage1b_transform_FC_fisher.m.

n_subj = size(data_FCs, 2);       % number of subjects
n_roi = size(data_FCs{1}, 1);     % number of regions of interest (ROI)

%% Vectorize each FC matrix (upper triangle only, see f_load_mat.m)
mask_ut = triu(true(n_roi, n_roi), 1);
[FCs_test, FCs_retest] = f_load_mat(data_FCs, mask_ut);
mask_diag = logical(eye(size(FCs_test, 1)));

%% Identifiability matrix: correlation of every test connectome against every retest connectome
Ident_mat = corr(FCs_test', FCs_retest');
Ident_mat_1 = Ident_mat;

% Success rate: how many times an Iself value is higher than an Iothers
% value on the same row and column.
sr1 = zeros(1, n_subj);
for i = 1:length(Ident_mat)
    sr1(i) = sum(Ident_mat(i, i) > Ident_mat(i, :)) + sum(Ident_mat(i, i) > Ident_mat(:, i));
end
sr_indiv = sr1 * 100 / (length(Ident_mat) * 2 - 2);  % individual success rate
sr_mean = mean(sr_indiv, 2);                          % average success rate

% Iself/Iothers/Idiff
Iself = zeros(1, n_subj);        % self identifiability
Iothers = zeros(1, n_subj);      % others-identifiability
Idiff_indiv = zeros(1, n_subj);  % Iself - Iothers
Idiff = nanmean(Ident_mat(mask_diag)) - nanmean(Ident_mat(~mask_diag));
for s = 1:n_subj
    Iself(s) = Ident_mat(s, s);
    Ident_mat(s, s) = nan;
    Iothers(s) = 0.5 .* (nanmean(Ident_mat(s, :)) + nanmean(Ident_mat(:, s))');
    Idiff_indiv(s) = Iself(s) - Iothers(s);
end

%% Edge-wise ICC
ICC_struct = f_ICC_edgewise(FCs_test(:, :)', FCs_retest(:, :)');
