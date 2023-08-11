%
% Look at first and second headers in a P file looking for a time gap
%
% The detection method was suggested by William and Rockland
%
% August-2023, Pat Welch, pat@mousebrains.com

function p_file_merger(vmpDir)
arguments (Input)
    vmpDir string {mustBeFolder} % Directory to look inside for SN*/*.[Pp] files
end % arguments Input

[toJoin, badFiles] = find_files_to_join(struct2table(dir(fullfile(vmpDir, "SN*/*"))));

if ~isempty(badFiles), fprintf("Moving/removing bad P files, %d\n", numel(badFiles)); end

for fn = badFiles'
    fnOrig = mkOriginalFilename(fn);
    myMoveFile(fn, fnOrig, true);
end

if ~isempty(toJoin), fprintf("Joining P files, %d\n", size(toJoin, 1)); end

for index = 1:size(toJoin,1)
    fnLHS = toJoin.fnLHS(index);
    if ismissing(fnLHS), continue; end % Already dealt with

    nameRHS = strings(size(toJoin,1),1); % RHS files to append to LHS
    nameRHS(index) = toJoin.fnRHS(index);

    for iter = (index+1):size(toJoin,1)
        q = ismember(toJoin.fnLHS, nameRHS(iter-1));
        if ~any(q), break; end
        nameRHS(iter) = toJoin.fnRHS(iter);
        toJoin.fnLHS(iter) = missing;
    end % for iter

    nameRHS = nameRHS(strlength(nameRHS)>0);
    tmpName = tempname(fileparts(fnLHS)); % tempname for output

    ofp = myOpen(tmpName, "wb");
    if ofp == -1, continue; end

    ifp = myOpen(fnLHS, "rb");
    if ifp == -1
        myClose(ofp, tmpName, true);
        continue;
    end

    n = fwrite(ofp, fread(ifp)); % Copy first file to temp file
    fprintf("Copy %s %d\n", fnLHS, n);
    if ~myClose(ifp, fnLHS) % Close the LHS
        myClose(ofp, tmpName, true);
        continue;
    end % if ~myClose

    qOkay = true;
    for fnRHS = nameRHS'
        ifp = skipRecord0(fnRHS);
        if ifp == -1
            myClose(ofp, tmpName, true);
            continue;
        end % if ifp == -1

        n = fwrite(ofp, fread(ifp)); % Copy data from RHS to temp file
        fprintf("append %s %d\n", fnRHS, n);
        if ~myClose(ifp, fnRHS)
            myClose(ofp, tmpName, true);
            qOkay = false;
            break;
        end % if ~myClose
    end % for name

    if ~qOkay, continue; end

    if ~myClose(ofp, tmpName)
        delete(tmpName);
        continue;
    end % if myClose

    names = union(fnLHS, nameRHS');
    qOkay = true;
    for index_name = 1:numel(names)
        fn = names(index_name);
        fnOrig = mkOriginalFilename(fn);
        if ~exist(fnOrig ,"file") && ~myMoveFile(fn, fnOrig)
            for j = 1:(index_name-1) % Unwind what I've done
                fn1 = names(j);
                fn1Orig = mkOriginalFilename(fn1);
                if ~exist(fn1, "file") && exist(fn1Orig, "file")
                    myMoveFile(fn1Orig, fn1);
                end % if
            end % for j
            qOkay = false;
            delete(tmpName);
            break;
        end % if
    end % for index
    
    if ~qOkay, continue; end

    if ~myMoveFile(tmpName, fnLHS)
        delete(tmpName);
        fprintf("Deleted %s\n", tmpName);
        for fn = names
            fnOrig = mkOriginalFilename(fn);
            if ~exist(fn, "file") && exist(fnOrig, "file")
                myMoveFile(fnOrig, fn);
            end % if
        end % for fn
    end % if ~myMoveFile
end % for index
end % p_file_merger

function [toJoin, badFiles] = find_files_to_join(items, dtMax)
arguments (Input)
    items table % Output of struct2table(dir(*))
    dtMax double = 0.1 % Maximum duration between config and first data record time stamps to be rollover
end % arguments Input
arguments (Output)
    toJoin table % List of tables to be joined
    badFiles (:,1) string % List of files that are "bad"
end % arguments Input

items = items(endsWith(items.name, ".p", "IgnoreCase", true) & ~items.isdir,:); % Retain just the .P files
items = items(~endsWith(items.name, "_original.p", "IgnoreCase", true),:); % Drop _original.p files
items.name = string(items.name);
items.folder = string(items.folder);
items.fn = fullfile(items.folder, items.name);
items.t0 = NaT(size(items.name));
items.t1 = NaT(size(items.name));

for index = 1:size(items,1)
    fn = items.fn(index);
    [fid, errmsg] = fopen(fn, "rb");
    if fid == -1
        fprintf("Error opening %s\n", fn, errmsg);
        continue;
    end % if fid
    hdr = fread(fid, 64, "uint16", "ieee-be");
    if numel(hdr) ~= 64
        fprintf("Error reading header 0 from %s\n", fn);
        fclose(fid);
        continue;
    end % if numel
    items.t0(index) = datetime(hdr(4:9)') + milliseconds(hdr(10));
    status = fseek(fid, hdr(12), "cof");
    if status ~= 0
        fprintf("Error seeking in %s\n", fn, ferror(fid));
        fclose(fid);
        continue;
    end
    hdr = fread(fid, 64, "uint16", "ieee-be");
    if numel(hdr) ~= 64
        fprintf("Error reading header 1 from %s\n", fn);
        fclose(fid);
        continue;
    end % if numel
    items.t1(index) = datetime(hdr(4:9)') + milliseconds(hdr(10));
    fclose(fid);
end % for index

badFiles = items.fn(isnat(items.t1));

items.dt = abs(seconds(items.t1 - items.t0));
items = items(items.dt < dtMax,:); % Candidates
[folder, fn, suffix] = fileparts(items.fn);
n = strlength(fn) - 4;
items.fnLHS = fullfile(folder, ...
    append( ...
    extractBefore(fn, n+1), ...
    string(num2str(uint32(str2double(extractAfter(fn, n)) - 1), "%04d")), ...
    suffix));

items = renamevars(items, "fn", "fnRHS");
items = sortrows(items, "t0");
toJoin = removevars(items, ["name", "folder", "date", "bytes", "isdir", "datenum", "t0", "t1"]);
end % find_files_to_join

function orig = mkOriginalFilename(fn)
arguments (Input)
    fn string
end % arguments Input
arguments (Output)
    orig string
end % Output
[folder, name, ext] = fileparts(fn);
orig = fullfile(folder, append(name, "_original", ext));
end % mkOriginalFilename

function q = myMoveFile(src, dest, onNotExist, onError)
arguments (Input)
    src string % Source filename
    dest string % Target filename
    onNotExist logical = false % Delete src if dest exists
    onError logical = false % Delete src if error while moving src -> dest
end % arguments Input
arguments (Output)
    q logical % src existed and was moved to dest
end % arguments Output

q = false;

if ~exist(src, "file")
    fprintf("Doesn't exist\n");
    if onNotExist
        delete(src);
        fprintf("Deleted %s\n", src);
    end % if onNotExist
    return;
end % if

[status, errmsg] = movefile(src, dest);
q = status == 1;
if q
    fprintf("Moved %s to %s\n", src, dest);
    return;
end

fprintf("Error moving %s to %s, %s\n", src, dest, errmsg);

if onError
    delete(src);
    fprintf("Deleted %s\n", src);
end % if onError
end % myMoveFile

function fid = myOpen(fn, mode)
arguments (Input)
    fn string % File to be opened
    mode string = "rb";
end % arguments Input

[fid, errmsg] = fopen(fn, mode, "ieee-be");
if fid == -1
    fprintf("Error opening %s, %s\n", fn, errmsg);
end % if fid
end % myOpen

function q = myClose(fid, fn, qDelete)
arguments(Input)
    fid double
    fn string
    qDelete logical = false % Should fn be deleted after close
end % arguments Input

status = fclose(fid);
q = status == 0;
if ~q
    fprintf("Error closing %s, %s\n", fn, ferror(fid));
end % if ~q

if qDelete && exist(fn, "file"), delete(fn); end
end % myClose

function fid = skipRecord0(fn)
arguments (Input)
    fn string % Input filename to strip off configuration record from
end % arguments Input
arguments (Output)
    fid double
end % arguments Output

fid = myOpen(fn);
if fid == -1
    return;
end

hdr = fread(fid, 64, "uint16"); % Read in configuration header

if numel(hdr) ~= 64
    fprintf("EOF while reading header in %s\n", fnRHS);
    myClose(fid, fn);
    fid = -1;
    return;
end % if numel

fseek(fid, hdr(12), "cof"); % Move past the configuration record
end % skipRecord0