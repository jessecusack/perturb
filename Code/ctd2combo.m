% Combine the output of ctd2binned into a single table, sorted by time
%
% This is a refactorization to deal with parallelization.
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function ctd2combo(ctd, p_filenames, pars)
arguments (Input)
    ctd (:,1) cell
    p_filenames table
    pars struct
end % arguments Input

if ~pars.CT_has, return; end

fnCombo = fullfile(pars.ctd_root, "ctd.combo.mat");
if isfile(fnCombo)
    items = struct2table(dir(fullfile(pars.ctd_root, pars.p_file_pattern)));
    items = items(~items.isdir,:);
    mtime = max(items.datenum);
    items = dir(fnCombo);
    if items.datenum > mtime
        fprintf("No need to rebuild CTD combo, %s is newer than inputs\n", fnCombo);
        return;
    end
end % if isfile

names = strings(0);
nTimes = 0;
for index = 1:numel(ctd)
    tbl = ctd{index};
    nTimes = nTimes + size(tbl,1);
    names = union(names, string(tbl.Properties.VariableNames));
end % for index

[~, ix] = sort(lower(names));
names = names(ix);
names = ["t"; setdiff(names, "t")];

tbl = table();
tbl.t = NaT(nTimes,1);

for name = names(2:end)'
    name
    tbl.(name) = nan(nTimes,1);
end % for name

offset = 0;
for index = 1:numel(ctd)
    a = ctd{index};
    ii = offset + (1:size(a,1));
    offset = offset + size(a,1);
    for name = string(a.Properties.VariableNames)
        tbl.(name)(ii) = a.(name);
    end % for name
end % for index

[~, ix] = unique(tbl.t);
tbl = tbl(ix,:);

data = struct();
data.ctd = tbl;
data.info = p_filenames;

my_mk_directory(fnCombo, pars.debug);
fprintf("Writing %s\n", fnCombo);
save(fnCombo, "-struct", "data", pars.matlab_file_format);
end % ctd2combo