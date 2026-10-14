%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%% STAGE 4 - DISCRIMINABILITY
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Loads the test/retest FC data saved by stage1b_transform_FC_fisher.m (path in
% sFC_Pearson_new) and computes discr_value with discriminability.m.

load(sFC_Pearson_new, 'data_FCs');
connectivity_cell = data_FCs;

num_subjects = length(connectivity_cell);
num_nodes = size(connectivity_cell{1}, 1);    % 400
num_measures = size(connectivity_cell{1}, 3); % 2 (test, retest)

mats_for_discr = zeros(num_nodes, num_nodes, num_subjects, num_measures);
for subject_index = 1:num_subjects
    mats_for_discr(:, :, subject_index, :) = connectivity_cell{subject_index};
end

discr_value = discriminability(mats_for_discr, 'euclidean');
