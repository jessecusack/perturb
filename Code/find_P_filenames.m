function tbl = find_P_filenames(p_file_root, p_file_pattern)
arguments (Input)
    p_file_root string {mustBeFolder} % Root pattern to apply pattern to
    p_file_pattern string="*" % glob pattern to match against, doesn't have .p due to case issues
end % arguments Input
arguments (Output)
    tbl table
end % arguments Output

tbl = struct2table(dir(fullfile(p_file_root, p_file_pattern)));
tbl = tbl( ...
    ~tbl.isdir ...
    & endsWith(tbl.name, ".p", "IgnoreCase", true) ...
    & ~endsWith(tbl.name, "_original.p", "IgnoreCase", true) ...
    , :);

tbl.fn = string(fullfile(tbl.folder, tbl.name));
tbl.date = datetime(tbl.datenum, "ConvertFrom", "datenum");
tbl = removevars(tbl, ["folder", "isdir", "datenum"]);

base = dir(p_file_root);
baseFolder = string(base(1).folder);
tbl.name = extractAfter(tbl.fn, baseFolder); % Portion after p_file_root
tbl.name = extractBefore(tbl.name, strlength(tbl.name) - 1); % Drop .p
tbl.name = extractAfter(tbl.name, 1); % Drop leading /
end % find_p_filenames