% Bin profiles into depth bins
%
% July-2023, Pat Welch, pat@mousebrains.com

function [row, retval] = diss2binned(row, profile, pars)
arguments (Input)
    row (1,:) table % row to work on
    profile struct % Output of profile2diss, struct or empty
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

fnDiss = row.fnDiss;
fnBin = fullfile(pars.diss_binned_root, append(row.name, ".mat"));
row.fnDissBin = fnBin;

if isnewer(fnBin, fnDiss)
    retval = {fnBin, []}; % We want this for combining
    fprintf("%s: %s is newer than %s\n", row.name, row.fnBin, row.fnDiss);
    return;
end % if isnewer

if isempty(profile)
    fprintf("Loading %s\n", row.fnDiss);
    profile = load(row.fnDiss);
end % if isempty

%% Bin the data into depth bins

method = pars.binDiss_method; % Which method to aggregate the data together
if ~isa(method, "function_handle")
    if method == "median"
        method = @(x) median(x, 1, "omitnan");
    elseif method == "mean"
        method = @(x) mean(x, 1, "omitnan");
    else
        error("Unrecognized binning method %s\n", method)
    end % if
end % if ~isa

dInfo = profile.info;
profiles = profile.profiles;

dz = pars.binDiss_width; % Bin stepsize (m) or (sec)

if pars.profile_direction == "time" % Bin in time
    dz = seconds(dz);
    allBins = dInfo.t0:dz:(dInfo.t1 + dz / 2);
    binName = "t";
else % Bin in depth
    minDepth = min(dInfo.min_depth, [], "omitnan"); % Minimum depth in casts
    maxDepth = max(dInfo.max_depth, [], "omitnan"); % Maximum depth in casts

    if isnan(minDepth) || isnan(maxDepth)
        row.qProfileOkay = false;
        fprintf("%s: nan in min or max depth\n", row.name);
        return;
    end % if

    allBins = (floor(minDepth*dz)/dz):dz:(maxDepth + dz/2); % Bin centroids
    binName = "depth";
end % if profile_direction

if numel(allBins) < 2
    fprintf("%s: Number of allBins, %d < 2\n", row.name, numel(allBins));
    return;
end

fprintf("%s: Binning %d diss profiles\n", row.name, size(dInfo,1));
casts = cell(size(dInfo,1),1);
names = dictionary();

% Build a pre-allocated table
nCasts = numel(casts);
nBins = numel(allBins);
tbl = table();
tbl.bin = allBins';
tbl.n = uint32(zeros(nBins, nCasts));
tbl.t = NaT(nBins, nCasts);

for index = 1:numel(profiles)
    profile = profiles{index};
    if isempty(profile), continue; end
    nE = size(profile.e,2);
    for name = setdiff(string(profile.Properties.VariableNames), "t")
        if ndims(profile.(name)) ~= 2, continue; end
        sz = size(profile.(name),2);
        if sz == 1
            tbl.(name) = nan(nBins, nCasts);
        elseif sz == nE
            for j = 1:sz
                tbl.(append(name, "_", string(j))) = nan(nBins, nCasts);
            end % for j
        end % if sz
    end % for name
end % for index

% Bin profiles into tbl
for index = 1:numel(profiles)
    st = tic();
    profile = profiles{index};
    profile.bin = interp1(allBins-dz/2, tbl.bin, profile.(binName), "previous"); % Might be empty
    if isdatetime(profile.bin)
        profile = profile(~isnat(profile.bin),:);
    else
        profile = profile(~isnan(profile.bin),:); % Drop nan bins (I don't think this should happen)
    end

    if isempty(profile)
        fprintf("%s No bins found for diss profile %d in %s\n", row.name, index);
        continue;
    end % No diss data to work with

    profile.grp = findgroups(profile.bin); % Bin group
    grp2bin = rowfun(@(x) x(1), profile, ...
        "InputVariables", "bin", ...
        "GroupingVariables", "grp", ...
        "OutputVariableNames", "bin");

    [~, iLHS, iRHS] = innerjoin(tbl, grp2bin, "Keys", "bin"); % Match bin to bin
    tbl.n(iLHS,index) = grp2bin.GroupCount(iRHS);

    vNames = setdiff(string(profile.Properties.VariableNames), ["bin", "grp"]);
    nE = size(profile.e, 2);

    for j = 1:numel(vNames)
        vName = vNames(j);
        if ndims(profile.(vName)) ~= 2, continue; end
        sz = size(profile.(vName),2);
        if ~ismember(sz, [1, nE]), continue; end

        rhs = rowfun(method, profile, ...
            "InputVariables", vName, ...
            "GroupingVariables", "grp", ...
            "OutputVariableNames", vName);

        if sz == 1
            tbl.(vName)(iLHS,index) = rhs.(vName)(iRHS);
        elseif sz == nE
            for k = 1:sz
                tbl.(append(vName, "_", string(k)))(iLHS,index) = rhs.(vName)(iRHS,k);
            end % for k
        end % if sz
    end % for j
end % for index

tbl = tbl(any(tbl.n ~= 0, 2),:);

binned = struct ( ...
    "tbl", tbl, ...
    "info", dInfo);

my_mk_directory(fnBin);
save(fnBin, "-struct", "binned", pars.matlab_file_format);
fprintf("%s: Saving %d profiles to %s\n", row.name, size(dInfo,1), fnBin);
retval = {fnBin, binned};
end % bin_data
