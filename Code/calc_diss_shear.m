
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

function [dInfo, tbl] = calc_diss_shear(profile, pInfo, pars)
arguments (Input)
    profile struct % Profile information
    pInfo (1,:) table % Summary information about the profile
    pars struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    dInfo (1,:) table % pInfo with extra fields
    tbl table % Tabular form of diss struct
end % arguments Output

label = sprintf("%s(%d)", pInfo.name, pInfo.index);

[dissInfo, SH_HP, AA] = mk_diss_info(profile, pars, pInfo, label);

dNames = ["speed", "T", "t", "P"]; % Names that might need trimmed

if pars.diss_trim_top && pars.trim_calculate % Trim the top of the profile
    q = dissInfo.P >= (pInfo.trim_depth + pars.diss_trim_top_offset);
    SH_HP = SH_HP(q,:);
    AA  = AA(q,:);
    for name = dNames
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

if pars.diss_trim_bottom && pars.bottom_calculate % Trim the bottom of the profile
    q = dissInfo.P <= (pInfo.bottom_depth + pars.diss_trim_bottom_offset);
    SH_HP = SH_HP(q,:);
    AA  = AA(q,:);
    for name = dNames
        dissInfo.(name) = dissInfo.(name)(q);
    end % for name
end % if trim_use

dInfo = pInfo;
tbl = table(); % Nothing calculated

if size(SH_HP,1) < dissInfo.diss_length % Not enough data to work with
    fprintf("%s: Too little data to make a dissipation estimates, %d < diss length %d\n", ...
        label, size(SH_HP, 1), dissInfo.diss_length);
    return;
end % if size <

if pars.diss_reverse
    % flip upside down so the dissipation is calculated end to start in time (think BBL)
    SH_HP = flipud(SH_HP);
    AA = flipud(AA);
    for name = ["speed", "T", "t", "P"]
        dissInfo.(name) = flipud(dissInfo.(name));
    end % for name
end % if pars.diss_reverseå

try % dissipation estimates
    diss = get_diss_odas(SH_HP, AA, dissInfo); % ODAS library dissipation estimate
    diss = mk_epsilon_mean(diss, pars.diss_epsilon_minimum, pars.diss_warning_fraction, label);
    diss.depth = interp1(profile.slow.t_slow, profile.slow.depth, diss.t, "linear", "extrap");

    if ismember("elevation", profile.fast.Properties.VariableNames)
        diss.elevation = interp1(profile.fast.t_fast, profile.fast.elevation, diss.t, "linear", "extrap");
    end % if elevation

    diss.t = pInfo.t0 + seconds(diss.t - diss.t(1));

    [dInfo, tbl] = mk_diss_struct(pInfo, diss);
catch ME
    rethrow(ME)
    fprintf("Error %s calculating dissipation, %s\n", label, ME.message);
    for i = 1:numel(ME.stack)
        stk = ME.stack(i);
        fprintf("Stack(%d) line=%d name=%s file=%s\n", i, stk.line, string(stk.name), string(stk.file));
    end % for i
end % try
end % calc_diss_shear

function [dInfo, tbl] = mk_diss_struct(pInfo, diss)
arguments (Input)
    pInfo (1,:) table % Profile information
    diss struct % Dissipation information from get_diss_odas
end % arguments Input
arguments(Output)
    dInfo (1,:) table % Dissipation input information with a table of the dissipation results, built on pInfo
    tbl table % Dissipation information built into a table, rows are depth/time
end % arguments Output

% I don't like hardcoding names, but for a single dissipation estimate, size fails
pNames = ["speed", "nu", "P", "T", "t", "AOA", "epsilonMean", "epsilonLnSigma", "depth", "elevation"];
npNames = ["e", "K_max", "method", "dof_e", "mad", "FM"];
mnpNames = "Nasmyth_spec";
mnnpNames = ["sh_clean", "sh", "AA", "UA"];
mpNames = ["F", "K"];

dInfo = pInfo; % We're going to add to pInfo columns with dissipation scalars
tbl = table();
tbl.t = diss.t; % Force as first column
tbl.depth = diss.depth; % Force to the second column

for name = string(fieldnames(diss))'
    val = diss.(name);
    if isempty(val), continue; end
    if isscalar(val)
        dInfo.(name) = diss.(name);
    elseif ismember(name, pNames)
        tbl.(name) = val;
    elseif ismember(name, npNames) || ismember(name, mpNames)
        tbl.(name) = val';
    elseif ismember(name, mnpNames)
        tbl.(name) = permute(val, [3,2,1]);
    elseif ismember(name, mnnpNames)
        tbl.(name) = permute(val, [4,2,3,1]);
    else
        fprintf("Unknown %s\n", name);
    end
end
end % mk_diss_struct

function [dissInfo, SH_HP, AA] = mk_diss_info(profile, pars, pInfo, label)
arguments
    profile struct
    pars struct % From get_info
    pInfo (1,:) table
    label string
end % arguments

fast = profile.fast; % fast variables for despiking
fft_length_sec = pars.diss_fft_length_sec;
diss_length_factor = pars.diss_length_fac;

AA = table();
for name = ["Ax", "Ay"]
    AA.(name) = my_despike(fast.(name), pInfo.fs_fast, pars, "A", ...
        sprintf("%s %s %2g", label, name, fft_length_sec), pInfo);
end
AA = table2array(AA);

% Grab all the shear probes
names = regexp(string(fast.Properties.VariableNames), "^sh\d+$", "once", "match");
names = unique(names(~ismissing(names))); % Sorted shear probes, assumes <10 shear probes

SH = table(); % Space for all the shear probes
for name = names
    SH.(name) = my_despike(fast.(name), pInfo.fs_fast, pars, "sh", ...
        sprintf("%s %s %2g", label, name, fft_length_sec), pInfo);
end % for
SH = table2array(SH);

HP_cut = 0.5 * 1 / fft_length_sec; % Follow Matlab manual
[bh, ah] = butter(1, HP_cut / pInfo.fs_fast / 2, "high");
% Do a forward filter then flip and reverse filter
SH_HP = filter(bh, ah, SH); % Filter forwards
SH_HP = flipud(SH_HP); % Flip forwards to backwards
SH_HP = filter(bh, ah, SH_HP); % Filter backwards
SH_HP = flipud(SH_HP); % Flip backwards to forward

dissInfo = struct();
dissInfo.fft_length = round(fft_length_sec * pInfo.fs_fast); % FFT length in bins
dissInfo.diss_length = diss_length_factor * dissInfo.fft_length; % Dissipation length in bins

if pars.diss_overlap_factor == 0
    dissInfo.overlap = 0; % No overlap
else
    dissInfo.overlap = ceil(dissInfo.diss_length / pars.diss_overlap_factor); % Number of bins to overlap
end

for name = ["goodman", "f_limit", "fit_2_isr", "f_AA", "fit_order"]
    val = pars.(append("diss_", name));
    if isnan(val), continue; end
    dissInfo.(name) = val;
end

dissInfo.fs_fast = pInfo.fs_fast;
dissInfo.fs_slow = pInfo.fs_slow;
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

function b = my_despike(a, fs, pars, codigo, tit, pInfo)
arguments (Input)
    a (:,1) {mustBeNumeric} % Vector to be despiked
    fs (1,1) double {mustBePositive} % Samplig frequency
    pars struct % Parameters, defaults from get_info
    codigo string % Middle field of parameter name, A or sh
    tit string % diagnostic title string
    pInfo (1,:) table % Profile summary information for this profile
end % arguments Input

p = struct();
for name = ["thresh", "smooth", "N_FS", "warning_fraction"]
    p.(name) = pars.(sprintf("despike_%s_%s", codigo, name));
end % for name

[b, ~, ~, raction] = despike(a, p.thresh, p.smooth, fs, round(p.N_FS * fs));

if raction > p.warning_fraction
    fprintf("WARNING: %s spike ratio %.1f%% for profile %d in %s\n", ...
        tit, raction * 100, ...
        pInfo.index, pInfo.name);
end % raction >
end % my_despike

%% Get the mean epsilon, subject to expected variance

function diss = mk_epsilon_mean(diss, epsilonMinimumValue, warningFraction, label)
arguments (Input)
    diss struct % From get_diss_odas
    epsilonMinimumValue double {mustBePositive}
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

diss_length = diss.diss_length;
fs = diss.fs_fast;

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
