% Diagnostic plots for trim limits from profiles
%
% The first argument is a profile mat filename
% Optional arguments are:
%  profiles a vector of profiles to plot, if not specified, all profiles are ploted
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function a = trim_diagnostic_plots(varargin)
p = inputParser();
addRequired(p, "fn", @isfile);
addParameter(p, "profiles", [], @(x) ~isempty(x));
addParameter(p, "minDepth", nan, @isreal);
addParameter(p, "maxDepth", nan, @isreal);
addParameter(p, "shLimit", nan, @isreal);
addParameter(p, "ALimit", nan, @isreal);
addParameter(p, "smoother", nan, @(x) isreal(x) & x > 0);
parse(p, varargin{:});

pars = p.Results;
fn = pars.fn;
profiles = pars.profiles;

a = load(fn);

if isempty(profiles)
    profiles = 1:numel(a.profiles);
end % if isempty

pInfo = a.pInfo;

depthLimits = [ ...
    min(pInfo.min_depth(profiles), [], "omitnan"), ...
    max(pInfo.max_depth(profiles), [], "omitnan") ...
    ];

if ~isnan(pars.minDepth), depthLimits(1) = pars.minDepth; end
if ~isnan(pars.maxDepth), depthLimits(2) = pars.maxDepth; end
depthLimits = sort(depthLimits);

names = ["Ax", "Ay", "sh1", "sh2", "dz/dt", "accel", "Incl_X", "Incl_Y", "JAC_T", "SP"];

for i = profiles
    row = pInfo(i,:);
    profile = a.profiles{i};
    slow = profile.slow;
    fast = profile.fast;
    fsFast = 1 / median(diff(fast.t_fast));
    fsSlow = 1 / median(diff(slow.t_slow));
    vel = diff(fast.depth) ./ diff(fast.t_fast);
    depthVel = (fast.depth(1:end-1) + fast.depth(2:end)) / 2;
    accel = diff(vel) ./ (fast.t_fast(3:end) - fast.t_fast(1:end-2));
    depthAccel = (depthVel(1:end-1) + depthVel(2:end)) / 2;

    qFast = ismember(names, fast.Properties.VariableNames);
    qSlow = ismember(names, slow.Properties.VariableNames);

    trimDepth = nan;
    bottomDepth = nan;

    if ismember("trim_depth", row.Properties.VariableNames)
            trimDepth = row.trim_depth;
    end % if

    if ismember("bottom_depth", row.Properties.VariableNames)
        bottomDepth = row.bottom_depth;
    end % if

    clf;
    tiledlayout(1, numel(names));
    h = cell(numel(names), 1);
    for j = 1:numel(names)
        name = names(j);
        h{j} = nexttile();
        if qFast(j)
            x = fast.(name);
            y = fast.depth;
            fs = fsFast;
        elseif qSlow(j)
            x = slow.(name);
            y = slow.depth;
            fs = fsSlow;
        elseif isequal(name, "dz/dt")
            x = vel;
            y = depthVel;
            fs = fsFast;
        elseif isequal(name, "accel")
            x = accel;
            y = depthAccel;
            fs = fsFast;
        else
            error("Unsupported name %s", name);
        end

        qTrimmed = true(size(x));

        if ~isnan(trimDepth)
            qTrimmed = qTrimmed & y >= trimDepth;
        end % if

        if ~isnan(bottomDepth)
            qTrimmed = qTrimmed & y <= bottomDepth;
        end % if

        x = detrend(x);

        plot(x, y, "-", x(qTrimmed), y(qTrimmed), "-");

        if ~isnan(pars.smoother)
            [bb, aa] = butter(1, pars.smoother / (fs / 2)); % smoother frequency smoother
            xSmooth = filter(bb, aa, x);
            hold on;
            plot(filter(bb, aa, x), y, "-k", "LineWidth", 0.5);
        end % if smoother

        axis ij;
        grid on;
        ylim(depthLimits);
        % xlim(quantile(x, [0.01, 0.99]));
        if ~isnan(pars.shLimit) && startsWith(name, "sh")
            xlim(pars.shLimit * [-1, 1]);
        elseif ~isnan(pars.ALimit) && startsWith(name, "A")
            xlim(pars.ALimit * [-1, 1]);
        end % if
        xlabel(name, "Interpreter", "none");
        if j == 1, ylabel("Depth (m)"); end
        hold on;
    end % for j;
    hold off;

    sgtitle(sprintf("Profile %d/%d %s to %s [%.2f %.2f]", ...
        i, size(pInfo,1), row.t0, row.t1, trimDepth, bottomDepth));
    linkaxes(vertcat(h{:}), "y");
    if i ~= profiles(end), waitforbuttonpress(); end
end % for i
end % trim_insitu_diagnostic_plots