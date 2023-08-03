% Trim the initial part of profiles before the VMP is stable and out of the prop wash

function pInfo = trim_profiles(profiles, pInfo, info)
arguments (Input)
    profiles cell % Cell array of individual profiles
    pInfo table % Summary information for each profile
    info struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    pInfo table % Updated summary information for each profile
end % arguments Input
%%
dz = info.trim_dz;
bins = info.trim_minDepth:dz:info.trim_maxDepth; % Depth bins for variance estimates

qMinDepth = bins(1) - dz/2;
qMaxDepth = bins(end) + dz/2;

nProfiles = numel(profiles);
pInfo.trimDepth = nan(nProfiles,1);
pInfo.trimMaxDepth = nan(nProfiles,1);

casts = cell(nProfiles,1);

for index = pInfo.index'
    profile = profiles{index};
    fast = profile.fast;
    slow = profile.slow;
    fast = fast(fast.P_fast >= qMinDepth & fast.P_fast <= qMaxDepth, ["P_fast", "Ax", "Ay", "sh1", "sh2", "W_fast"]);
    slow = slow(slow.P_slow >= qMinDepth & slow.P_slow <= qMaxDepth, ["P_slow", "Incl_Y", "Incl_X"]);
    fast.bin = interp1(bins, bins, fast.P_fast, "nearest");
    slow.bin = interp1(bins, bins, slow.P_slow, "nearest");
    fast.grp = findgroups(fast.bin);
    slow.grp = findgroups(slow.bin);
    pFast = rowfun(@(x) x(1), fast, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "P");
    pSlow = rowfun(@(x) x(1), slow, "InputVariables", "bin", "GroupingVariables", "grp", "OutputVariableNames", "P");
    for name = setdiff(string(fast.Properties.VariableNames), ["bin", "grp", "P_fast"])
        a = rowfun(@(x) var(x, "omitmissing"), fast, "InputVariables", name, "GroupingVariables", "grp", "OutputVariableNames", name);
        pFast.(name) = sqrt(a.(name));
    end % for name fast
    for name = setdiff(string(slow.Properties.VariableNames), ["bin", "grp", "P_slow"])
        a = rowfun(@(x) var(x, "omitmissing"), slow, "InputVariables", name, "GroupingVariables", "grp", "OutputVariableNames", name);
        pSlow.(name) = sqrt(a.(name));
    end % for name slow
    [~, ileft, iright] = innerjoin(pFast, pSlow, "Keys", "grp");
    if ~isempty(ileft)
        joint = pFast(ileft,:);
        joint.nSlow = pSlow.GroupCount(iright);
        joint.Incl_X = pSlow.Incl_X(iright);
        joint.Incl_Y = pSlow.Incl_Y(iright);
        casts{index} = joint;
    end % if ~isempty
end % for index

qKeep = ~cellfun(@isempty, casts); % casts to keep
if ~any(qKeep)
    fprintf("WARNING: No trimable casts found in %s %s\n", pInfo.sn(1), pInfo.basename(1));
    return;
end % if ~any

casts = casts(qKeep); % Drop empty casts

names = ["Ax", "Ay", "W_fast", "sh1", "sh2", "Incl_X", "Incl_Y"];
a = vertcat(casts{:}); % Combine all the casts to get the median value for the variables
depths = table();
for i = 1:numel(names)
    name = names(i);
    aMid = median(a.(name), "omitmissing");
    depths.(name) = nan(numel(casts),1);
    for j = 1:numel(casts)
        cast = casts{j};
        ix = find(cast.(name) < aMid, 1, "first");
        if ~isempty(ix)
            depths.(name)(j) = cast.P(ix);
        end % if ~isempty
    end % for i
end % for name

depths = table2array(depths);
minDepth = quantile(depths, info.trim_quantile, 2);
pInfo.trimDepth(qKeep) = minDepth;
pInfo.trimMaxDepth(qKeep) = max(depths, [], 2);
end % trim_profiles
