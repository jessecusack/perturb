% Add in seawater properties to slow

function slow = add_seawater_properties(profile, pars, latDefault, lonDefault)
arguments (Input)
    profile struct % Structure being built by mat2profiles
    pars struct % Structure from get_info
    latDefault double = 0
    lonDefault double = 0
end % arguments Input
arguments (Output)
    slow table % Slow variables with additional seawater columns
end % arguments Output

lat = profile.lat;
lon = profile.lon;

lat(isnan(lat)) = latDefault;
lon(isnan(lon)) = lonDefault;

slow = profile.slow;

TName = pars.CT_T_name;
CName = pars.CT_C_name;

if all(ismember([TName, CName], slow.Properties.VariableNames))
    slow.SP = gsw_SP_from_C(slow.(CName), slow.(TName), slow.P_slow); % Practical salinity
    slow.SA = gsw_SA_from_SP(slow.SP, slow.P_slow, lon, lat); % Absolute salinity
    slow.theta = gsw_CT_from_t(slow.SA, slow.(TName), slow.P_slow); % Conservation T
    slow.sigma = gsw_sigma0(slow.SA, slow.theta);
    slow.rho = gsw_rho(slow.SA, slow.theta, slow.P_slow) - 1000; % density kg/m^3 - 1000
end % if ismember
slow.depth = gsw_depth_from_z(gsw_z_from_p(slow.P_slow, lat));
end % addSeawaterProperties