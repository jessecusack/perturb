%
% Glue together multiple profiles lengthwise
%
% This is a rewrite of my existing code for time binning and combo
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function binned = glue_lengthwise(key, profiles, vNames, tblName)
arguments (Input)
    key string                    % key to bin on
    profiles (:,1) cell           % cell array of tables to glue together
    vNames (:,1) string = strings(0,1) % list of variable to glue together
    tblName string = "tbl"       % table name within each profile to extract, if profile is a struct
end % arguments Input
arguments (Output)
    binned table % Glued together table
end % arguments Output

[items, bins] = glue_extract_information(key, profiles, vNames, tblName, true);

binned = glue_build_empty_table(key, bins, items, false);

for index = 1:numel(profiles)
    tbl = profiles{index};

    if isstruct(tbl)
        if ~isfield(tbl, tblName)
            error("%s is not in profile %d", tblName, index);
        end % if ~isfield
        tbl = tbl.(tblName);
    end % if isstruct

    [~, iLHS, iRHS] = innerjoin(binned, tbl, "Keys", key);
    
    for name = items.name(items.index == index)'
        binned.(name)(iLHS,:) = tbl.(name)(iRHS,:);
    end % for name
end % for index
end % glue_widthwise