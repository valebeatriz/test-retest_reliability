function CONN_ICC_A = f_ICC_edgewise(Atest, Aretest)
%F_ICC_EDGEWISE Edge-wise test-retest ICC.
%   CONN_ICC_A = F_ICC_EDGEWISE(ATEST, ARETEST) computes the intraclass
%   correlation (ICC, type 'A-1') between ATEST and ARETEST for every
%   edge (row), where each is a numEdges x numSubjects matrix. Rows with
%   any NaN across the two sessions are dropped before computing that
%   edge's ICC.
%
%   Requires ICC.m to be on the MATLAB path

numEdges = size(Atest, 1);
CONN_ICC_A = zeros(1, numEdges);

for comp = 1:numEdges
    data4icc_A = [Atest(comp, :)' Aretest(comp, :)'];
    rows2delete_A = isnan(sum(data4icc_A, 2));
    data4icc_A(rows2delete_A, :) = [];
    CONN_ICC_A(1, comp) = ICC(data4icc_A, 'A-1');
end

end
