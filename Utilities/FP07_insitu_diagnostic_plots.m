% Diagnostic plots for fp07 in situ calibration from profiles
%
% The first argument is a profile mat filename
% Optional arguments are:
%  profiles a vector of profiles to plot, if not specified, all profiles are ploted
%  CT_T_name reference temperature, JAC_T by default
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function a = FP07_insitu_diagnostic_plots(varargin)
p = inputParser();
addRequired(p, "fn", @isfile);
addParameter(p, "profiles", [], @(x) ~isempty(x));
addParameter(p, "CT_T_name", "JAC_T", @isstring);
parse(p, varargin{:});

pars = p.Results;
fn = pars.fn;
profiles = pars.profiles;
CT_T_name = pars.CT_T_name;

a = load(fn);

if ~isfield(a, "fp07Lags")
    error("fp07Lags is not a field in %s", fn);
end

fp07Lags = a.fp07Lags;
pInfo = a.pInfo;

if isempty(profiles)
    profiles = 1:numel(a.profiles);
end % if isempty

fitOrder = size(a.fp07Lags.beta,2);

tits = strings(size(fp07Lags, 1),1);
for i = 1:size(fp07Lags,1)
    row = fp07Lags(i,:);
    tit = sprintf("%s lag=%.3f $$T_0=%.3f\\pm%.2f", row.channel, row.lag, row.T0, row.T0_std);
    for j = 1:fitOrder
        tit = append(tit, sprintf(", \\beta_%d=%.1f\\pm%.1f", j, row.beta(j), row.beta_std(j)));
    end
    tits(i) = append(tit, "$$");
end % for i

names = [CT_T_name; append(fp07Lags.channel, "_slow"); append(fp07Lags.channel, "_fast")]';

depthLimits = [ ...
    min(pInfo.min_depth(profiles), [], "omitnan"), ...
    max(pInfo.max_depth(profiles), [], "omitnan") ...
    ];

tempLimits = nan(2,1);
dTempLimits = nan(2,1);

for i = profiles
    profile = a.profiles{i};
    slow = profile.slow;
    fast = profile.fast;
    fast.(CT_T_name) = interp1(slow.t, slow.(CT_T_name), fast.t, "linear", "extrap");

    for name = names
        if endsWith(name, "_fast")
            tempLimits(1) = min(tempLimits(1), min(fast.(name), [], "omitnan"));
            tempLimits(2) = max(tempLimits(2), max(fast.(name), [], "omitnan"));
            dTempLimits(1) = min(dTempLimits(1), min(fast.(CT_T_name) - fast.(name), [], "omitnan"));
            dTempLimits(2) = max(dTempLimits(2), max(fast.(CT_T_name) - fast.(name), [], "omitnan"));
        else % slow
            tempLimits(1) = min(tempLimits(1), min(slow.(name), [], "omitnan"));
            tempLimits(2) = max(tempLimits(2), max(slow.(name), [], "omitnan"));
            if ~isequal(name, CT_T_name)
                dTempLimits(1) = min(dTempLimits(1), min(slow.(CT_T_name) - slow.(name), [], "omitnan"));
                dTempLimits(2) = max(dTempLimits(2), max(slow.(CT_T_name) - slow.(name), [], "omitnan"));
            end % if ~isequal
        end % if endsWith
    end % for name
end % for i

for i = profiles
    row = pInfo(i,:);
    profile = a.profiles{i};
    slow = profile.slow;
    fast = profile.fast;
    fast.(CT_T_name) = interp1(slow.t, slow.(CT_T_name), fast.t, "linear", "extrap");

    clf;
    tiledlayout(1,2);
    h0 = nexttile();
    for name = names
        if endsWith(name, "_fast")
            plot(fast.(name), fast.P_fast, "-");
        else
            plot(slow.(name), slow.P_slow, "-");
        end
        hold on;
    end % for j
    hold off;
    axis ij;
    grid on;
    xlabel("Temperature (C)");
    ylabel("Depth (m)");
    xlim(tempLimits);
    ylim(depthLimits);
    legend(names, "Location", "best", "Interpreter", "none");

    h1 = nexttile();
    for j = 2:numel(names)
        name = names(j);
        if endsWith(name, "_fast")
            plot(fast.(CT_T_name) - fast.(name), fast.P_fast, "-");
        else
            plot(slow.(CT_T_name) - slow.(name), slow.P_slow, "-");
        end
        hold on;
    end % for j
    hold off;
    hold off;
    axis ij;
    grid on;
    xlabel("Temperature (C)");
    xlim(dTempLimits);
    ylim(depthLimits);
    legend(append(names(1), "-", names(2:end)), "Location", "best", "Interpreter", "none");

    sgtitle([sprintf("%s Profile %d %s to %s", row.name, i, slow.t(1), slow.t(end)); tits], ...
        "interpreter", "latex");

    linkaxes([h0, h1], "y");
    
    if i ~= profiles(end), waitforbuttonpress(); end
end % for i
end % FP07_insitu_diagnostic_plots