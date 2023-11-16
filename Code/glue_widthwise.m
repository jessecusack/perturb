%
% Glue together multiple profiles widthwise
%
% This is a rewrite of my existing code for depth binning and combo
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function binned = glue_widthwise(key, profiles, vNames, tblName)
arguments (Input)
    key string             % key to bin on
    profiles (:,1) cell    % cell array of tables to glue together
    vNames (:,1) string = strings(0) % list of variable to glue together
    tblName string = "tbl" % Table name in struct     
end % arguments Input
arguments (Output)
    binned table % Glued together table
end % arguments Output

[items, bins] = glue_extract_information(key, profiles, vNames, tblName, true);

binned = glue_build_empty_table(key, bins, items, true);
head(binned)

offset = 0; % Column offset

for index = 1:numel(profiles)
    tbl = profiles{index};

    if isstruct(tbl)
        if ~isfield(tbl, tblName)
            error("%s is not in profile %d", tblName, index);
        end % if ~isfield
        tbl = tbl.(tblName);
    end % if isstruct

    rows = items(items.index == index,:);
    width = rows.width(1); % We know they are all the same width

    [~, iLHS, iRHS] = innerjoin(binned, tbl, "Keys", key);

    ii = offset + (1:width);
    offset = offset + width;
    for name = items.name(items.index == index)'
        binned.(name)(iLHS,ii) = tbl.(name)(iRHS,:);
    end % for name
end % for index
end % glue_widthwise

