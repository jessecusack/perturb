%
% Add global attributes from info into attr
%
% July-2023, Pat Welch, pat@mousebrains.com

function attr = nc_add_global_attributes(attr, info)
arguments
    attr struct % Structure of attributes, key/value
    info struct % Parameters, defaults from get_info
end % arguments

now = string(datetime(), "yyyy-MM-dd'T'HH:mm:ss'Z'");
for name = ["date_created", "date_modified", "date_issued", "date_metadata_modified"]
    attr.(name) = now;
end

items = table();
items.name = string(fieldnames(info));
items.suffix = extractAfter(items.name, "netCDF_");
items = items(~ismissing(items.suffix),:);

for index = 1:size(items,1)
    item = items(index,:);
    val = info.(item.name);
    if ~ismissing(val)
        attr.(item.suffix) = val;
    end % if
end % for index
end % nc_add_global_attributes
