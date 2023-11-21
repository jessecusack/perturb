%
% Pour a table into a NetCDF file
%
% If the table column name is in nameMap, the NetCDF variable will be renamed
%
% If fnJSON exists and the NetCDF variable name is in the vars section, then
% the values are treated as attributes
%
% July-2023, Pat Welch, pat@mousebrains.com

function mk_NetCDF(fn, tbl, info, fnJSON)
arguments (Input)
    fn string                 % Output filename
    tbl (:,:) table           % Input data
    info struct               % parameters from getInfo
    fnJSON string             % JSON file defining variable attributes
end % arguments

fn = abspath(fn); % Matlab's netcdf does not like ~, so make absolute

if exist(fn, "file"), delete(fn); end

[attrG, attrV, nameMap, compressionLevel, dimensions] = nc_load_JSON(fnJSON, info, tbl);

dimNames = string(fieldnames(dimensions));

fprintf("Writing %s\n", fn);
ncid = netcdf.create(fn, ... % Create a fresh copy
    bitor(netcdf.getConstant("CLOBBER"), netcdf.getConstant("NETCDF4")));

nc_put_attribute(ncid, netcdf.getConstant("NC_GLOBAL"), attrG); % Add any global attributes

dimIDs = nan(size(dimNames));

for index = 1:numel(dimNames) % Create dimensions
    key = dimNames(index);
    dName = dimensions.(key);
    dimIDs(index) = netcdf.defDim(ncid, dName, size(tbl.(key), index));
end % for index

varID = nc_create_variables(ncid, dimIDs, nameMap, tbl, attrV, compressionLevel);
netcdf.endDef(ncid);

nc_put_variable(ncid, varID, tbl);

netcdf.close(ncid);
end % mk_NetCDF
