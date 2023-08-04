% Set a variable's attributes from a structure
%
% July-2023, Pat Welch, pat@mousebrains.com

function nc_put_attribute(ncid, varID, attr)
arguments (Input)
    ncid double % NetCDF file id
    varID double % Variable id
    attr struct % Attributes key -> val
end % arguments Input

for key = string(fieldnames(attr))'
    val = attr.(key);
    if ischar(val), val = string(val); end
    netcdf.putAtt(ncid, varID, key, val, nc_mk_XType(val));
end % for
end % nc_put_attribute
