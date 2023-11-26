% Combine the output of ctd2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function a = ctd2combo(ctd, pars)
arguments (Input)
    ctd (:,1) cell
    pars struct
end % arguments Input
arguments (Output)
    a struct % Binned CTD data
end % arguments Output

if ismissing(pars.CT_T_name) || ismissing(pars.CT_C_name) || isempty(ctd), return; end

[a, fnCombo] = CTDsave2combo(ctd, pars);

fnCDL = fullfile(fileparts(mfilename("fullpath")), "CTD.json");
save2NetCDF(a, fnCombo, pars, fnCDL)
end % ctd2combo

function [a, fnCombo] = CTDsave2combo(ctd, pars)
arguments (Input)
    ctd (:,1) cell % Cell array of time binned CTD information, possibly empty
    pars struct    % Modified version of get_info's output
end % arguments Input
arguments (Output)
    a  struct % info and tbl as a struct
    fnCombo string % Filename of combined CTD information
end % arguments Output

a = struct();
fnCombo = fullfile(pars.ctd_combo_root, "combo.mat");

data = table();
data.fn = cellfun(@(x) x{1}, ctd);
data.data = cellfun(@(x) x{2}, ctd, "UniformOutput", false);

data = data(~ismissing(data.fn),:);

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
        fprintf("No need to rebuild CTD combo, %s is newer than inputs\n", fnCombo);
        return;
    end
    fprintf("Rebuilding %s due to %d files\n", fnCombo, sum(data.datenum >= item.datenum));
end % if isfile

if any(cellfun(@isempty, data.data))
    items = cell(size(data.data));
    dd = parallel.pool.Constant(data); % Doesn't change from here on
    parfor index = 1:size(data,1)      % Load in parallel
        if ~isempty(dd.Value.data{index})
            items{index} = dd.Value.data{index};
        else
            fprintf("Loading %s\n", dd.Value.fn(index));
            items{index} = load(dd.Value.fn(index));
        end % if ~isempty
    end % parfor
    delete(dd);
    data.data = items;
end % if any

tbl = glue_lengthwise("bin", data.data, strings(0), "tbl");

cInfo = cellfun(@(x) x.info, data.data, "UniformOutput", false);
cInfo = vertcat(cInfo{:});

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
a = struct("info", cInfo, "tbl", tbl);
save(fnCombo, "-struct", "a", pars.matlab_file_format);
end % ctd2combo