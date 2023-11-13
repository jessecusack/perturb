% Bin profiles into depth bins
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval] = profile2binned(row, a, pars)
arguments (Input)
    row (1,:) table % row to work on
    a struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % {filename or missing, empty or binned profiles}
end % arguments Output

retval = {missing, []};

if ~row.qProfileOkay
    return;
end % if ~row.qProfileOkay

fnProf = row.fnProf;
fnBin = fullfile(pars.prof_binned_root, append(row.name, ".mat"));
row.fnBin = fnBin;

if isnewer(fnBin, fnProf)
    retval = {fnBin, []}; % We want this for combining
    fprintf("%s: %s is newer than %s\n", row.name, row.fnBin, row.fnProf);
    return;
end % if isnewer

if isempty(a)
    fprintf("Loading %s\n", row.fnProf);
    a = load(row.fnProf);
end % if isempty

method = pars.bin_method; % Which method to aggregate the data together
if ~isa(method, "function_handle")
    if method == "median"
        method = @(x) median(x, 1, "omitnan");
    elseif method == "mean"
        method = @(x) mean(x, 1, "omitnan");
    else
        error("Unrecognized binning method %s\n", method)
    end % if
end % if ~isa

pInfo = a.pInfo;
profiles = a.profiles;

fprintf("%s: Binning %d profiles\n", row.name, numel(profiles));
casts = cell(numel(profiles),1);

dz = pars.bin_width; % Bin stepsize (m) or (sec)

if pars.profile_direction == "time" % Bin in time
    dz = seconds(dz);
    allBins = pInfo.t0:dz:(pInfo.t1 + dz / 2);
    binName = "t";
else % Bin in depth
    minDepth = min(pInfo.min_depth, [], "omitnan"); % Minimum depth in casts
    maxDepth = max(pInfo.max_depth, [], "omitnan"); % Maximum depth in casts

    if isnan(minDepth) || isnan(maxDepth)
        row.qProfileOkay = false;
        fprintf("%s: nan in min or max depth\n", row.name);
        return;
    end % if

    allBins = (floor(minDepth*dz)/dz):dz:(maxDepth + dz/2); % Bin centroids
    binName = "depth";
end % if profile_direction

if numel(allBins) < 2
    row.qProfileOkay = false;
    fprintf("%s: Number of allBins, %d < 2\n", row.name, numel(allBins));
    return;
end

for index = 1:numel(profiles)
    profile = profiles{index};

    fast = profile.fast;
    slow = profile.slow;

    fast.bin = interp1(allBins-dz/2, allBins, fast.(binName), "previous"); % -dz/2 to find bin centroid
    slow.bin = interp1(allBins-dz/2, allBins, slow.(binName), "previous");

    if pars.profile_direction == "time"
        fast = fast(~isnat(fast.bin),:);
        slow = slow(~isnat(slow.bin),:);
    else
        fast = fast(~isnan(fast.bin),:); % Take off values above the first bin
        slow = slow(~isnan(slow.bin),:);
    end

    if isempty(fast) || isempty(slow)
        fprintf("%s No bins found for profile %d in %s\n", row.name, index);
        continue;
    end % No fast and slow data to work with

    fast.grp = findgroups(fast.bin);
    slow.grp = findgroups(slow.bin);

    fastNames = setdiff(string(fast.Properties.VariableNames), ["bin", "grp", "t_fast", "t_fast_YD"]);
    slowNames = setdiff(string(slow.Properties.VariableNames), ["bin", "grp", "t", "t_slow", "t_slow_YD"]);

    tblF = rowfun(method, fast, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "bin");
    tblS = rowfun(method, slow, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "bin");

    for varName = slowNames
        a = rowfun(method, slow, "InputVariables", varName, "GroupingVariables", "grp", "OutputVariableNames", varName);
        tblS.(varName) = a.(varName);
    end % for slow names

    for varName = fastNames
        a = rowfun(method, fast, "InputVariables", varName, "GroupingVariables", "grp", "OutputVariableNames", varName);
        tblF.(varName) = a.(varName);
    end % for fast names

    % Merge slow and fast tables

    tblF = removevars(tblF, "grp");
    tblS = removevars(tblS, ["grp", "depth"]);

    tblF = renamevars(tblF, "GroupCount", "cntFast");
    tblS = renamevars(tblS, "GroupCount", "cntSlow");

    tbl = outerjoin(tblF, tblS, "Keys", "bin", "MergeKeys", true);

    casts{index} = tbl;
end % for index

qDrop = cellfun(@isempty, casts); % This shouldn't happend
if any(qDrop)
    casts = casts(~qDrop);
    pInfo = pInfo(~qDrop,:);
end % any qDrop

if isempty(casts)
    row.qProfileOkay = false;
    fprintf("%s: No usable casts found in %s\n", row.name, row.fnProf);
    return;
end

nCasts = numel(casts);
nBins = numel(allBins);

names = cell(size(casts));
for iCast = 1:nCasts % In case a dissipation table is empty
    rhs = casts{iCast};
    names{iCast} = string(rhs.Properties.VariableNames)';
end % for iCast
names = setdiff(unique(vertcat(names{:})), "bin");
[~, ix] = sort(lower(names)); % case-insensitive sort is for humans
names = names(ix);

tbl = table();
tbl.bin = allBins'; % Bin centroids
tbl.t = NaT(nBins,nCasts);

for name = setdiff(names, "t")'
    tbl.(name) = nan(nBins, nCasts);
end % for name

for iCast = 1:nCasts
    rhs = casts{iCast};
    [~, iLHS, iRHS] = innerjoin(tbl, rhs, "Keys", "bin");
    if isempty(iLHS)
        disp(head(tbl));
        disp(head(rhs));
        error("Unexpected empty innerjoin");
    end % if isempty
    for name = setdiff(string(rhs.Properties.VariableNames), "bin")
        try
            tbl.(name)(iLHS,iCast) = rhs.(name)(iRHS);
        catch ME
            fprintf("Error setting name %s iCast %d\n", name, iCast);
            rethrow(ME)
        end % try
    end % for name
end % for iCast;

binned = struct ( ...
    "tbl", tbl(1:end-1,:), ... % Strip off last row which will be NaN
    "info", pInfo);

my_mk_directory(fnBin);
save(fnBin, "-struct", "binned", pars.matlab_file_format);
fprintf("%s: Saving %d profiles to %s\n", row.name, size(pInfo,1), fnBin);
retval = {fnBin, binned};
end % profile2binned