% Detect when VMP crashes into the bottom.
%
% Find the point of maximum deacceleration below a minimum depth.
% Then to use the Ax/Ay vibration sensors to find the initial contact point.
%
% This was tested on 20k+ bottom crash casts in the Gulf of Mexico as part of the SUNRISE project.
% The bottom of the Gulf of Mexico where SUNRISE happened, off Lousiana is fairly soft and silty, so
% the VMP contacts the bottom, then deaccelerates over the next ~0.4m.
%
% Nov-2023, Pat Welch, pat@mousebrains.com

function [pInfo, profile] = bottom_crash_profile(iProfile, pInfo, profile, pars)
arguments (Input)
    iProfile uint32   % Profile number for diagnostic messages
    pInfo (1,:) table % information for this profile
    profile struct    % Profile information
    pars struct       % get_info are the defaults
end % arguments Input
arguments (Output)
    pInfo table    % Input pInfo, possibly with bottom depth information
    profile struct % Input profile, possibly with elevation added
end % arguments Output

if ~pars.bottom_calculate, return; end % Don't calculate anything

% For early returns
profile.fast.elevation = nan(size(profile.fast.depth));
profile.slow.elevation = nan(size(profile.slow.depth));
pInfo.bottom_depth = nan;

if pInfo.max_depth < pars.bottom_depth_minimum % Too shallow to try and find the bottom
    fprintf("%s: profile %d maximum depth, %f, less than depth minimum, %f\n", ...
        pInfo.name, iProfile, pInfo.max_depth, pars.bottom_depth_minimum);
    return;
end % maxDepth

fast = profile.fast; % Fast variables finding the bottom contact
fs = profile.fs_fast;
depth = fast.depth;

% When the bottom is encountered, the VMP will slow to zero very rapidly.
% Find the maximum deacceleration, ~4m/s^2 in the Gulf of Mexico.
% A sanity check is done by making sure the velocity goes close to zero below the maximum.

dzdt = diff(depth) * fs;                  % Vertical velocity (m/s)
P1 = (depth(1:end-1) + depth(2:end)) / 2; % Depth of velocity cell (m)

dz2dt2 = diff(dzdt) .* fs;          % Vertical acceleration (m/s^2)
P2 = (P1(1:end-1) + P1(2:end)) / 2; % Depth of acceleration cell (m)

q = P2 > pars.bottom_depth_minimum; % Only look below this depth

[~, iMin] = min(dz2dt2(q)); % Index of maximum deacceleration below depth min

iOffset = find(~q, 1, "last"); % Find index of last bin above depth minimum
if ~isempty(iOffset), iMin = iMin + iOffset; end % Add back in index above depth minimum

if min(dzdt(iMin:end), [], "omitnan") > median(dzdt(1:iMin), "omitnan") * pars.bottom_speed_factor
    fprintf("%s(%d): Bottom deacceleration not detected, %f, %f, %f\n", ...
        pInfo.name, iProfile, median(dzdt(1:iMin), "omitnan"), pars.bottom_speed_factor, ...
        min(dzdt(iMin:end), [], "omitnan"));
    return;
end % if min

dz2dt2 = dz2dt2(1:iMin); % Acceleration above maximum deacceleration
P2 = P2(1:iMin); % Depth above maximum deacceleration

q = P2 >= (P2(iMin) - pars.bottom_depth_window); % Depth window to look at acceleration within
dz2dt2 = dz2dt2(q); % From maximum deacceleration upwards for a depth window
P2 = P2(q);

aMedian = median(dz2dt2, "omitnan"); % Median acceleration in depth window, should converge to zero
aSigma = std(dz2dt2, "omitnan");
iMedian = find(dz2dt2 >= (aMedian - aSigma * pars.bottom_median_factor), 1, "last");

aSigma = std(dz2dt2(1:iMedian), "omitnan"); % Standard deviation

iBottom = find(dz2dt2 >= (aMedian - aSigma), 1, "last"); % Proposed bottom
bottomDepth = P2(iBottom); % The bottom is no deeper than this value

% Look at vibration sensors, Ax and Ay, and find when they are settled.
% The vibration sensors respond faster than the pressure sensor.
% For soft bottoms they can give us a better estimate of when the VMP starts to enter the muck.

sigmaAx = movstd(fast.Ax, ceil(fs / pars.bottom_vibration_frequency), "omitnan");
sigmaAy = movstd(fast.Ay, ceil(fs / pars.bottom_vibration_frequency), "omitnan");
depthA = fast.depth; % Depth of each A[xy] cell

q = (depthA <= bottomDepth) & (depthA >= (bottomDepth - pars.bottom_depth_window));
if ~any(q), return; end

sigmaAx = sigmaAx(q);
sigmaAy = sigmaAy(q);
depthA = depthA(q);

sigmaAxLimit = median(sigmaAx, "omitnan") * pars.bottom_vibration_factor;
sigmaAyLimit = median(sigmaAy, "omitnan") * pars.bottom_vibration_factor;

q = sigmaAx < sigmaAxLimit & sigmaAy < sigmaAyLimit;
iBottom = find(q, 1, "last"); % Deepest point where both vibration sensors are not blown out
bottomDepth = depthA(iBottom);

pInfo.bottom_depth = bottomDepth;
profile.fast.elevation = bottomDepth - profile.fast.depth;
profile.slow.elevation = bottomDepth - profile.slow.depth;
end % bottom_crash_profile
