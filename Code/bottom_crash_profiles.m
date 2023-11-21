% Trim the bottom part of profiles before the VMP crashes into the bottom

function pInfo = bottom_crash_profiles(profiles, pInfo, info)
arguments (Input)
    profiles cell % Cell array with each profile
    pInfo table % Summary information for all the profiles
    info struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    pInfo table % Updated summary information for all the profiles
end % arguments Output
%%

if ~info.bbl_calculate, return; end % Don't do any BBL stuff

warning("Bottom Crash Detection not implemented!");
disp(profiles); % To avoid syntax warning
pInfo.bottomDepth = pInfo.max_depth + 1; % Past the deepest part of each profile
end % trimProfiles
