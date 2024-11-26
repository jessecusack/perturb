%
% Calculate chi from temperature gradients given an already calculated epsilon
%
% Aug-2024, Pat Welch, pat@mousebrains.com

function [dInfo, tbl] = calc_chi(diss, dInfo)
arguments (Input)
    diss table % Profile information
    dInfo (1,:) table % Summary information about the profile
end % arguments Input
arguments (Output)
    dInfo (1,:) table % pInfo with extra fields
    tbl table % Tabular form of diss struct
end % arguments Output

kappa_T = 1.4e-7; % thermal diffusivity [m^2/s]

tbl = table();
tbl.t = diss.t;
tbl.depth = diss.depth;

names = string(diss.Properties.VariableNames);

for name = names(startsWith(names, "gradT"))
    gradT = diss.(name);
    gradT2 = gradT.^2;
    % gradT2(gradT <= 0) = NaN;
    index = extractAfter(name, "gradT");
    tbl.(name) = gradT;
    tbl.(sprintf("chi_dT%s_mean", index)) = 2 * kappa_T * diss.N2 .* diss.epsilonMean ./ gradT2;
    for j = 1:size(diss.e,2)
        tbl.(sprintf("chi_dT%s_e%d", index, j)) = 2 * kappa_T * diss.N2 .* diss.e(:,j) ./ gradT2;
    end % for j
end % for name
end % calc_chi