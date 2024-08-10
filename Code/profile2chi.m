%

% For each profile, calculate chi estimates
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [row, chiInfo] = profile2chi(row, profileInfo, chiInfo, pars)
arguments (Input)
    row (1,:) table % row to work on
    profileInfo struct % Output of mat2profile
    chiInfo struct % Output of profile2diss
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

if isempty(chiInfo) % we need to load dissInfo
    fprintf("Loading %s\n", row.fnDiss);
    chiInfo = load(row.fnDiss);
end

stime = tic();

profiles = profileInfo.profiles;
pInfo = profileInfo.pInfo;
nProfiles = numel(profiles);

dProfiles = chiInfo.profiles;
dInfo = chiInfo.info;

if size(pInfo,1) ~= size(dInfo,1)
    warning("Mismatched number of profiles in chi calculation, %d ~= %d", size(pInfo,1), size(dInfo,1));
    return;
end % if size

tbl = cell(nProfiles, 1);
dInfo = cell(size(tbl));

for index = 1:nProfiles
    profile = profiles{index};
    fast = profile.fast;
    slow = profile.slow;
    diss = dProfiles{index};
    fast.dDepth = interp1(diss.depth, diss.depth, fast.depth, "nearest", "extrap");
    fast.grp = findgroups(fast.dDepth);
    a = rowfun(@(x) x(1), fast, ...
        InputVariables="dDepth", ...
        GroupingVariables="grp", ...
        OutputVariableNames="depth");
    names = string(fast.Properties.VariableNames);
    names = names(startsWith(names, "gradT"));
    for name = names
        a.(name) = rowfun(@(x) median(x, "omitnan"), fast, ...
            InputVariables=name, ...
            GroupingVariables="grp", ...
            OutputFormat="uniform");
    end % for

    N2 = table();
    [N2.N2, N2.pMid] = gsw_Nsquared(slow.SA, slow.theta, slow.P_slow, slow.lat);
    N2.depth = (slow.depth(1:end-1) + slow.depth(2:end)) / 2;
    N2.dDepth = interp1(diss.depth, diss.depth, N2.depth, "nearest", "extrap");
    N2.grp = findgroups(N2.dDepth);

    b = rowfun(@(x) x(1), N2, ...
        InputVariables="dDepth", ...
        GroupingVariables="grp", ...
        OutputVariableNames="depth");
    b.N2 = rowfun(@(x) median(x, "omitnan"), N2, ...
            InputVariables="N2", ...
            GroupingVariables="grp", ...
            OutputFormat="uniform");

    diss = innerjoin(diss, a, Keys="depth", RightVariables=names);
    diss = innerjoin(diss, b, Keys="depth", RightVariables="N2");

    [dInfo{index}, tbl{index}] = calc_chi(diss, pInfo(index,:));
end % for index

qEmpty = cellfun(@isempty, tbl);
if all(qEmpty) % No dissipation estimates
    fprintf("%s: No dissipation estimates found", row.name);
    return;
end

tbl = tbl(~qEmpty);
dInfo = dInfo(~qEmpty);

chiInfo = struct();
chiInfo.info = vertcat(dInfo{:});
chiInfo.profiles = tbl;

my_mk_directory(fnChi);
save(fnChi, "-struct", "chiInfo", pars.matlab_file_format);
fprintf("Took %.2f seconds to create %s\n", toc(stime), fnChi);
end % profile2diss