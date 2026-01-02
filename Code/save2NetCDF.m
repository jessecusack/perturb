% Called by diss2combo and profiles2combo to write out a NetCDF version of the combo file
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function save2NetCDF(a, fnCombo, pars, fnCDL)
arguments (Input)
    a struct
    fnCombo string {mustBeFile}
    pars struct
    fnCDL string = missing
end % arguments Input

[dirname, basename] = fileparts(fnCombo);
fnNC = fullfile(dirname, append(basename, ".nc"));

if isnewer(fnNC, fnCombo)
    fprintf("No need to rebuild %s\n", fnNC);
    return;
end % if isnewer

if isempty(a) || isempty(fieldnames(a))
    fprintf("Loading %s\n", fnCombo);
    a = load(fnCombo);
end % if isempty

if ismissing(fnCDL)
    fnCDL = fullfile(fileparts(mfilename("fullpath")), "Combo.json");
end % if ismissing

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

cNames = string(cInfo.Properties.VariableNames);
tNames = string(tbl.Properties.VariableNames);

if ismember("lat", cNames)
    attrG.geospatial_lat_min = min(cInfo.lat, [], "omitnan");
    attrG.geospatial_lat_max = max(cInfo.lat, [], "omitnan");
    attrG.geospatial_lon_min = min(cInfo.lon, [], "omitnan");
    attrG.geospatial_lon_max = max(cInfo.lon, [], "omitnan");
elseif ismember("lat", tNames)
    attrG.geospatial_lat_min = min(tbl.lat, [], "omitnan");
    attrG.geospatial_lat_max = max(tbl.lat, [], "omitnan");
    attrG.geospatial_lon_min = min(tbl.lon, [], "omitnan");
    attrG.geospatial_lon_max = max(tbl.lon, [], "omitnan");
end % geospatial lat/lon

if isfield(attrG, "geospatial_lat_min")
    attrG.geospatial_lat_resolution = "0.000001"; % Just a filler
    attrG.geospatial_lon_resolution = "0.000001";
    attrG.geospatial_lat_units = "degrees_north";
    attrG.geospatial_lon_units = "degrees_east";
    attrG.geospatial_bounds_crs = "EPSG:4326";
    attrG.geospatial_bounds = sprintf("POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))", ...
        attrG.geospatial_lat_min, attrG.geospatial_lon_min, ...
        attrG.geospatial_lat_min, attrG.geospatial_lon_max, ...
        attrG.geospatial_lat_max, attrG.geospatial_lon_max, ...
        attrG.geospatial_lat_max, attrG.geospatial_lon_min, ...
        attrG.geospatial_lat_min, attrG.geospatial_lon_min ...
        );
end

if ismember("min_depth", cNames)
    attrG.geospatial_vertical_min = min(cInfo.min_depth, [], "omitnan");
    attrG.geospatial_vertical_max = max(cInfo.max_depth, [], "omitnan");
elseif ismember("depth", tNames)
    attrG.geospatial_vertical_min = min(tbl.depth, [], "omitnan");
    attrG.geospatial_vertical_max = max(tbl.depth, [], "omitnan");
end % if 

if isfield(attrG, "geospatial_vertical_min")
    attrG.geospatial_vertical_positive = "down";
    attrG.geospatial_bounds_vertical_crs = "5734"; % AIOC95_Depth
    attrG.geospatial_vertical_units = "meters";
    attrG.geospatial_vertical_resolution = 0.001;
    attrG.geospatial_bounds_vertical = sprintf("%f,%f", ...
        attrG.geospatial_vertical_min, attrG.geospatial_vertical_max);
end % if isreal

fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
tMin = min(cInfo.t0);
tMax = max(cInfo.t1);
attrG.time_coverage_start = string(tMin, fmt);
attrG.time_coverage_end = string(tMax, fmt);
attrG.time_coverage_duration = sprintf("T%fS", seconds(tMax - tMin));
attrG.time_coverage_resolution = sprintf("T%fS", seconds(mk_resolution(tbl.t)));

fnNC = abspath(fnNC); % Matlab's netcdf does not like ~ in filenames, so get rid of it

if exist(fnNC, "file")
    try
        delete(fnNC);
    catch ME
        warning("Failed to delete existing NetCDF file %s: %s", fnNC, ME.message);
    end
end % We say to clobber, but it still fails sometimes

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
