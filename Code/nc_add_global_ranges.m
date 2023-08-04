%
% Get global ranges for time/lat/lon/depth
%
% July-2023, Pat Welch, pat@mousebrains.com

function attr = nc_add_global_ranges(attr, tbl, gm)
arguments (Input)
    attr struct % Attributes to add to
    tbl (:,:) table % Data columns
    gm struct %  Geo-reference structure
end % arguments Input
arguments (Output)
    attr struct % Updated attributes
end % arguments Output

if ~isfield(gm, "time"), gm.time = "t"; end
if ~isfield(gm, "lat"), gm.lat = "lat"; end
if ~isfield(gm, "lon"), gm.lon = "lon"; end
if ~isfield(gm, "depth"), gm.depth = "depth"; end

names = string(tbl.Properties.VariableNames); % Table column names

if ismember(gm.time, names) % A time column
    fmt = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'";
    val = tbl.(gm.time);
    tMin = min(val(:));
    tMax = max(val(:));
    attr.time_coverage_start = string(tMin, fmt);
    attr.time_coverage_end = string(tMax, fmt);
    attr.time_coverage_duration = sprintf("T%fS", seconds(tMax - tMin));
    attr.time_coverage_resolution = sprintf("T%fS", seconds(median(diff(tbl.(gm.time)))));
end % if

bb = nan(2,2);

for item = [gm.lat, "lat"; gm.lon, "lon"; gm.depth, "vertical"]'
    name = item(1);
    if ismember(name, names)
        prefix = append("geospatial_", item(2), "_");
        val = tbl.(name);
        vMin = min(val(:), [], "omitmissing");
        vMax = max(val(:), [], "omitmissing");
        attr.(append(prefix, "min")) = vMin;
        attr.(append(prefix, "max")) = vMax;
        switch name
            case gm.depth
                attr.(append(prefix, "bounds")) = sprintf("%f,%f", vMin, vMax);
            case gm.lat
                bb(1,2) = vMin;
                bb(2,2) = vMax;
            case gm.lon
                bb(1,1) = vMin;
                bb(2,1) = vMax;
        end % switch
    end % if
end % for item

if all(~isnan(bb(:)))
    attr.geospatial_bounds = ...
        sprintf("POLYGON((%f %f, %f %f, %f %f, %f %f, %f %f))", ...
        bb(1,1), bb(1,2), ...
        bb(2,1), bb(1,2), ...
        bb(2,1), bb(2,2), ...
        bb(1,1), bb(2,2), ...
        bb(1,1), bb(1,2) ...
        );
end % ~isnan
end % nc_add_global_ranges
