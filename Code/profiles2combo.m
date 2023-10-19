% Combine the output of profile2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function profiles2combo(binned, p_filenames, pars)
arguments (Input)
    binned (:,1) cell
    p_filenames table
    pars struct
end % arguments Input

fnCombo = fullfile(pars.combo_root, "combo.mat");
if isfile(fnCombo)
    items = struct2table(dir(fullfile(pars.binned_root, pars.p_file_pattern)));
    items = items(~items.isdir,:);
    mtime = max(items.datenum);
    items = dir(fnCombo);
    if items.datenum > mtime
        fprintf("No need to rebuild combo, %s is newer than inputs\n", fnCombo);
        return;
    end
end % if isfile

nFiles = numel(binned);
t0 = NaT(size(binned));
nCasts = 0;
names = strings(0);
bins = [];
items = cell(size(binned));

for index = 1:nFiles
    item = binned{index};
    items{index} = item.info;
    t0(index) = item.info.t0(1);
    nCasts = nCasts + size(item.tbl.t,2);
    bins = union(bins, item.tbl.bin);
    names = union(names, string(item.tbl.Properties.VariableNames));
end % for index

[~, ix] = sort(t0);
binned = binned(ix);

items = vertcat(items{ix});

[~, ix] = sort(lower(names)); % Dictionary sort for humans
names = names(ix);
names = ["bin"; "t"; setdiff(names, ["bin", "t"])];

nBins = numel(bins); % Number of depth bins

tbl = table();
tbl.bin = bins;
tbl.t = NaT(nBins, nCasts);
for name = names(3:end)'
    tbl.(name) = nan(nBins, nCasts);
end % for name

offset = 0;

for index = 1:numel(binned)
    a = binned{index}.tbl;
    [~, iLHS, iRHS] = innerjoin(tbl, a, "Keys", "bin");
    a = a(iRHS,:);
    width = size(a.t,2);
    ii = (1:width) + offset;
    offset = offset + width;

    for name = string(a.Properties.VariableNames)
        if name == "bin", continue; end
        tbl.(name)(iLHS,ii) = a.(name);
    end % for name
end % for index

data = struct();
data.tbl = tbl;
data.info = items;

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
save(fnCombo, "-struct", "data", pars.matlab_file_format);
end % ctd2combo