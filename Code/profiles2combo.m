% Combine the output of profile2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function profiles2combo(binned, pars)
arguments (Input)
    binned (:,1) cell
    pars struct
end % arguments Input

data = table();
data.fn = cellfun(@(x) x{1}, binned);
data.data = cellfun(@(x) x{2}, binned, "UniformOutput", false);

data = data(~ismissing(data.fn),:);

fnCombo = fullfile(pars.combo_root, "combo.mat");
if isfile(fnCombo)
    data.datenum = nan(size(data.fn));
    for index = 1:size(data,1)
        fn = data.fn(index);
        if isfile(fn)
            item = dir(fn);
            data.datenum(index) = item(1).datenum;
        else
            fprintf("WARNING: %s does not exist!\n", fn);
            data.fn(index) = missing;
        end % if
    end % for index
    mtime = max(data.datenum, [], "omitnan");
    item = dir(fnCombo);
    if item.datenum > mtime
        fprintf("No need to rebuild Profile combo, %s is newer than inputs\n", fnCombo);
        return;
    end
    fprintf("Rebuilding %s\n", fnCombo);
    disp(data.fn(data.datenum >= item.datenum));
end % if isfile

if any(cellfun(@isempty, data.data))
    items = cell(size(data.data));
    dd = parallel.pool.Constant(data); % Doesn't change from here on
    parfor index = 1:size(data,1)
        if ~isempty(dd.Value.data{index})
            items{index} = dd.Value.data{index};
        else
            fprintf("Loading %s\n", dd.Value.fn(index));
            items{index} = load(dd.Value.fn(index));
        end % if ~isempty
    end % parfor
    delete(dd);
    data.data = items;
end % if any

t0 = rowfun(@(x) x.info.t0(1), data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "OutputFormat", "uniform" ...
    );

[~, ix] = sort(t0);
data = data(ix,:); % Time sort the files

nCasts = sum(rowfun(@(x) size(x.tbl.t,2), data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "OutputFormat", "uniform" ...
    )); % How many profiles are there in total

names = rowfun(@(x) string(x.tbl.Properties.VariableNames), data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "OutputVariableNames", "a" ...
    ); % Names in all the profiles
names = unique(names.a(:));
[~, ix] = sort(lower(names));
names = names(ix);
names = ["bin"; "t"; setdiff(names, ["bin", "t"])];

bins = rowfun(@(x) x.tbl.bin, data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "Outputformat", "cell" ...
    ); % The depth bins
bins = unique(vertcat(bins{:})); % Unique and sorted depth bins
nBins = numel(bins); % Number of depth bins

tbl = table();
tbl.bin = bins;
tbl.t = NaT(nBins, nCasts);
for name = names(3:end)'
    tbl.(name) = nan(nBins, nCasts);
end % for name

offset = 0; % Cast offset
items = cell(size(data.data));

for index = 1:numel(binned)
    a = data.data{index}.tbl;
    items{index} = data.data{index}.info;
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

items = vertcat(items{:});

a = struct();
a.tbl = tbl;
a.info = items;

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
save(fnCombo, "-struct", "a", pars.matlab_file_format);
end % ctd2combo