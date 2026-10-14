function [FCs_test, FCs_retest] = f_load_mat(FCtype, mask_ut)
%F_LOAD_MAT Vectorize a cell array of test/retest FC matrices.
%   FCtype is a cell array; each cell holds one subject's two functional
%   connectomes (FC), sized brain_regions x brain_regions x
%   [test, retest].
%   mask_ut is a logical mask over the FC matrices selecting the upper
%   triangular elements only.
%
%   FCs_test:   one row per subject, one column per upper-triangle
%               element of that subject's TEST FC.
%   FCs_retest: same, for the RETEST FC.

FCs_test = nan(length(FCtype), nnz(mask_ut));
FCs_retest = nan(length(FCtype), nnz(mask_ut));

for i = 1:length(FCtype)
    aux_test = FCtype{i}(:, :, 1);
    aux_retest = FCtype{i}(:, :, 2);

    FCs_test(i, :) = aux_test(mask_ut);
    FCs_retest(i, :) = aux_retest(mask_ut);
end

end
