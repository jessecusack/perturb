%
% Convience function used by glue_widthwise and glue_lengthwise
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [items, bins] = glue_extract_information(key, profiles, cNames, tblName, qWidthCheck)
arguments (Input)
    key string          % column name to join on
    profiles (:,1) cell % Collection of tables to extract information from
    cNames (:,1) string % List of columns to extract
    tblName string = "tbl" % For profiles which are struct, the name of the data table
    qWidthCheck logical = true % Should all the columns in cNames have the same width?
end % arguments Input
arguments (Output)
    items table % Information about each profile, one row per profile 
    bins        % column vector of binned values from all the profiles
end % arguments Output

qcNames = numel(cNames) > 0; % Check if vNames was specified or not

% First rip through the profiles and find the full set of names and sizes
items = cell(numel(profiles), 1); % cell array of tables with information on each profile
bins  =  cell(numel(profiles),1);

for index = 1:numel(profiles)
    tbl = profiles{index};

    if isstruct(tbl)
        if ~isfield(tbl, tblName)
            error("%s is not in profile %d", tblName, index);
        end % if ~isfield
        tbl = tbl.(tblName);
    end % if isstruct

    tblNames = string(tbl.Properties.VariableNames)';
    if ~ismember(key, tblNames)
        error("Key, %s, is not in profile %d's table", key, index);
    end % if ~ismember key

    if size(tbl.(key),2) ~= 1
        error("%s is not a vector, %d, in profile %d", key, size(tbl.(key),2), index);
    end % if size

    item = table();
    if qcNames
        item.name = intersect(cNames, tblNames);
    else
        item.name = setdiff(tblNames, key);
    end % if qvNames

    item.index = index + zeros(size(item.name));
    item.width = nan(size(item.name));
    item.class = strings(size(item.name));

    bins{index} = tbl.(key);
    
    for j = 1:size(item,1)
        name = item.name(j);
        if ~ismatrix(tbl.(name))
            error("%s has %d dimensions in profile %d, only 1 or 2 are supported", ...
                name, ndims(tbl.(name)), index);
        end % if ismatrix
        item.width(j) = size(tbl.(name),2);
        item.class(j) = class(tbl.(name));
    end % for j

    if qWidthCheck && any(item.width(1) ~= item.width)
        disp(item);
        error("Not all columns have the same second dimension in profile %s", index);
    end % if any
    items{index} = item;
end % for index

items = vertcat(items{:});
bins  = unique(vertcat(bins{:}));
end % glue_extract_information