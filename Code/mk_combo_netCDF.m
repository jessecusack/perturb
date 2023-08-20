% Create a NetCDF version of the combo mat file
%
% There are two tables in the file, info and tbl
%
% We'll have two dimensions, info.t0 and tbl.bin, so special from mk_netCDF
%
% July-2023, Pat Welch, pat@mousebrains.com
%

function mk_combo_netCDF(info)
arguments (Input)
    info struct % Parameters, defaults from get_info.m
end % arguments

fnCombo = info.combo_filename;
[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));

if isnewer(fnNC, fnCombo)
    fprintf("No need to rebuild %s\n", fnNC);
    return;
end % if isnewer

combo = load(fnCombo); % info and tbl

myDir = fileparts(mfilename("fullpath"));
fnCDL = fullfile(myDir, "Combo.json");

my_mk_netCDF(fnNC, combo, info, fnCDL);
end % mk_combo_netCDF

%
% This is a bastardized version of mkNetCDF
%
% July-2023, Pat Welch, pat@mousebrains.com

function my_mk_netCDF(fn, combo, info, fnJSON)
arguments (Input)
    fn string     % Output filename
    combo struct  % Input data
    info struct   % parameters from getInfo
    fnJSON string % JSON file defining variable attributes
end % arguments

cInfo = combo.info;
tbl = combo.tbl;

cInfo = removevars(cInfo, ["basename", "qUse", "fnM", "fnProf", "fnBin", "index"]);

[attrG, attrV, nameMap, compressionLevel] = nc_load_JSON(fnJSON, info, cInfo);

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

fn = abspath(fn); % Matlab's netcdf does not like ~ in filenames, so get rid of it

if exist(fn, "file"), delete(fn); end

fprintf("Creating %s\n", fn);
ncid = netcdf.create(fn, ... % Create a fresh copy
    bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));

nc_put_attribute(ncid, netcdf.getConstant("NC_GLOBAL"), attrG); % Add any global attributes

dimIDs = nan(2,1);
dimIDs(1) = netcdf.defDim(ncid, "bin", size(tbl,1));
dimIDs(2) = netcdf.defDim(ncid, "time", size(cInfo,1));

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
mu = mean(dt, "omitmissing");
resolution = sum(mu .* n) ./ sum(n);
end % mk_resolution
