
% Despike a profile
% Calculate the dissipation from the shear probes top to bottom
% Calculate the dissipation from the shear probes bottom to top
% Estimate the standard deviation for each dissipation observation
% Combine dissipation estimates from different shear probes 
%   that are within the 95% confidence interval
%
% This is a ground up rewrite of my code derived from Fucent's code
%
% June-2023, Pat Welch, pat@mousebrains.com

function profile = calc_diss_shear(profile, pInfo, pars)
arguments (Input)
    profile struct % Profile information
    pInfo table % Summary information about the profile
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    profile struct % Modified version of profile with diss and bbl added
end % arguments Output

label = sprintf("%s cast %d", pInfo.name, pInfo.index);

[dissInfo, SH_HP, AA] = mk_diss_info(profile, pars, pInfo, ...
    "diss_forwards_fft_length_sec", "diss_forwards_length_fac", label);

if pars.trim_use % Trim the top of the profile
    q = dissInfo.P >= (pInfo.trim_depth + pars.trim_extra_depth);
    SH_HP = SH_HP(q,:);
    AA  = AA(q,:);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
    try
        diss = get_diss_odas(SH_HP, AA, dissInfo);
        diss = mk_epsilon_mean(diss, pars.diss_epsilon_minimum, dissInfo.diss_length, ...
            profile.fs_fast, pars.diss_warning_fraction, label);
        diss.depth = interp1(profile.slow.t_slow, profile.slow.depth, diss.t, "linear", "extrap");
        diss.t = pInfo.t0 + seconds(diss.t - diss.t(1));
        profile.diss = mk_diss_struct(diss, dissInfo);
    catch ME
        fprintf("Error %s calculating Top->Bottom dissipation, %s\n", label, ME.message);
        for i = 1:numel(ME.stack)
            stk = ME.stack(i);
            fprintf("Stack(%d) line=%d name=%s file=%s\n", i, stk.line, string(stk.name), string(stk.file));
        end % for i
        profile.diss = mk_empty_diss_struct(dissInfo);
    end % try

else % Too little data, so fudge up profile.diss
    profile.diss = mk_empty_diss_struct(dissInfo);
end % if ~isempty

%% Calculate dissipation bottom to top

if pars.bbl_calculate
    [dissInfo, SH_HP, AA] = mk_diss_info(profile, pars, pInfo, ...
        "diss_backwards_fft_length_sec", "diss_backwards_length_fac", label);

    if pars.bbl_use % Trim the bottom of the profile
        q = dissInfo.P <= (pInfo.bottomDepth + pars.bbl_extraDepth);
        SH_HP = SH_HP(q,:);
        AA  = AA(q,:);
        for name = ["speed", "T", "t", "P"]
            dissInfo.(name) = dissInfo.(name)(q);
        end % for name
    end % if trim_use

    if size(SH_HP,1) >= dissInfo.diss_length % enough data to work with
        % flip upside down so the dissipation is calculated from the bottom upwards

        SH_HP = flipud(SH_HP);
        AA = flipud(AA);
        for name = ["speed", "T", "t", "P"]
            dissInfo.(name) = flipud(dissInfo.(name));
        end % for name

        try
            diss = get_diss_odas(SH_HP, AA, dissInfo);
            diss = mk_epsilon_mean(diss, pars.diss_epsilon_minimum, dissInfo.diss_length, ...
                profile.fs_fast, pars.diss_warning_fraction, label);
            diss.depth = interp1(profile.slow.t_slow, profile.slow.depth, diss.t, "linear", "extrap");
            profile.bbl = mk_diss_struct(diss, dissInfo);
        catch ME
            fprintf("Error %s calculating Bottom->Top dissipation, %s\n", label, ME.message);
            for i = 1:numel(ME.stack)
                stk = ME.stack(i);
                fprintf("Stack(%d) line=%d name=%s file=%s\n", i, stk.line, string(stk.name), string(stk.file));
            end % for i
            profile.bbl = mk_empty_diss_struct(dissInfo);
        end % try
    else % Too little data, so fudge up profile.diss
        profile.bbl = mk_empty_diss_struct(dissInfo);
    end % if ~isempty
end % pars.bbl_calculate
end % calc_diss_shear

function dInfo = mk_empty_diss_struct(dissInfo)
arguments (Input)
    dissInfo struct % Input structure to get_diss_odas
end % arguments Input
arguments (Output)
    dInfo struct % structure with an empty table, but a P column for downstream binning
end % arguments Output

dInfo = struct();
dInfo.info = dissInfo;
tbl = table();
tbl.P = nan(0); % For binning
dInfo.tbl = tbl;
end % mk_empty_diss_struct

function dInfo = mk_diss_struct(diss, dissInfo)
arguments (Input)
    diss struct % Dissipation information from get_diss_odas
    dissInfo struct % Input dissipation information to get_diss_odas
end % arguments Input
arguments(Output)
    dInfo struct % Dissipation input information with a table of the dissipation results
end % arguments Output

dInfo = struct();
dInfo.info = dissInfo;
tbl = table();

% I don't like this hardcoding, but for single dissipation estimates I have
% not found a clean dynamic method!
npNames = ["e", "K_max", "method", "dof_e", "mad", "FM"];
pNames = ["speed", "nu", "P", "T", "t", "epsilonMean", "epsilonLnSigma", "depth"];
mnpNames = "Nasymth_spec";

for name = string(fieldnames(diss))'
    if ismember(name, pNames) % Column vectors of one sample per dissipation estimate
        tbl.(name) = diss.(name);
    elseif ismember(name, npNames) % n sensors x p dissipation estimates
        tbl.(name) = permute(diss.(name), [2,1]);
    elseif ismember(name, mnpNames) % m freq x n sensors x p disspation estimates
        tbl.(name) = perument(diss.(name), [3,2,1]);
    else
        dInfo.(name) = diss.(name);
    end % if
end % for

dInfo.tbl = tbl;
end % mk_diss_struct

function [dissInfo, SH_HP, AA] = mk_diss_info(profile, pars, pInfo, fftSec, fftFac, label)
arguments
    profile struct
    pars struct % From get_info
    pInfo (1,:) table
    fftSec string
    fftFac string
    label string
end % arguments

fast = profile.fast; % fast variables for despiking
fft_length_sec = pars.(fftSec);
fft_length_fac = pars.(fftFac);

AA = table();
for name = ["Ax", "Ay"]
    AA.(name) = my_despike(fast.(name), profile.fs_fast, pars, "A", ...
        append(label, " ", name, " ", fftSec), pInfo);
end
AA = table2array(AA);

% Grab all the shear probes
names = regexp(string(fast.Properties.VariableNames), "^sh\d+$", "once", "match");
names = unique(names(~ismissing(names))); % Sorted shear probes, assumes <10 shear probes

SH = table(); % Space for all the shear probes
for name = names
    SH.(name) = my_despike(fast.(name), profile.fs_fast, pars, "sh", ...
        append(label, " ", name, " ", fftSec), pInfo);
end % for
SH = table2array(SH);

HP_cut = 0.5 * 1 / fft_length_sec; % Follow Matlab manual
[bh, ah] = butter(1, HP_cut / profile.fs_fast / 2, "high");
% Do a forward filter then flip and reverse filter
SH_HP = filter(bh, ah, SH); % Filter forwards
SH_HP = flipud(SH_HP); % Flip forwards to backwards
SH_HP = filter(bh, ah, SH_HP); % Filter backwards
SH_HP = flipud(SH_HP); % Flip backwards to forward

dissInfo = struct();
dissInfo.fft_length = round(fft_length_sec * profile.fs_fast);
dissInfo.diss_length = fft_length_fac * dissInfo.fft_length;
dissInfo.overlap = ceil(dissInfo.diss_length / 2);
dissInfo.fs_fast = profile.fs_fast;
dissInfo.fs_slow = profile.fs_slow;
dissInfo.t = fast.t_fast;
dissInfo.P = fast.P_fast;

if ismember(pars.diss_speed_source, string(fast.Properties.VariableNames))
    dissInfo.speed = fast.(pars.diss_speed_source);
elseif ismember(pars.diss_speed_source, string(profile.slow.Properties.VariableNames))
    dissInfo.speed = interp1(profile.slow.t, profile.slow.(pars.diss_speed_source), fast.t, "linear", "extrap");
else
    error("diss_speed_source, %s, not in fast table", pars.diss_speed_source);
end % if ~ismember

if ismissing(pars.diss_T_source)
    dissInfo.T = ...
        (pars.diss_T1_norm * fast.T1_fast + pars.diss_T2_norm * fast.T2_fast) ./ ...
        (pars.diss_T1_norm + pars.diss_T2_norm);
else % if ismissing
    TName = pars.diss_T_source; % column name for temperature source
    if ismember(TName, string(fast.Properties.VariableNames)) % A fast variable
        dissInfo.T = fast.(TName);
    elseif ismember(TName, string(profile.slow.Properties.VariableNames)) % A slow variable
        dissInfo.T = interp1(profile.slow.t, profile.slow.(TName), fast.t, "linear", "extrap");
    else
        error("diss_T_source, %s, not found in fast nor slow", TName);
    end
end % if ismissing
end % mk_diss_info

function b = my_despike(a, fs, info, codigo, tit, pInfo)
arguments (Input)
    a (:,1) {mustBeNumeric} % Vector to be despiked
    fs (1,1) double {mustBePositive} % Samplig frequency
    info struct % Parameters, defaults from get_info
    codigo string % Middle field of parameter name, A or sh
    tit string % diagnostic title string
    pInfo (1,:) table % Profile summary information for this profile
end % arguments Input

p = struct();
for name = ["thresh", "smooth", "N_FS", "warning_fraction"]
    p.(name) = info.(sprintf("despike_%s_%s", codigo, name));
end % for name

[b, ~, ~, raction] = despike(a, p.thresh, p.smooth, fs, round(p.N_FS * fs));

if raction > p.warning_fraction
    fprintf("WARNING: %s spike ratio %.1f%% for profile %d in %s\n", ...
        tit, raction * 100, ...
        pInfo.index, pInfo.name);
end % raction >
end % my_despike

%% Get the mean epsilon, subject to expected variance

function diss = mk_epsilon_mean(diss, epsilonMinimumValue, diss_length, fs, warningFraction, label)
arguments (Input)
    diss struct % From get_diss_odas
    epsilonMinimumValue double {mustBePositive}
    diss_length double {mustBePositive}
    fs double {mustBePositive}
    warningFraction double
    label string
end % arguments Input
arguments (Output)
    diss struct % Modified version of diss
end % arguments Output

nu = diss.nu; % Dynamic viscosity
epsilon = diss.e'; % Transposed dissipation estimates
q = epsilon <= epsilonMinimumValue; % Values which should not exist, probably bad electronics
if any(q(:))
    epsilon(q) = nan;
    for index = 1:size(q,2)
        n = sum(q(:,index));
        if n > 0
            frac = n / size(q,1);
            if frac > warningFraction
                fprintf("WARNING: %s %.2f%% of the values for epsilon %d <= %g\n", ...
                    label, frac*100, index, epsilonMinimumValue);
            end % if
        end % if
    end % for
end % if any

L_K = (nu.^3 ./ epsilon).^(1/4); % Kolmogorov length (kg/m/s)
L = diss.speed * diss_length / fs; % Physical length of the data
L_hat = L ./ L_K;

Vf = 1; % Fraction of shear variance resolved by terminating the spectral integration at an upper wavenumber

L_f_hat = L_hat .* Vf.^(3/4);

var_ln_epsilon = 5.5 ./ (1 + (L_f_hat ./ 4).^(7/9)); % Variance of epsilon in log space
sigma_ln_epsilon = sqrt(var_ln_epsilon); % Standard deviation of epsilon in log space
mu_sigma_ln_epsilon = mean(sigma_ln_epsilon, 2, "omitnan"); % Mean across shear probes at each time
CF95_range = 1.96 * sqrt(2) * mu_sigma_ln_epsilon; % 95% confidence interval in log space

for iter = 1:(size(epsilon,2)-1) % To avoid an infinite loop, this is the an at most amount
    minE = min(epsilon, [], 2, "omitnan");
    [maxE, ix] = max(epsilon, [], 2, "omitnan"); % get indices in case we want to drop them
    ratio = abs(diff(log([minE, maxE]), 1, 2));
    q = ratio > CF95_range; % If minE and maxE ratio -> 95% confidence interval
    if ~any(q), break; end % We're done, we can use all the values
    epsilon(sub2ind(size(epsilon), find(q), ix(q))) = nan; % Set the maximums that are outside the 95% interval to nan
    frac = sum(q) / size(epsilon,1);
    if frac > warningFraction
        fprintf("WARNING: %s dropping %.2f%% epsilons outside of 95%% confidence interval, iter=%d\n", ...
            label, sum(q) / size(epsilon,1) * 100, iter);
    end % if
end % for iter

mu = exp(mean(log(epsilon), 2, "omitnan")); % Take the mean of the remaining values in log space
diss.epsilonMean = mu;
diss.epsilonLnSigma = mu_sigma_ln_epsilon;
end % mk_epsilon_mean
