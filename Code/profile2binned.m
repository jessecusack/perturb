% Bin profiles into depth bins
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval] = profile2binned(row, a, pars)
arguments (Input)
    row table % row to work on
    a struct % Output of mat2profile
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    row table % row worked on
    retval (2,1) cell % {filename or missing, empty or binned profiles}
end % arguments Output

if ~row.qProfileOkay
    retval = {missing, []};
    return;
end % if ~row.qProfileOkay

fnProf = row.fnProf;
fnBin = fullfile(pars.binned_root, append(row.name, ".mat"));
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

%% Bin the data into depth bins

dz = pars.bin_width; % Bin stepsize (m)

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
casts = cell(numel(profiles,1),1);

minDepth = min(pInfo.min_depth, [], "omitnan"); % Minimum depth in casts
maxDepth = max(pInfo.max_depth, [], "omitnan"); % Maximum depth in casts

if isnan(minDepth) || isnan(maxDepth)
    retval = {missing, []};
    row.qProfileOkay = false;
    fprintf("%s: nan in min or max depth\n", row.name);
    return;
end % if

allBins = (floor(minDepth*dz)/dz):dz:(maxDepth + dz/2); % Bin centroids

if numel(allBins) < 2
    retval = {missing, []};
    row.qProfileOkay = false;
    fprintf("%s: Number of allBins, %d < 2\n", row.name, numel(allBins));
    return;
end

for index = 1:numel(profiles)
    profile = profiles{index};

    fast = profile.fast;
    slow = profile.slow;

    fast.bin = interp1(allBins-dz/2, allBins, fast.depth, "previous"); % -dz/2 to find bin centroid
    slow.bin = interp1(allBins-dz/2, allBins, slow.depth, "previous");

    fast = fast(~isnan(fast.bin),:); % Take off values above the first bin
    slow = slow(~isnan(slow.bin),:);

    if isfield(profile, "diss") && isfield(profile.diss, "tbl") && ~isempty(profile.diss.tbl)
        diss = profile.diss.tbl;
        diss.bin = interp1(allBins-dz/2, allBins, diss.depth, "previous"); % Might be empty
        diss = diss(~isnan(diss.bin),:);
    else
        diss = table();
    end % if

    if isfield(profile, "bbl") && isfield(profile.bbl, "tbl") && ~isempty(profile.bbl.tbl)
        bbl = profile.bbl.tbl;
        bbl.bin = interp1(allBins-dz/2, allBins, bbl.depth, "previous"); % Might be empty
        bbl = bbl(~isnan(bbl.bin),:);
    else
        bbl = table();
    end % if

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

    %%
    %
    % Dissipation is special and we're only going to work with e
    % and FM, figure of merit = mad*sqrt(dof_spec),
    % mad = mean absolute deviation,
    % dof_spec = degrees of freedom in each dissipation estimate
    %
    % e and FM are nxp matrices where
    %   n is the number of probes and
    %   p is the number of pressure bins

    if ~isempty(diss) % Top downwards
        tblD = bin_diss(diss, "diss", method);
        tbl = outerjoin(tbl, tblD, "Keys", "bin", "MergeKeys", true);
    end % if ~isempty diss

    if ~isempty(bbl) % Bottom upwards
        tblB = bin_diss(bbl, "bbl", method);
        tbl = outerjoin(tbl, tblB, "Keys", "bin", "MergeKeys", true);
    end % if ~isempty bbl
    %%

    casts{index} = tbl;
end % for index

qDrop = cellfun(@isempty, casts); % This shouldn't happend
if any(qDrop)
    casts = casts(~qDrop);
    pInfo = pInfo(~qDrop,:);
end % any qDrop

if isempty(casts)
    retval = {missing, []};
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
    [~, iLeft, iRight] = innerjoin(tbl, rhs, "Keys", "bin");
    if isempty(iLeft)
        disp(head(tbl));
        disp(head(rhs));
        error("Unexpected empty innerjoin");
    end % if isempty
    for name = setdiff(string(rhs.Properties.VariableNames), "bin")
        try
            tbl.(name)(iLeft,iCast) = rhs.(name)(iRight);
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
end % bin_data

function tbl = bin_diss(diss, suffix, method)
arguments
    diss table
    suffix string
    method function_handle
end

logNormalNames = ["e", "epsilonMean"];

suffix = append("_", suffix);

names = string(diss.Properties.VariableNames);
[~, ix] = sort(lower(names)); % Dictionary sort for humans
names = names(ix);

grp = findgroups(diss.bin);

tbl = table();
tbl.cnt = splitapply(@numel, diss.t, grp);

for name = setdiff(names, "t")
    qLog = ismember(name, logNormalNames); % Is this a log normal column
    val = diss.(name);
    if qLog, val = log(val); end
    tbl.(name) = splitapply(method, val, grp);
    if qLog, tbl.(name) = exp(tbl.(name)); end
end % for

names = setdiff(string(tbl.Properties.VariableNames), "bin");
names = names(~endsWith(names, suffix));
tbl = renamevars(tbl, names, append(names, suffix));
end % bin_diss
