% Combine the output of diss2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function diss2combo(binned, pars)
arguments (Input)
    binned (:,1) cell
    pars struct
end % arguments Input

[a, fnCombo] = save2combo(binned, pars, pars.diss_combo_root);
save2NetCDF(a, fnCombo, pars);
end % diss2combo