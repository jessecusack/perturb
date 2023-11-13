%
% For each profile, calculate dissipation estimates
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [row, dissInfo] = profile2diss(row, profileInfo, pars)
arguments (Input)
    row (1,:) table % row to work on
    profileInfo struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    row table % row worked on
    dissInfo  % Dissipation estimates structure or empty
end % arguments Output

dissInfo = [];

fnDiss = fullfile(pars.diss_root, append(row.name, ".mat"));
row.fnDiss = fnDiss;

if isnewer(fnDiss, row.fnProf) % fnDiss is newer than fnProf
    fprintf("%s: %s newer than %s\n", row.name, fnDiss, row.fnProf);
    return;
end

if isempty(profileInfo) % we need to load a
    fprintf("Loading %s\n", row.fnProf);
    profileInfo = load(row.fnProf);
end

stime = tic();

profiles = profileInfo.profiles;
pInfo = profileInfo.pInfo;
nProfiles = numel(profiles);

tbl = cell(nProfiles, 1);
dInfo = cell(size(tbl));

for index = 1:nProfiles
    [dInfo{index}, tbl{index}] = calc_diss_shear(profiles{index}, pInfo(index,:), pars);
end % for index

qEmpty = cellfun(@isempty, tbl);
if all(qEmpty) % No dissipation estimates
    fprintf("%s: No dissipation estimates found", row.name);
    return;
end

tbl = tbl(~qEmpty);
dInfo = dInfo(~qEmpty);

dissInfo = struct();
dissInfo.info = vertcat(dInfo{:});
dissInfo.profiles = tbl;
if isfield(profileInfo, "fp07Lags")
    dissInfo.fp07 = profileInfo.fp07Lags;
end % if isfield

my_mk_directory(fnDiss);
save(fnDiss, "-struct", "dissInfo", pars.matlab_file_format);
fprintf("Took %.2f seconds to create %s\n", toc(stime), fnDiss);
end % profile2diss