%
% Convert P files to binned data
%
% This is ground up rewrite of Fucent's code with a lot of enhancements
%
% The code uses Matlab's parallel pool, if available. If not it will run serially.
%
% July-2023, Pat Welch, pat@mousebrains.com
% Oct-2023, Pat Welch, pat@mousebrains.com # refactor for using a parallel pool

function pars = process_P_files(varargin)
stime = tic();

% Turn off name conflict warning for the input method I need to make ODAS work
warningState = warning; % Current status
warning("off", "MATLAB:dispatcher:nameConflict");

% Process input arguments and build a structure with parameters
pars = get_info(varargin{:}); % Parse arguments and supply defaults
pars = update_paths(pars); % Populate all the paths

my_mk_directory(pars.log_filename, pars.debug); % Make sure the directory to write logfile to exists

diary(pars.log_filename);
diary on; % Record all output into info.log_filename
fprintf("\n\n********* Started at %s **********\n", datetime());
fprintf("%s\n\n", jsonencode(rmfield(pars, "gps_class"), "PrettyPrint", true));

try
    p_filenames = find_P_filenames(pars.p_file_root, pars.p_file_pattern); % Get a list of all the current P files

    if isempty(p_filenames)
        fprintf("No P files found for %s\n", fullfile(pars.p_file_root, pars.p_file_pattern));
        return;
    end

    % Sort out if the Parallel Computing Toolbox is installed or not
    toolboxes = matlab.addons.installedAddons;
    if ~ismember("Parallel Computing Toolbox", toolboxes.Name)
        fprintf("\nThis software is capabe of using Matlab's parallel computing toolbox!\n\n");
    elseif isempty(gcp("nocreate"))
        parpool("Processes"); % Since save is not thread safe, we have to use Processes
    end % isempty gcp

    p_filenames = load_P_file_headers(p_filenames, pars); % Get the header record for each P file
    p_filenames = trim_P_files(p_filenames, pars); % Trim fractional records in P files

    if pars.p_file_merge % merge P files that were rolled over due to size
        my_mk_directory(fullfile(pars.p_merge_root, "dummy"), pars.debug);
        p_filenames = merge_p_files(p_filenames, pars.p_merge_root);
    end % if p_file_merge

    p_filenames.qMatOkay     = true(size(p_filenames,1),1);
    p_filenames.qProfileOkay = true(size(p_filenames,1),1);

    qUseDB = fullfile(pars.database_root, "qUse.db.mat");
    if isfile(qUseDB)
        qUse = load(qUseDB).qUse;
        [~, iLHS, iRHS] = innerjoin(p_filenames, qUse, "Keys", "name");
        if ~isempty(iLHS)
            p_filenames.qMatOkay(iLHS) = qUse.qMatOkay(iRHS);
            p_filenames.qProfileOkay(iLHS) = qUse.qProfileOkay(iRHS);
        end
    else
        qUse = p_filenames(:,["name", "qMatOkay", "qProfileOkay"]);
    end % if isfile

    qMatOkay     = true(size(p_filenames,1),1);
    qProfileOkay = true(size(p_filenames,1),1);

    params = parallel.pool.Constant(pars); % Doesn't change from here on

    binnedProfile = cell(size(p_filenames,1),1);
    binnedDiss = cell(size(binnedProfile));
    binnedCTD = cell(size(binnedProfile));

    parfor index = 1:size(p_filenames,1)
        st = tic();
        row = p_filenames(index,:);
        logFN = fullfile(params.Value.log_root, append(row.name, ".log"));
        my_mk_directory(logFN);
        diary(logFN);
        diary on;
        fprintf("\n\n********* Started %s at %s *********\n", row.name, datetime());
        try
            if row.qMatOkay
                [row, binnedProfile{index}, binnedDiss{index}, binnedCTD{index}] = P_to_binned_profile(row, params.Value);
                qMatOkay(index) = row.qMatOkay;
                qProfileOkay(index) = row.qProfileOkay;
            else
                fprintf("%s: qMatOkay false\n", row.name);
            end % if row.qMatOkay
            fprintf("********* Finished %s in %.1f seconds *********\n", row.name, toc(st));
        catch ME
            fprintf("%s: EXCEPTION\n%s\n\n", row.name, getReport(ME));
            fprintf("********* Finished %s with exception at %s in %.1f seconds *********\n", ...
                row.name, datetime(), toc(st));
            qMatOkay(index) = false;
        end
        diary off;
    end % parfor

    p_filenames.qMatOkay = p_filenames.qMatOkay & qMatOkay;
    p_filenames.qProfileOkay = p_filenames.qProfileOkay & qProfileOkay;

    [~, iLHS, iRHS] = outerjoin(p_filenames, qUse, "Keys", "name");
    qOld = iLHS ~= 0 & iRHS ~= 0;
    qNew = iLHS ~= 0 & iRHS == 0;
    qUse.qMatOkay(iRHS(qOld)) = p_filenames.qMatOkay(iLHS(qOld));
    qUse.qProfileOkay(iRHS(qOld)) = p_filenames.qProfileOkay(iLHS(qOld));
    qUse = vertcat([qUse; p_filenames(iLHS(qNew), ["name", "qMatOkay", "qProfileOkay"])]);
    my_mk_directory(qUseDB, pars.debug);
    save(qUseDB, "qUse", pars.matlab_file_format);

    binnedProfile = binnedProfile(~cellfun(@isempty, binnedProfile)); % Prune empty bins
    binnedDiss = binnedDiss(~cellfun(@isempty, binnedDiss)); % Prune empty bins
    binnedCTD = binnedCTD(~cellfun(@isempty, binnedCTD)); % Prune empty bins

    qProf = ~cellfun(@(x) isempty(x{1}) || ismissing(x{1}), binnedProfile); % Valid data for profile depth binning
    qDiss = ~cellfun(@(x) isempty(x{1}) || ismissing(x{1}), binnedDiss);    % Valid data for diss depth binning
    qCTD  = ~cellfun(@(x) isempty(x{1}) || ismissing(x{1}), binnedCTD);     % Valid data for CTD time binning

    if any(qProf)
        profiles2combo(binnedProfile(qProf), pars);
    end % if any qProf
    if any(qDiss)
        diss2combo(binnedDiss(qDiss), pars);
    end % if any qDiss
    if ~ismissing(pars.CT_T_name) && ~ismissing(pars.CT_C_name) && any(qCTD)
        ctd2combo(binnedCTD(qCTD), pars);
    end % if any qCTD

    fprintf("\n********* Finished at %s in %.0f seconds **********\n", datetime(), toc(stime));
    diary off;
catch ME
    fprintf("\n\nEXCEPTION\n%s\n\n", getReport(ME));
    fprintf("\n\n********* Finished with exception at %s in %.0f seconds **********\n", ...
        datetime(), toc(stime));
    diary off
end % try

warning(warningState); % Restore the warning status
end % process_P_files

function [row, binnedProfile, binnedDiss, ctdBinned] = P_to_binned_profile(row, pars)
arguments (Input)
    row (1,:) table
    pars struct
end % arguments Input
arguments (Output)
    row (1,:) table
    binnedProfile (2,1) cell % {filename, data}
    binnedDiss (2,1) cell
    ctdBinned    (2,1) cell
end % arguments Input

binnedProfile = {missing, []}; % Filename of binned profile information, binned profile data
binnedDiss = {missing, []};
ctdBinned = {missing, []};
gps = [];

[row, mat] = convert2mat(row, pars); % Convert P file to mat via odas_p2mat
if ~row.qMatOkay, return; end % Failed going through odas_p2mat

if ~ismissing(pars.CT_T_name) && ~ismissing(pars.CT_C_name)
    % Use the profiles information to get "tow-yo" estimates for GPS locations.
    [row, ctdBinned, mat, gps] = ctd2binned(row, mat, pars); % time bin up scalers with no profiles
end % if

if ~row.qProfileOkay, return; end % Failed in the past, so don't work on the profiles

[row, profiles] = mat2profile(row, mat, pars, gps); % Split into profiles

if ~row.qProfileOkay, return; end % Nothing more to do

[row, binnedProfile] = profile2binned(row, profiles, pars); % Bin profiles by depth

% Calculate the dissipations for each profile
[row, diss] = profile2diss(row, profiles, pars); % Calculate dissipations
[row, binnedDiss] = diss2binned(row, diss, pars); % Bin the dissipation
end %s process_P_to_binned_profile
