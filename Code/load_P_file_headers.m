%
% Load the P file header and check some sanity of the file
%
% Oct-2023, Pat Welch, pat@mousebrains.com

function db = load_P_file_headers(filenames, pars)
arguments (Input)
    filenames table
    pars struct
end % arguments Input
arguments (Output)
    db table
end % arguments Output

dbFN = fullfile(pars.database_root, "pfilenames.db.mat");

if isfile(dbFN)
    db = load(dbFN).db; % Load what was done before
    [~, iLHS, iRHS] = outerjoin(filenames, db, "Keys", "fn");
    indices = nan(1,size(filenames,1));
    qLeftOnly = iLHS ~= 0 & iRHS == 0;
    indices(iLHS(qLeftOnly)) = iLHS(qLeftOnly); % New entries
    qJoint = iLHS ~= 0 & iRHS ~= 0;
    qRedo = ...
        filenames.date(iLHS(qJoint)) > db.date(iRHS(qJoint)) | ...
        filenames.bytes(iLHS(qJoint)) ~= db.bytes(iRHS(qJoint));
    indices(iLHS(qRedo)) = iLHS(qRedo); % Entries already known, but need redone
    indices = indices(~isnan(indices));
else % No previous information, so do everybody
    indices = 1:size(filenames,1);
    db = table();
end % if isfile

if isempty(indices)
    if ~isempty(db)
        db = db(~db.qDrop,:); % Drop files that are corrupted.
    end % if ~isempty
    return; % Nothing new to look at
end % if isempty

rows = cell(size(indices,1),1);
files = parallel.pool.Constant(filenames);

parfor j = 1:numel(indices)
    index = indices(j);
    row = files.Value(index,:);
    rows{j} = load_P_file_header(row.fn, row);
end % parfor

rows = vertcat(rows{:});

if isempty(db)
    db = rows;
else
    [~, iLHS, iRHS] = outerjoin(db, rows, "Keys", "fn");
    qJoint = iLHS ~= 0 & iRHS ~= 0;
    if any(qJoint)
        db(iLHS(qJoint),:) = rows(iRHS(qJoint),:);
    end % any

    qRHS = iLHS == 0 & iRHS ~= 0;
    if any(qRHS)
        db = vertcat([db; rows(iRHS(qRHS),:)]); % Merge in new entries
    end % if any
end % if isempty db

my_mk_directory(dbFN, pars.debug);
save(dbFN, "db", pars.matlab_file_format);

db = db(~db.qDrop,:); % Drop files that are corrupted.
end % load_P_file_headers

function row = load_P_file_header(fn, row)
arguments (Input)
    fn string {mustBeFile}
    row (1,:) table
end % arguments Input
arguments (Output)
    row (1,:) table
end % arguments Output

row.endian = "ieee-be";
row.qDrop = false;
row.fileNumber = nan; % Sequence number of the file
row.nHeader =  nan;   % Length in bytes of the header, typically 128
row.nConfig =  nan;   % Length in bytes of configuration payload
row.nData =  nan;     % Length in bytes of data payload
row.fClock =  nan;    % Clock frequency
row.version =  nan;   % Firmware version
row.nPrevious = uint16(0);  % Previous file number for rolled files
row.t0 =  NaT;        % Time of configuration record
row.t1 =  NaT;        % Time of first data record
row.tEnd =  NaT;      % Time of last data record
row.configHash =  "";  % Key hash of the config body

fid = my_open(fn, row.endian);
if fid == -1
    row.qDrop = true;
    return;
end

[hdr, n] = fread(fid, 64, "*uint16"); % Try reading as big endian

if n ~= 64
    my_close(fid, fn);
    fprintf("EOF reading header 0, %d != 128 in %s\n", n, fn);
    row.qDrop = true;
    return;
end % if numel hdr0

if hdr(end) ~= 2 % Not big-endian, so try little endian
    row.endian = "ieee-le"; % Not big-endian, so try little-endian
    my_close(fid, fn);
    fid = my_open(fn, row.endian); % Reopen with little-endian
    if fid == -1, return; end % Shouldn't happen
    hdr = fread(fid, 64, "*uint16"); % We know there are 64 words
    if hdr(end) ~= 1
        my_close(fid, fn);
        fprintf("Unknown endian type, %d, in %s\n", hdr(end), fn);
        row.qDrop = true;
        return;
    end % hdr
end % if

% We now have a "good" header

row.fileNumber = hdr(1); % file number, i.e. last four digits of filename
row.nHeader = hdr(18); % Header size in bytes
row.nConfig = hdr(12); % Configuration body in bytes
row.nData = hdr(19); % Header+data block in bytes
row.fClock = double(hdr(21)) + double(hdr(22)) / 1000; % sampling frequency in Hz
row.t0 = datetime(hdr(4:9)') + milliseconds(hdr(10)); % Time of header record
row.nPrevious = hdr(17); % Previous filenumber for rolled files

% MSB has major version, LSB has minor version
row.version = double(bitand(bitshift(hdr(11),-8), 255)) + double(bitand(hdr(11),255)) / 10;

[cfg, n] = fread(fid, row.nConfig, "*uint8"); % Read the configuration body
if numel(cfg) ~= row.nConfig
    my_close(fid, fn);
    fprintf("Configuration body was not the correct length, %d != %d, in %s\n", ...
        n, row.nConfig, fn);
    row.qDrop = true;
    return;
end

% Use SHA512 to minimize collison probabilities, for a 20kB ASCII cfg string,
% the collision probability will be <2^(256-16) or ~1 in 10^72
% sha512 = java.security.MessageDigest.getInstance("SHA-512");
% row.configHash = strjoin(string(dec2hex(typecast(sha512.digest(uint8(cfg)), "uint8"))), "");
row.configHash = keyHash(cfg);

[hdr, n] = fread(fid, 64, "*uint16"); % Read the first data header
if n ~= 64
    my_close(fid, fn);
    fprintf("EOF reading header 1, %d != 128, in %s\n", n, fn);
    row.qDrop = true;
    return;
end

row.t1 = datetime(hdr(4:9)') + milliseconds(hdr(10));
dt = seconds(row.t1 - row.t0);
if dt <= 0
    my_close(fid, fn);
    fprintf("Invalid times in configuration header, %s, and first data record %s, %s, in %s\n", ...
        string(row.t0, "yyyy-MM-dd HH:mm:ss.SSS"), ...
        string(row.t1, "yyyy-MM-dd HH:mm:ss.SSS"), ...
        string(dt, "mm:ss.SSS"), ...
        fn);
    row.qDrop = true;
    return;
end

my_close(fid, fn);

% Number of data records in the file, should be a whole number
nRecords = double(row.bytes - uint64(row.nHeader) - uint64(row.nConfig)) / double(row.nData);
nData = row.nData - row.nHeader; % data words in each data record
% Time of last record
% time of config record + number of records * number of bytes per record over clock frequency
% over 2 bytes per word
row.tEnd = row.t0 + seconds(floor(nRecords) * double(nData) / row.fClock / 2);
end % load_P_file_header

function fid = my_open(fn, endian)
arguments (Input)
    fn string
    endian string
end % arguments (Input)
arguments (Output)
    fid double % File identifier
end % arguments Output

[fid, errmsg] = fopen(fn, "rb", endian);

if fid == -1
    fprintf("Error opening %s, %s\n", fn, errmsg);
end % if
end % my_open

function my_close(fid, fn)
arguments (Input)
    fid double % open file identifier
    fn string % open filename
end % arguments Input

if fclose(fid) ~= 0
    fprintf("Error closing %s, %s\n", fn, ferror(fid));
end % if fclose
end % my_close