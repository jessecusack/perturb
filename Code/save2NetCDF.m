% Called by diss2combo and profiles2combo to write out a NetCDF version of the combo file
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function save2NetCDF(a, fnCombo, pars)
arguments (Input)
    a struct
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

[attrG, attrV, nameMap, compressionLevel] = nc_load_JSON(fnJSON, pars, cInfo);

if isreal(tbl.bin)
    attrG.geospatial_vertical_min = min(tbl.bin);
    attrG.geospatial_vertical_max = max(tbl.bin);
    attrG.geospatial_bounds_vertical = sprintf("%f,%f", ...
        attrG.geospatial_vertical_min, attrG.geospatial_vertical_max);
end % if isreal
fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
tMin = min(cInfo.t0);
tMax = max(cInfo.t1);
attrG.time_coverage_end = string(tMax, fmt);
attrG.time_coverage_duration = sprintf("T%fS", seconds(tMax - tMin));
attrG.time_coverage_resolution = sprintf("T%fS", seconds(mk_resolution(tbl.t)));

fnNC = abspath(fnNC); % Matlab's netcdf does not like ~ in filenames, so get rid of it

if exist(fnNC, "file"), delete(fnNC); end % We say to clobber, but it still fails sometimes

fprintf("Writing %s\n", fnNC);
ncid = netcdf.create(fnNC, ... % Create a fresh copy
    bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));

nc_put_attribute(ncid, netcdf.getConstant("NC_GLOBAL"), attrG); % Add any global attributes

dimIDs = nan(2,1);
dimIDs(1) = netcdf.defDim(ncid, "bin", size(tbl,1));
dimIDs(2) = netcdf.defDim(ncid, "profile", size(cInfo,1));

varID = nc_create_variables(ncid, dimIDs(2), nameMap, cInfo, attrV, compressionLevel);

tbl = removevars(tbl, intersect(tbl.Properties.VariableNames, cInfo.Properties.VariableNames));

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
