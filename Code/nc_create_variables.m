%
% Create a variable with attributes and ranges
%
% July-2023, Pat Welch, pat@mousebrains.com

function varID = nc_create_variables(ncid, dimIDs, nameMap, tbl, attrV, compressionLevel)
arguments (Input)
    ncid double % NetCDF Id
    dimIDs double % Dimension ids for this variable
    nameMap struct % mapping from table columns to NetCDF variables
    tbl table % Variable data
    attrV struct % Variable attributes
    compressionLevel int8 = -1 % How much to compress the data, <0 => no compression
end % arguments
arguments (Output)
    varID double % Array of variable IDs for table columns
end % arguments

names = string(tbl.Properties.VariableNames);

varID = nan(size(tbl,2),1);

for index = 1:numel(names)
    name = names(index);
    val = tbl.(name);
    if isfield(nameMap, name)
        nameNC = nameMap.(name);
    else
        nameNC = name;
    end

    if isrow(val) || iscolumn(val)
        dID = dimIDs(1);
    else
        dID = dimIDs;
    end % if isrow

    varID(index) = netcdf.defVar(ncid, nameNC, nc_mk_XType(val), dID);
    if compressionLevel >= 0 && ~isstring(val)
        netcdf.defVarDeflate(ncid, varID(index), false, true, compressionLevel);
    end % if compressioinLevel
    if ~isfield(attrV, nameNC), attrV.(nameNC) = struct(); end
    attr = attrV.(nameNC);
    switch class(val)
        case "datetime"
            attr.valid_min = posixtime(min(val(:), [], "omitnan"));
            attr.valid_max = posixtime(max(val(:), [], "omitnan"));
            attr.units = "seconds since 1970-01-01 00:00:00";
            attr.calendar = "proleptic_gregorian";
        case "logical"
            attr.dtype = "bool";
            attr.valid_min = min(val(:), [], "omitnan");
            attr.valid_max = max(val(:), [], "omitnan");
        case {"char", "string"}
            ;
        otherwise
            attr.valid_min = min(val(:), [], "omitnan");
            attr.valid_max = max(val(:), [], "omitnan");
    end
    nc_put_attribute(ncid, varID(index), attr);
end % for
end % nc_create_variables
