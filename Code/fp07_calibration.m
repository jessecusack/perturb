%
% do an in-situ calibration of the FP07 probes against the JAC_T
%
% This was derived from odas 4.5.1's cal_FP07_in_situ.m
%
% July-2023, Pat Welch, pat@mousebrains.com

function a = fp07_calibration(a, indicesSlow, indicesFast, info)
arguments (Input)
    a struct % Output of odas_p2mat
    indicesSlow (2,:) int64 % Output of get_profile, indices into slow vectors for profiles
    indicesFast (2,:) int64 % Output of get_profile, indices into fast vectors for profiles
    info struct % Parameters, defaults from get_info
end % arguments Input
arguments (Output)
    a struct % possibly modified version of odas_p2mat output
end % arguments Output

if ~info.fp07_calibration, return; end % Don't calibrate the FP07 sensors

cfgObj = setupstr(char(a.setupfilestr));

[Treference, TNames] = extractNames(a, info.fp07_reference);

if isempty(Treference) || isempty(TNames), return; end % no reference nor fp07s  found


fp07Info = cell(size(TNames,1),1);
for index = 1:size(TNames,1)
    row = TNames(index,:);
    [a, row] = calibrateProfiles(a, indicesSlow, indicesFast, Treference, row, info, cfgObj);
    fp07Info{index} = row;
end % for index
TNames = vertcat(fp07Info{:});
lag = median(TNames.lag);
iBack = round(lag * a.fs_slow);

if contains(Treference, "_") % Something like JAC_T
    parts = split(Treference, "_");
    prefix = parts(1);
else
    prefix = "JAC_"; % Take a guess
end

names = string(fieldnames(a)); % All variable names
names = names(startsWith(names, prefix)); % Ones that start with prefix

fprintf("%s shifting %s by %f seconds to match FP07(s)\n", a.label, strjoin(names, ", "), lag);

for name = names'
    a.(name) = circshift(a.(name), iBack);
end % for name

a.TNames = TNames;
end % fp07Calibrationa 

%%
function [a, TNames] = calibrateProfiles(a, indicesSlow, indicesFast, Treference, TNames, info, cfgObj)
arguments
    a struct
    indicesSlow (2,:) int64
    indicesFast (2,:) int64
    Treference string
    TNames table
    info struct
    cfgObj (1,:) struct
end % arguments

fs_slow = a.fs_slow;
fs_fast = a.fs_fast;

Tref = a.(Treference);
Tfp07 = getFP07Temperature(a, TNames, fs_slow, fs_fast);
TT = lowPassFilter(Tfp07, Treference, fs_slow, a.W_slow, indicesSlow); % Lowpass filter Tfp07

% Get all the lags
lag = cell(size(indicesSlow,2),1);
for index = 1:numel(lag)
    ii = indicesSlow(1,index):indicesSlow(2,index);
    [vLag, maxCorr] = calcLag(Tref(ii), TT(ii), fs_slow);
    lag{index} = struct( ...
        "lag", vLag, ...
        "maxCorr", maxCorr, ...
        "n", numel(ii));
end % for index
lag = struct2table(vertcat(lag{:}));
a.(append("fp07_lags_", TNames.channel)) = lag;
TNames.minCorr = min(lag.maxCorr);
TNames.medianCorr = median(lag.maxCorr);
TNames.maxCorr = max(lag.maxCorr);

lag = sortrows(lag, "lag"); % Order by lag
lag.cumsum = cumsum(lag.n .* lag.maxCorr); % weighting to find "median"
[~, ix] = min(abs(lag.cumsum - max(lag.cumsum)/2)); % argmin of midpoint
TNames.lag = lag.lag(ix); % psuedo median
iBack = round(TNames.lag * fs_slow); % Index to shift

Tref = circshift(Tref, iBack); % Shift JACT to when FP07 has the highest correlation

% Prepare data set to look at using all the profile
% odas only uses one.

tbl = cell(size(indicesSlow,2),1); % To hold FP07 mined information

for index = 1:size(tbl,1)
    ii = indicesSlow(1,index):indicesSlow(2,index);
    item = table();
    item.Tref = Tref(ii);
    item.T = TT(ii);
    tbl{index} = item;
end % for index
tbl = vertcat(tbl{:});

tbl.Tref_regress = 1 ./ (tbl.Tref + 273.15); % C -> 1/K

order = info.fp07_order; % Polynomial order
TrefMinRange = 8;
if range(tbl.Tref) <= TrefMinRange && order > 1
    warning("Temperature range, %g, is less than %g degrees and order(%g) > 1\nRecommend using order 1", ...
        range(tbl.Tref), TrefMinRange, order);
end % if range

tbl.RT_R0 = compute_RT_R0(tbl.T, cfgObj, TNames.channel);

% Generate the coefficients for this thermistor
pFit = polyfit(tbl.RT_R0, tbl.Tref_regress, order);
TNames.T_0 = 1 ./ pFit(end); % Constant term
TNames.beta = 1 ./ pFit(end-1:-1:1);

fprintf("%s %s lag %f T_0 %g beta %s\n", ...
    a.label, TNames.channel, TNames.lag, TNames.T_0, num2str(TNames.beta));

% The slow predicted temperature for the whole series
RT_R0 = compute_RT_R0(TT, cfgObj, TNames.channel);
Tslow = 1 ./ polyval(pFit, RT_R0) - 273.15;
a.(append(TNames.channel, "_slow")) = Tslow;

if ~ismissing(TNames.fast)
    TT = lowPassFilter(a.(TNames.fast), Treference, fs_fast, a.W_fast, indicesFast);
    RT_R0 = compute_RT_R0(TT, cfgObj, TNames.channel);
    Tfast = 1 ./ polyval(pFit, RT_R0) - 273.15;
    a.(append(TNames.channel, "_fast")) = Tfast;
end % if
end % calibrateProfiles

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
else % Sea-Bird Thermistor
    fc = fs_slow/3;
end % if isequal
[b,a] = butter(1, fc/(fs_slow/2)); % Low-pass filter parameters
Tfp07 = filter(b,a,Tfp07); % Low pass filter the FP07 thermistor to make it more like the slow thermistor
end % lowPassFilter

%%
function [lag, maxCorr] = calcLag(Tref, Tfp07, fs_slow)
arguments
    Tref (:,1) double
    Tfp07 (:,1) double
    fs_slow double
end % arguments
maxLag = round(10 * fs_slow); % A 10 second maximum lag
[bb, aa] = butter(2, 4/(fs_slow/2)); % 4 Hz smoother to supress high-frequency noise
[correlation, lags] = xcorr( ...
    filter(bb, aa, detrend(diff(Tfp07))), ...
    filter(bb, aa, detrend(diff(Tref))), ...
    maxLag, "coeff");

[~, iZero] = min(abs(lags)); % index for dt zero
% Lag should be less than zero since Tref is behind FP07 in motion
% The correlation should be positive, unless the response is inverted
% One expects the lag to be ~physical distance / fall speed
[maxCorr, iLag] = max(correlation(1:iZero)); % Only consider <= 0 lags
lag = lags(iLag) / fs_slow; % Lag in seconds
end % calcLag

%%
function Tfp07 = getFP07Temperature(a, TNames, fs_slow, fs_fast)
arguments
    a struct
    TNames table
    fs_slow double
    fs_fast double
end % arguments

% Get the FP07 temperature to use from the entire file

if ismissing(TNames.fast) % No data with pre-emphasis, i.e. T1_dT1
    Tfp07 = a.(TNames.slow);
else % Data with pre-emphasis, so downsample
    fp07Name = TNames.fast;
    if ismissing(TNames.slow)
        Tslow = [];
    else
        Tslow = a.(TNames.slow);
    end % if
    Tfp07 = deconvolve(char(fp07Name), Tslow, a.(fp07Name), fs_fast, a.setupfilestr);
    ratio = round(fs_fast / fs_slow);
    Tfp07 = reshape(Tfp07, ratio, []);
    Tfp07 = mean(Tfp07)';
end % ismissing
end % getTemperatures

%%
function [Treference, tbl] = extractNames(a, Treference)
arguments
    a struct
    Treference string
end % arguments

tbl = [];

if ~isfield(a, Treference)
    fprintf("WARNING: Temperature reference, %s, not found in %s\n", Treference, a.label);
    Treference = [];
    return;
end % if ~isfield

tbl = outerjoin( ...
    extractVariables("slow", a, "^(T\d+)$"), ... % T1 like variables
    extractVariables("fast", a, "^(T\d+)_dT\d+$"),  ...% T1_dT1 like variables
    "Keys", "channel", "MergeKeys", true);

if isempty(tbl)
    fprintf("WARNING: No FP07 temperature sensors found for %s!\n", a.label);
end % if
end % extractNames

%%
function info = extractVariables(name, a, exp)
arguments
    name string
    a struct
    exp string
end % arguments

[varNames, tokens] = regexp(string(fieldnames(a)), exp, "match", "tokens", "once", "emptymatch");
q = ~ismissing(varNames);

if any(q)
    info = table();
    info.channel = string(tokens(q));
    info.(name) = varNames(q);
else
    info = table('Size', [0,2], ...
        'VariableTypes', {'string', 'string'}, ...
        'VariableNames', {'channel', char(name)});
end % if any
end % extractVariables
