function discr = discriminability(mats, metric)
%DISCRIMINABILITY Discriminability of a set of matrices with multiple measures per subject.
%   Adapted from https://github.com/RXRodriguez98/DiscriminabilityMATLAB/blob/main/discriminability.m
%
%   Computes the discriminability of a set of connectomes across
%   subjects with multiple measures each (e.g. test/retest sessions).
%
%   INPUTS
%     mats    4D matrix, size n_nodes x n_nodes x n_subjects x n_measures
%             -- OR --
%             3D matrix, size n_edges x n_subjects x n_measures
%             A set of connectomes across subjects with multiple
%             measures. When 4D, the first two dimensions are a typical
%             connectome, indexed by subject (3rd dim) and measure (4th
%             dim). When 3D, the first dimension is an already-vectorized
%             connectome, indexed by subject (2nd dim) and measure (3rd
%             dim).
%     metric  string: the distance metric for the discriminability
%             calculation, e.g. 'correlation' or 'euclidean'.
%
%   OUTPUT
%     discr   double: the discriminability of the given dataset.

%% Convert connectomes to 2D (edges x [subject, measure])
if length(size(mats)) == 4  % 4D input
    n_subjects = size(mats, 3);
    n_nodes = size(mats, 1);
    n_edges = n_nodes * (n_nodes - 1) / 2;
    n_measures = size(mats, 4);

    vectors = zeros(n_edges, n_measures * n_subjects);
    for subject_index = 1:n_subjects
        for measure_index = 1:n_measures
            curr_mat = mats(:, :, subject_index, measure_index);
            curr_vec = curr_mat(find(triu(ones(n_nodes), 1)));
            vectors(:, (subject_index - 1) * n_measures + measure_index) = curr_vec;
        end
    end
else  % 3D input
    n_edges = size(mats, 1);
    n_subjects = size(mats, 2);
    n_measures = size(mats, 3);

    vectors = zeros(n_edges, n_measures * n_subjects);
    for subject_index = 1:n_subjects
        curr_vec = squeeze(mats(:, subject_index, :));
        vectors(:, ((subject_index - 1) * n_measures + 1):(subject_index * n_measures)) = curr_vec;
    end
end

%% Pairwise distance matrix between every [subject, measure] vector
dist_mat = pdist2(vectors', vectors', metric);

%% Discriminability: fraction of within-subject comparisons closer than between-subject comparisons
count = 0;  % number of times a within-subject comparison beats a between-subject comparison for the same scan
for subject_index = 1:n_subjects
    dist_inds = (subject_index - 1) * n_measures + (1:n_measures);
    for row = dist_inds
        full_row = dist_mat(row, :);
        cross_scan_inds = dist_inds;
        cross_scan_inds(dist_inds == row) = [];
        for cross_scan_ind = cross_scan_inds
            curr_comparison = full_row(cross_scan_ind);
            other_comparisons = full_row;
            other_comparisons(dist_inds) = [];
            count = count + length(find(other_comparisons >= curr_comparison));
        end
    end
end
discr = count / (n_subjects * n_measures * (n_subjects * n_measures - n_measures) * (n_measures - 1));

end
