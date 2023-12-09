%
% Save a binned data set to a combined file
%
% Used by diss2combo and profiles2combo
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function [a, fnCombo] = save2combo(binned, pars, combo_root)
arguments (Input)
    binned (:,1) cell
    pars struct
    combo_root string
end % arguments Input
arguments (Output)
    a % Can be either empty or struct
    fnCombo string
end % arguments Output

a = []; % Empty for early returns
fnCombo = fullfile(combo_root, "combo.mat");

data = table();
data.fn = cellfun(@(x) x{1}, binned);
data.data = cellfun(@(x) x{2}, binned, "UniformOutput", false);

data = data(~ismissing(data.fn),:); % Drop missing filenames

if isfile(fnCombo)
    data.datenum = nan(size(data.fn));
    for index = 1:size(data,1)
        fn = data.fn(index);
        if isfile(fn)
            item = dir(fn);
            data.datenum(index) = item(1).datenum;
        else
            fprintf("WARNING: %s does not exist!\n", fn);
            data.fn(index) = missing;
        end % if
    end % for index
    mtime = max(data.datenum, [], "omitnan");
    item = dir(fnCombo);
    if item.datenum > mtime
        fprintf("No need to rebuild Profile combo, %s is newer than inputs\n", fnCombo);
        return;
    end
    fprintf("Rebuilding %s due to %d files, %s %s\n", fnCombo, sum(data.datenum >= item.datenum), ...
        datetime(mtime, "ConvertFrom", "datenum"), ...
        datetime(item.datenum, "ConvertFrom", "datenum"));
    disp(data.fn(data.datenum >= item.datenum))
end % if isfile

if any(cellfun(@isempty, data.data))
    items = data.data;
    dd = parallel.pool.Constant(data.fn); % Doesn't change from here on
    parfor index = 1:size(data,1)
        if ~isempty(items{index}), continue; end
        fprintf("Loading %s\n", dd.Value(index));
        items{index} = load(dd.Value(index));
    end % parfor
    data.data = items;
    delete(dd); % Cleanup after myself
end % if any

t0 = cellfun(@(x) x.info.t0(1), data.data, "UniformOutput", true); % First time of each block
[~, ix] = sort(t0);
data.data = data.data(ix); % Sort temporaly into ascending order

if pars.profile_direction == "time"
    tbl = glue_lengthwise("bin", data.data);
else
    tbl = glue_widthwise("bin", data.data);
end % if direction

pInfo = cellfun(@(x) x.info, data.data, "UniformOutput", false);
pInfo = vertcat(pInfo{:});

a = struct();
a.tbl = tbl;
a.info = pInfo;

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
save(fnCombo, "-struct", "a", pars.matlab_file_format);
end % save2combo
