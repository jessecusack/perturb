% Search a directory tree and find all the candidate .[Pp] files.
%
% The expectation is the .[Pp] files are under info.p_file_root
% info.p_file_pattern is appended to p_file_root to get the list of P files
%
% June-2023, Pat Welch, pat@mousebrains.com

function tbl = mk_filenames(info)
arguments (Input)
    info struct
end % arguments Input
arguments (Output)
    tbl table % Table of acceptable .p filenames
end % arguments Output

items = struct2table(dir(fullfile(info.p_file_root, info.p_file_pattern))); % All files
items.name = string(items.name);
items = items(~items.isdir & endsWith(items.name, ".p", "IgnoreCase", true),:); % ends with .[Pp]
items = items(~endsWith(items.name, "_original.p", "IgnoreCase", true),:);
items.folder = string(items.folder);

[dirname, basename] = fileparts(extractAfter(fullfile(items.folder, items.name), info.p_file_root));
qDrop = startsWith(dirname, ["/", "\"]);
dirname(qDrop) = extractAfter(dirname(qDrop), 1);
items.basename = fullfile(dirname, basename);

tbl = table();
tbl.basename = items.basename;
tbl.qUse = true(size(tbl.basename));
tbl.fnP = fullfile(items.folder, items.name);
fn = append(tbl.basename, ".mat");
tbl.fnM    = fullfile(info.mat_root,     fn);
tbl.fnProf = fullfile(info.profile_root, fn);
tbl.fnBin  = fullfile(info.binned_root,  fn);

if exist(info.p2mat_filename, "file") % Join to existing information
    rhs = load(info.p2mat_filename).filenames;
    names = string(tbl.Properties.VariableNames);
    tbl
    rhs
    tbl = my_joiner(tbl, rhs, ...
        "basename", ...
        names(names.startsWith("fn")));
end % if exist
end % mk_filenames
