%
% Put table variables to a file
%
% July-2023, Pat Welch, pat@mousebrains.com

function nc_put_variable(ncid, varID, tbl)
arguments (Input)
    ncid double % NetCDF file id
    varID (:,1) double % Array of NetCDF variable ids ordered like table columns
    tbl table % table of data to write
end % arguments Input

names = string(tbl.Properties.VariableNames);

for index = 1:numel(names)
    name = names(index);
    ident = varID(index);
    val = tbl.(name);
    switch class(val)
        case "datetime"
            val = posixtime(val);
        case "logical"
            val = uint8(val);
        case "char"
            val = string(val);
    end % switch
    netcdf.putVar(ncid, ident, val);
end % for index
end % nc_put_variable
