%
% do an in-situ calibration of the FP07 probes against the CT_T_name sensor
%
% This was derived from odas 4.5.1's cal_FP07_in_situ.m
%
% July-2023, Pat Welch, pat@mousebrains.com

function a = fp07_calibration(a, indicesSlow, pars, basename)
arguments (Input)
    a struct % Output of odas_p2mat
    indicesSlow (2,:) int64 % Output of get_profile, indices into slow vectors for profiles
    pars struct % Parameters, defaults from get_info
    basename string % label for the file
end % arguments Input
arguments (Output)
    a struct % possibly modified version of odas_p2mat output
end % arguments Output

if ~pars.fp07_calibration, return; end % Don't calibrate the FP07 sensors

[Treference, TNames] = extractNames(a, pars.CT_T_name, basename); % Get the sensor channels and variable names

if isempty(Treference) || isempty(TNames), return; end % no reference nor fp07s  found

TNames.fp = append(TNames.channel, "_counts"); % FP07 sensor converted to counts
TNames.lp = append(TNames.channel, "_lp");     % FP07 counts low pass filtered to drop pre-emphasis
TNames.RT_R0 = append(TNames.channel, "_RT_R0"); % ln(R_T / R_0)
TNames.Ref = append(TNames.channel, "_Ref");   % Reference thermistor
TNames.pred = append(TNames.channel, "_pred"); % Prediction variable name

slow = table(); % Slow variables we'll use
slow.TRef = a.(Treference);

for i = 1:size(TNames,1)
    row = TNames(i,:);
    % Convert to counts/resistance
    slow.(row.fp) = getFP07Temperature(a, row, a.fs_slow, a.fs_fast);
    % Lowpass filter counts
    slow.(row.lp) = lowPassFilter(slow.(row.fp), a.(Treference), a.fs_slow, a.W_slow, indicesSlow);
    slow.(row.RT_R0) = compute_RT_R0(slow.(row.fp), a.cfgobj, row.channel); % ln(R_T / R_0) for fp07
end

% For each profile and channel find the sensor lag between the channel and reference temperature
fp07Info = table();
fp07Info.channel = strings(size(indicesSlow,2) * size(TNames, 1), 1); % n channels per profile
fp07Info.lag = nan(size(fp07Info.channel));
fp07Info.maxCorr = nan(size(fp07Info.channel));

slow.qInProfile = false(size(slow.TRef));

for i = 1:size(indicesSlow,2) % Walk through each profile
    ii = indicesSlow(1,i):indicesSlow(2,i); % Indices in this profile
    slow.qInProfile(ii) = true; % These rows in slow are in a profile
    sProf = slow(ii,:); % Just this profile
    for j = 1:size(TNames,1) % Walk through each channel
        index = size(TNames,1) * (i-1) + j;
        fp07Info.channel(index) = TNames.channel(j);
        [fp07Info.lag(index), fp07Info.maxCorr(index)] = ...
            calcLag(sProf.TRef, sProf.(TNames.lp(j)), a.fs_slow, pars);
    end % for j
end % for i

% For each channel summarize the lags for all the casts
fp07Info.grp = findgroups(fp07Info.channel);
fp07Info = rowfun(@mkFP07Stats, fp07Info, ...
    "InputVariables", ["channel", "lag", "maxCorr"], ...
    "GroupingVariables", "grp", ...
    "OutputVariableNames", ...
    ["channel", ...
    "lag", "lagMin", "lagMax", "lagSigma", ...
    "corr", "corrMin", "corrMax", "corrSigma"]);
fp07Info = removevars(fp07Info, "grp");
fp07Info = renamevars(fp07Info, "GroupCount", "n");
fp07Info.name = repmat(basename, size(fp07Info.n));
fp07Info.iShift = round(fp07Info.lag * a.fs_slow); % Bins to shift

% Create lagged version of TRef for each sensor
for i = 1:size(TNames,1)
    slow.(TNames.Ref(i)) = circshift(slow.TRef, fp07Info.iShift(i));
end

slow.TRef_shifted = circshift(slow.TRef, round(mean(fp07Info.iShift)));

% Add columns for the fit
fp07Info.T0 = nan(size(fp07Info.name));
fp07Info.T0_std = nan(size(fp07Info.name));
fp07Info.beta = nan(size(fp07Info,1), pars.fp07_order);
fp07Info.beta_std = nan(size(fp07Info,1), pars.fp07_order);

fitTo = slow(slow.qInProfile,:); % All the samples in profiles

% Fit to Stein-Hart for each sensor

eqn = strings(pars.fp07_order,1);

for i = 1:pars.fp07_order
    if i == 1
        eqn(i) = "RT_R0";
    else
        eqn(i) = sprintf("RT_R0^%d", i);
    end
end

eqn = append("tgt ~ ", strjoin(eqn, "+"));

fast = table();

for i = 1:size(TNames,1) % Walk through the sensor pairs
    row = TNames(i,:);
    channel = row.channel;

    tbl = table();
    tbl.tgt = 1 ./ (fitTo.(row.Ref) + 273.15); % 1/K of lagged reference sensor
    tbl.RT_R0 = fitTo.(row.RT_R0); % ln(R_T/R_0)

    mdl = fitlm(tbl,eqn);
    sigma = 1 ./ mdl.Coefficients.Estimate ./ mdl.Coefficients.tStat;

    fp07Info.T0(i) = 1 ./ mdl.Coefficients.Estimate(1);
    fp07Info.T0_std(i) = sigma(1);
    fp07Info.beta(i,:) = 1 ./ mdl.Coefficients.Estimate(2:end);
    fp07Info.beta_std(i,:) = sigma(2:end);

    slow.(row.RT_R0) = compute_RT_R0(slow.(row.fp), a.cfgobj, channel); % Not low passed
    slow.(row.pred) = 1 ./ predict(mdl, slow.(row.RT_R0)) - 273.15;

    fast.(row.fp) = getFP07Temperature(a, row, a.fs_fast, a.fs_fast);
    fast.(row.RT_R0) = compute_RT_R0(fast.(row.fp), a.cfgobj, channel); 
    fast.(row.pred) = 1 ./ predict(mdl, fast.(row.RT_R0)) - 273.15;
end % for i

%% Replace values in a

for i = 1:size(TNames,1)
    row = TNames(i,:);
    a.(append(row.channel, "_slow")) = slow.(row.pred);
    a.(append(row.channel, "_fast")) = fast.(row.pred);
end

a.(Treference) = slow.TRef_shifted;
a.fp07Info = fp07Info;
end % fp07Calibrationa 

%%
function RT_R0 = compute_RT_R0(T, cfgObj, channel)
channelName = char(channel);
row = table();
for name = ["type", "E_B", "a", "b", "G", "adc_fs", "adc_bits", "adc_zero"]
    val = setupstr(cfgObj, channelName, char(name));
    if isempty(val)
        val = 0;
    else
        a = str2double(val);
        if ~isnan(a)
            val = a; 
        else
            val = string(val);
        end
    end % if
    row.(name) = val;
end % for name

factor = (row.adc_fs / 2^row.adc_bits);
if row.type == "therm"
    factor = factor * 2 / (row.G * row.E_B);
    Z = factor * (T - row.a) / row.b;
else
    Z = T * factor + row.adc+zero;
    Z = ((Z - row.a) / row.b) * 2 / (row.G * row.E_B);
end

RT_R0 = log((1 - Z) ./ (1 + Z)); % Resistance ratio for this thermistor
end % compute_RT_R0

%%
function Tfp07 = lowPassFilter(Tfp07, Treference, fs_slow, W_slow, indicesSlow)
arguments
    Tfp07 (:,1) double
    Treference string
    fs_slow double
    W_slow (:,1) double
    indicesSlow (2,:) int64
end % arguments
% Low pass filter the FP07 to make it more compatible with the slow
% thermistor
if isequal(Treference, "JAC_T")
    cnt = 0;
    Wsum = 0;
    for index = 1:size(indicesSlow,2)
        ii = indicesSlow(1,index):indicesSlow(2,index);
        cnt = cnt + numel(ii);
        Wsum = Wsum + sum(W_slow(ii));
    end
    W_mean = abs(Wsum / cnt);
    fc = 0.73 * sqrt(W_mean / 0.62); % in Hz from odas
else % Sea-Bird Thermistor or hotel
    fc = fs_slow/3;
end % if isequal
[b,a] = butter(1, fc/(fs_slow/2)); % Low-pass filter parameters
Tfp07 = filter(b,a,Tfp07); % Low pass filter the FP07 thermistor to make it more like the slow thermistor
end % lowPassFilter

%%
function [lag, maxCorr] = calcLag(Tref, Tfp07, fs_slow, pars)
arguments
    Tref (:,1) double
    Tfp07 (:,1) double
    fs_slow double
    pars struct % From get_info with modifications
end % arguments

maxSeconds = pars.fp07_maximum_lag_seconds;
maxLag = round(maxSeconds * fs_slow); % maximum lag in bins
[bb, aa] = butter(2, 4/(fs_slow/2)); % 4 Hz smoother to supress high-frequency noise
[correlation, lags] = xcorr( ...
    filter(bb, aa, detrend(diff(Tfp07))), ...
    filter(bb, aa, detrend(diff(Tref))), ...
    maxLag, "coeff");

if pars.fp07_must_be_negative
    % Lag should be less than zero for a VMP with a CT sensor
    % since Tref is behind FP07 in motion
    % The correlation should be positive, unless the response is inverted
    % One expects the lag to be ~physical distance / fall speed
    [~, iZero] = min(abs(lags)); % index for dt zero
    [maxCorr, iLag] = max(correlation(1:iZero)); % Only consider <= 0 lags
else
    [maxCorr, iLag] = max(correlation); % Can be positive or negative lag
end % if fp07 must be negative

lag = lags(iLag) / fs_slow; % Lag in seconds
end % calcLag

%%
% Convert from physical units to counts which is linear in resistance
%
function Tfp07 = getFP07Temperature(a, TNames, fs_slow, fs_fast)
arguments (Input)
    a struct           % Output of odas_p2mat
    TNames (1,:) table % variable to convert
    fs_slow double     % Slow sampling frequency in Hertz
    fs_fast double     % Fast sampling frequency in Hertz
end % arguments Input
arguments (Output)
    Tfp07 (:,1) double % FP07 converted to counts
end % arguments Output

% Get the FP07 temperature to use from the entire file

if ismissing(TNames.fast) % No data with pre-emphasis, i.e. T1_dT1
    Tfp07 = a.(TNames.slow);
    if fs_slow >= fs_fast % Upsample slow to fast
        Tfp07 = interp1(a.t_slow, Tfp07, a.t_fast, "linear", "extrap");
    end % if fs_slow
else % Data with pre-emphasis, so downsample
    fp07Name = TNames.fast;
    if ismissing(TNames.slow)
        Tslow = [];
    else
        Tslow = a.(TNames.slow);
    end % if
    Tfp07 = deconvolve(char(fp07Name), Tslow, a.(fp07Name), fs_fast, a.setupfilestr);
    if fs_slow < fs_fast % Only downsample fast to slow
        ratio = round(fs_fast / fs_slow); % Number of samples to downsample by
        Tfp07 = reshape(Tfp07, ratio, []); % Reshape by number to downsample
        Tfp07 = mean(Tfp07)'; % Down sample
    end % if fs_slow
end % ismissing
end % getTemperatures

%%
% Get thermistor names
%
function [Treference, tbl] = extractNames(a, Treference, basename)
arguments
    a struct
    Treference string
    basename string
end % arguments

tbl = [];

if ~isfield(a, Treference)
    fprintf("WARNING: Temperature reference, %s, not found in %s\n", Treference, basename);
    Treference = [];
    return;
end % if ~isfield

tbl = outerjoin( ...
    extractVariables("slow", a, "^(T\d+)$"), ... % T1 like variables
    extractVariables("fast", a, "^(T\d+)_dT\d+$"),  ...% T1_dT1 like variables
    "Keys", "channel", "MergeKeys", true);

if isempty(tbl)
    fprintf("WARNING: No FP07 temperature sensors found for %s!\n", basename);
end % if
end % extractNames

%%
function tbl = extractVariables(name, a, exp)
arguments
    name string
    a struct
    exp string
end % arguments

[varNames, tokens] = regexp(string(fieldnames(a)), exp, "match", "tokens", "once", "emptymatch");
q = ~ismissing(varNames);

if any(q)
    tbl = table();
    tbl.channel = string(tokens(q));
    tbl.(name) = varNames(q);
else
    tbl = table('Size', [0,2], ...
        'VariableTypes', {'string', 'string'}, ...
        'VariableNames', {'channel', char(name)});
end % if any
end % extractVariables

%%
% Calculate summary statistics for the lags from each cast

function [channel, lag, lagMin, lagMax, lagSigma, corr, corrMin, corrMax, corrSigma] = mkFP07Stats( ...
    channel, lags, maxCorr)
arguments (Input)
    channel (:,1) string
    lags (:,1) double
    maxCorr (:,1) double
end % arguments Input
arguments (Output)
    channel string
    lag double
    lagMin double
    lagMax double
    lagSigma double
    corr double
    corrMin double
    corrMax double
    corrSigma double
end % arguments Output

channel = channel(1);

lag = median(lags, "omitnan");
lagMin = min(lags, [], "omitnan");
lagMax = max(lags, [], "omitnan");
lagSigma = std(lags, "omitnan");

corr = median(maxCorr, "omitnan");
corrMin = min(maxCorr, [], "omitnan");
corrMax = max(maxCorr, [], "omitnan");
corrSigma = std(maxCorr, "omitnan");
end % mkFP07Stats