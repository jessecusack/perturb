%
% Convience routine for glue_widthwise and glue_lengthwise
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function tbl = glue_build_empty_table(key, bins, items, qHorizontal)
arguments (Input)
    key string  % bin column name
    bins (:,1)  % Column of bin values, can be any type
    items table % Output of glue_extract_information
    qHorizontal logical % Check if widths are consistent between profiles
end % arguments Input
arguments (Output)
    tbl table % An empty table
end

tbl = table();
tbl.(key) = bins;
nBins = size(tbl,1);

if qHorizontal
    items.grp = findgroups(items.index);
    nWide = sum(rowfun(@(x) x(1), items, ...
        "InputVariables", "width", ...
        "GroupingVariables", "grp", ...
        "OutputFormat", "uniform"));
else
    nWide = nan;
end %

for name = unique(items.name)'
    rows = items(items.name == name,:);
  
    if ~qHorizontal
        nWide = rows.width(1);
        if any(nWide ~= rows.width) % All the profiles should have the same width
            disp(rows);
            error("%s has different widths between profiles", name);
        end % if any
    end
 
    if any(rows.class(1) ~= rows.class) % All the profiles must have the same data type
        disp(rows)
        error("%s has different types between profiles", name);
    end % if any

    switch rows.class(1)
        case "double"
            tbl.(name) = nan(nBins, nWide);
        case "datetime"
            tbl.(name) = NaT(nBins, nWide);
        case "duration"
            tbl.(name) = seconds(zeros(nBins, nWide));
        case "uint64"
            tbl.(name) = uint64(zeros(nBins, nWide));
        case "int64"
            tbl.(name) = int64(zeros(nBins, nWide));
        case "uint32"
            tbl.(name) = uint32(zeros(nBins, nWide));
        case "int32"
            tbl.(name) = int32(zeros(nBins, nWide));
        case "uint16"
            tbl.(name) = uint16(zeros(nBins, nWide));
        case "int16"
            tbl.(name) = int16(zeros(nBins, nWide));
        case "uint8"
            tbl.(name) = uint8(zeros(nBins, nWide));
        case "int8"
            tbl.(name) = int8(zeros(nBins, nWide));
        otherwise
            error("%s has an unknown type, %s", name, rows.type(1));
    end % switch
end % for name
end % glue_build_empty_tables