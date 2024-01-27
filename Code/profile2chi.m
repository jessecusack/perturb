%
% For each profile, calculate dissipation estimates
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [row, chiInfo] = profile2chi(row, profileInfo, dissInfo, pars)
arguments (Input)
    row (1,:) table % row to work on
    profileInfo struct % Output of mat2profile
    dissInfo struct % Output of profile2diss
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    row table % row worked on
    chiInfo  % chi estimates structure or empty
end % arguments Output

chiInfo = [];

fnChi = fullfile(pars.chi_root, append(row.name, ".mat"));
row.fnChi = fnChi;

if isnewer(fnChi, row.fnDiss) % fnChi is newer than fnDiss
    fprintf("%s: %s newer than %s\n", row.name, fnChi, row.fnDiss);
    return;
end

if isempty(profileInfo) % we need to load profileInfo
    fprintf("Loading %s\n", row.fnProf);
    profileInfo = load(row.fnProf);
end

if isempty(dissInfo) % we need to load dissInfo
    fprintf("Loading %s\n", row.fnDiss);
    dissInfo = load(row.fnDiss);
end

warning("Chi not implemented");
% return;
% 
% stime = tic();
% 
% profiles = profileInfo.profiles;
% pInfo = profileInfo.pInfo;
% nProfiles = numel(profiles);
% 
% tbl = cell(nProfiles, 1);
% dInfo = cell(size(tbl));
% 
% for index = 1:nProfiles
%     [dInfo{index}, tbl{index}] = calc_diss_shear(profiles{index}, pInfo(index,:), pars);
% end % for index
% 
% qEmpty = cellfun(@isempty, tbl);
% if all(qEmpty) % No dissipation estimates
%     fprintf("%s: No dissipation estimates found", row.name);
%     return;
% end
% 
% tbl = tbl(~qEmpty);
% dInfo = dInfo(~qEmpty);
% 
% dissInfo = struct();
% dissInfo.info = vertcat(dInfo{:});
% dissInfo.profiles = tbl;
% if isfield(profileInfo, "fp07Lags")
%     dissInfo.fp07 = profileInfo.fp07Lags;
% end % if isfield
% 
% my_mk_directory(fnChi);
% save(fnChi, "-struct", "chiInfo", pars.matlab_file_format);
% fprintf("Took %.2f seconds to create %s\n", toc(stime), fnChi);
end % profile2diss