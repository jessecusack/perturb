% return the NetCDF data type from the variables data type
%
% July-2023, Pat Welch, pat@mousebrains.com

function x = nc_mk_XType(val)
arguments (Input)
    val % variable to get NetCDF data type for
end % arguments Input
arguments (Output)
    x double % NetCDF data type
end % arguments Output

switch class(val)
    case {"double", "datetime"}
        x = netcdf.getConstant("NC_DOUBLE");
    case {"string", "char"}
        x = netcdf.getConstant("NC_STRING");
    case "logical"
        x = netcdf.getConstant("NC_UBYTE");
    case "uint16"
        x = netcdf.getConstant("NC_USHORT");
    case "int16"
        x = netcdf.getConstant("NC_SHORT");
    case "uint32"
        x = netcdf.getConstant("NC_UINT");
    case "int32"
        x = netcdf.getConstant("NC_INT");
    case "uint64"
        x = netcdf.getConstant("NC_UINT64");
    case "int64"
        x = netcdf.getConstant("NC_INT64");
    otherwise
        error("Unrecognized type %s", class(val));
end % switch
end % nc_mk_XType
