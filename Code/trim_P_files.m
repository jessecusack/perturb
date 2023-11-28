%
% Trim P files which have fractional records
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function p_filenames = trim_P_files(p_filenames, pars)
arguments (Input)
    p_filenames table
    pars struct
end % arguments Input
arguments (Output)
    p_filenames table
end % arguments Output

if ~pars.p_file_trim, return; end % Don't trim the P files

nRecords = (p_filenames.bytes - double(p_filenames.nHeader) - double(p_filenames.nConfig)) ...
    ./ double(p_filenames.nData);

qTrim = rem(nRecords,1) ~= 0; % A fractional record
if ~any(qTrim), return; end % Nothing to trim

toTrim = p_filenames(qTrim,:);
toTrim.nRecords = nRecords(qTrim);
toTrim.ofn = fullfile(pars.p_trim_root, append(toTrim.name, ".p"));

fn = strings(size(toTrim,1),1); % Output from trim_p_file
a = parallel.pool.Constant(toTrim); % Make constant for parfor

parfor index = 1:numel(fn)
    fn(index) = trim_p_file(a.Value(index,:));
end % parfor

toRename = toTrim(~ismissing(fn),:);

[~, iLHS, iRHS] = innerjoin(p_filenames, toRename, "Keys", "name");
p_filenames.fn(iLHS) = fn(iRHS);
end % trim_P_files

function ofn = trim_p_file(row)
arguments (Input)
    row table;
end % arguments Input
arguments (Output)
    ofn string
end % arguments Output

ifn = row.fn;
ofn = row.ofn;

if isnewer(ofn, ifn)
    fprintf("%s: %s is newer than %s\n", row.name, ofn, ifn);
    return;
end

my_mk_directory(ofn); % Make sure the directory exists

[ifp, errmsg] = fopen(ifn);
if ifp == -1
    ofn = missing;
    fprintf("Unable to open %s, %s", ifn, errmsg);
    return;
end % if ifd

buffer = fread(ifp, row.nHeader + row.nConfig);
if numel(buffer) ~= (row.nHeader + row.nConfig)
    ofn = missing;
    fprintf("Error reading header from %s\n", ifn);
    return;
end

[ofp, errmsg] = fopen(ofn, "wb");
if ofp == -1
    ofn = missing;
    fprintf("Error opening %s, %s\n", ofn, errmsg);
    return;
end

fwrite(ofp, buffer); % Write out header+config record, which we know is good already

while ~feof(ifp)
    buffer = fread(ifp, row.nData); % Read a header+data record
    if numel(buffer) ~= row.nData, break; end % A fractional record
    % We should put some sanity checks of the data header in here
    fwrite(ofp, buffer); % Write out header+data record to trimmed file
end

status = fclose(ofp);
if status ~= 0
    ofn = missing;
    fprintf("Error closing %s, %s\n", ofn, ferror(ofp));
    return;
end

status = fclose(ifp);
if status ~= 0
    fprintf("Problem closing %s, %s\n", ifn, ferror(ifp));
end
fprintf("Trimmed %s\n", ifn);
end % trim_p_file