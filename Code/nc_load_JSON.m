%
% Load a JSON file defining attributes for a NetCDF file
%
% July-2023, Pat Welch, pat@mousebrains.com

function [attrG, attrV, nameMap, compressionLevel, dimensions, globalMap] = ...
		nc_load_JSON(fn, info, tbl)
arguments (Input)
    fn string % Input JSON filename
    info struct % parameters, defaults from get_info
    tbl table % data 
end % arguments
arguments (Output)
    attrG struct % Global attributes
    attrV struct % Variable specific attributes
    nameMap struct % table column names to NetCDF variable names
    compressionLevel int8 % variable compression level
    dimensions struct % dimension names
    globalMap struct % Global attribute map from JSON file
end % arguments output

if exist(fn, "file")
    attr = jsondecode(fileread(fn));
else
    attr = struct();
end % if

for name = ["compressionLevel", "nameMap", "global", "vars", "dimensions", "globalMap"]
    if ~isfield(attr, name)
        attr.(name) = struct();
    end % if
end % for

attrG = nc_add_global_attributes(attr.global, info);
attrG = nc_add_global_ranges(attrG, tbl, attr.globalMap);
attrV = attr.vars;
nameMap = attr.nameMap;
compressionLevel = attr.compressionLevel;
if isempty(attr.compressionLevel), compressionLevel = -1; end

dimensions = attr.dimensions;
globalMap = attr.globalMap;
end % nc_load_JSON
