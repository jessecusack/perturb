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

[a, fnCombo] = save2combo(binned, pars);
save2NetCDF(a, fnCombo, pars);
end % profiles2combo

function [a, fnCombo] = save2combo(binned, pars)
arguments (Input)
    binned (:,1) cell
    pars struct
end % arguments Input
arguments (Output)
    a table
    fnCombo string
end % arguments Output

a = table(); % Empty table for early returns
fnCombo = fullfile(pars.combo_root, "combo.mat");

data = table();
data.fn = cellfun(@(x) x{1}, binned);
data.data = cellfun(@(x) x{2}, binned, "UniformOutput", false);

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
        fprintf("No need to rebuild Profile combo, %s is newer than inputs\n", fnCombo);
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
    "OutputFormat", "cell" ...
    ); % Names in all the profiles
names = unique(horzcat(names{:}));
[~, ix] = sort(lower(names));
names = names(ix);
names = ["bin", "t", setdiff(names, ["bin", "t"])];

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
for name = names(3:end)
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
end % save2combo

function save2NetCDF(a, fnCombo, pars)
arguments (Input)
    a
    fnCombo string {mustBeFile}
    pars struct
end % arguments Input

[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));

if isnewer(fnNC, fnCombo)
    fprintf("No need to rebuild %s\n", fnNC);
    return;
end % if isnewer

if isempty(a)
    fprintf("Loading %s\n", fnCombo);
    a = load(fnCombo);
end % if isempty

fnCDL = fullfile(fileparts(mfilename("fullpath")), "Combo.json");
my_mk_NetCDF(fnNC, a, pars, fnCDL);
end % save2NetCDF

%
% This is a bastardized version of mk_NetCDF
%
% July-2023, Pat Welch, pat@mousebrains.com

function my_mk_NetCDF(fnNC, combo, pars, fnJSON)
arguments (Input)
    fnNC string   % Output filename
    combo struct  % Input data
    pars struct   % parameters from getInfo
    fnJSON string % JSON file defining variable attributes
end % arguments

cInfo = combo.info;
tbl = combo.tbl;

cInfo = removevars(cInfo, ["name", "index"]);

[attrG, attrV, nameMap, compressionLevel] = nc_load_JSON(fnJSON, pars, cInfo);

attrG.geospatial_vertical_min = min(tbl.bin);
attrG.geospatial_vertical_max = max(tbl.bin);
attrG.geospatial_bounds_vertical = sprintf("%f,%f", ...
    attrG.geospatial_vertical_min, attrG.geospatial_vertical_max);
fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
tMin = min(cInfo.t0);
tMax = max(cInfo.t1);
attrG.time_coverage_end = string(tMax, fmt);
attrG.time_coverage_duration = sprintf("T%fS", seconds(tMax - tMin));
attrG.time_coverage_resolution = sprintf("T%fS", seconds(mk_resolution(tbl.t)));

fnNC = abspath(fnNC); % Matlab's netcdf does not like ~ in filenames, so get rid of it

if exist(fnNC, "file"), delete(fnNC); end % We say to clobber, but it still fails sometimes

fprintf("Creating %s\n", fnNC);
ncid = netcdf.create(fnNC, ... % Create a fresh copy
    bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));

nc_put_attribute(ncid, netcdf.getConstant("NC_GLOBAL"), attrG); % Add any global attributes

dimIDs = nan(2,1);
dimIDs(1) = netcdf.defDim(ncid, "bin", size(tbl,1));
dimIDs(2) = netcdf.defDim(ncid, "profile", size(cInfo,1));

varID = nc_create_variables(ncid, dimIDs(2), nameMap, cInfo, attrV, compressionLevel);
tblID = nc_create_variables(ncid, dimIDs, nameMap, tbl, attrV, compressionLevel);
netcdf.endDef(ncid);

nc_put_variable(ncid, varID, cInfo);
nc_put_variable(ncid, tblID, tbl);

netcdf.close(ncid);
end % my_mk_netCDF

function resolution = mk_resolution(t)
arguments (Input)
    t datetime % Profile timestamps
end % arguments Input
arguments (Output)
    resolution duration % time between timestamps
end % arguments Output

dt = diff(t);
n = sum(~isnan(dt));
mu = mean(dt, "omitnan");
resolution = sum(mu .* n) ./ sum(n);
end % mk_resolution