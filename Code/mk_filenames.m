% Search a directory tree and find all the candidate .[Pp] files.
%
% The expectation is the .[Pp] files are under info.vmp_root in directories
% like "SN*/*.[pP]"
%
% June-2023, Pat Welch, pat@mousebrains.com

function tbl = mk_filenames(info)
arguments (Input)
    info struct
end % arguments Input
arguments (Output)
    tbl table % Table of acceptable .p filenames
end % arguments Output

items = struct2table(dir(fullfile(info.vmp_root, "SN*/*"))); % All files
items.name = string(items.name);
items = items(endsWith(items.name, ".p", "IgnoreCase", true),:); % For case sensitive file systems
items = items(~endsWith(items.name, "_original.p", "IgnoreCase", true),:);
items.folder = string(items.folder);

tbl = table();
[~, tbl.sn] = fileparts(items.folder);
[~, tbl.basename] = fileparts(items.name);
tbl.label = append(tbl.sn, "/", tbl.basename);
tbl.qUse = true(size(tbl.sn));
tbl.fnP = fullfile(items.folder, items.name);
fn = fullfile(tbl.sn, append(tbl.basename, ".mat"));
tbl.fnM    = fullfile(info.mat_root,     fn);
tbl.fnProf = fullfile(info.profile_root, fn);
tbl.fnBin  = fullfile(info.binned_root,  fn);

if exist(info.p2mat_filename, "file") % Join to existing information
    rhs = load(info.p2mat_filename).filenames;
    names = string(tbl.Properties.VariableNames);
    tbl = my_joiner(tbl, rhs, ...
        ["basename", "sn"], ...
        names(names.startsWith("fn")));
end % if exist
end % mk_filenames
