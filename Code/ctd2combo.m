% Combine the output of ctd2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function tbl = ctd2combo(ctd, pars)
arguments (Input)
    ctd (:,1) cell
    pars struct
end % arguments Input
arguments (Output)
    tbl table % Binned CTD data
end % arguments Output

if ~pars.CT_has || isempty(ctd), return; end

[tbl, fnCombo] = save2combo(ctd, pars);
save2NetCDF(tbl, fnCombo, pars);
end % ctd2combo

function [tbl, fnCombo] = save2combo(ctd, pars)
arguments (Input)
    ctd (:,1) cell
    pars struct
end % arguments Input
arguments (Output)
    tbl table % Binned CTD data
    fnCombo string % Filename of combined CTD information
end % arguments Output

tbl = table(); % In case we return early
fnCombo = fullfile(pars.ctd_combo_root, "ctd.combo.mat");

data = table();
data.fn = cellfun(@(x) x{1}, ctd);
data.data = cellfun(@(x) x{2}, ctd, "UniformOutput", false);

data = data(~ismissing(data.fn),:);

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
        fprintf("No need to rebuild CTD combo, %s is newer than inputs\n", fnCombo);
        return;
    end
    fprintf("Rebuilding %s due to %d files\n", fnCombo, sum(data.datenum >= item.datenum));
end % if isfile

if any(cellfun(@isempty, data.data))
    items = cell(size(data.data));
    dd = parallel.pool.Constant(data); % Doesn't change from here on
    parfor index = 1:size(data,1)
        if ~isempty(dd.Value.data{index})
            items{index} = dd.Value.data{index};
        else
            fprintf("Loading %s\n", dd.Value.fn(index));
            items{index} = load(dd.Value.fn(index)).binned;
        end % if ~isempty
    end % parfor
    delete(dd);
    data.data = items;
end % if any

nTimes = sum(rowfun(@(x) size(x, 1), data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "OutputFormat", "uniform" ...
    )); % How many profiles are there in total

names = rowfun(@(x) string(x.Properties.VariableNames), data, ...
    "InputVariables", "data", ...
    "ExtractCellContents", true, ...
    "OutputFormat", "cell" ...
    ); % Names in all the profiles
names = unique(horzcat(names{:}));

[~, ix] = sort(lower(names));
names = names(ix);
names = ["t", setdiff(names, "t")];

tbl = table();
tbl.t = NaT(nTimes,1);

for name = names(2:end)
    tbl.(name) = nan(nTimes,1);
end % for name

offset = 0;
for index = 1:numel(ctd)
    a = data.data{index};
    ii = offset + (1:size(a,1));
    offset = offset + size(a,1);
    for name = string(a.Properties.VariableNames)
        tbl.(name)(ii) = a.(name);
    end % for name
end % for index

[~, ix] = unique(tbl.t); % Should be sorted, but who knows
tbl = tbl(ix,:);

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
save(fnCombo, "tbl", pars.matlab_file_format);
end % ctd2combo

function save2NetCDF(tbl, fnCombo, pars)
arguments (Input)
    tbl table
    fnCombo string {mustBeFile}
    pars struct
end % arguments Input

[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));

if isnewer(fnNC, fnCombo)
    fprintf("No need to rebuild %s\n", fnNC);
    return;
end % if isnewer

if isempty(tbl)
    fprintf("Loading %s\n", fnCombo);
    tbl = load(fnCombo).tbl;
end % if isempty

fnCDL = fullfile(fileparts(mfilename("fullpath")), "CTD.json");
mk_NetCDF(fnNC, tbl, pars, fnCDL);
end % save2NetCDF