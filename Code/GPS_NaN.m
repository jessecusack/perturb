% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_NaN <GPS_base_class
    methods
        function obj = GPS_NaN(method)
            arguments
                method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
            end % arguments
            %%
            now = datetime();
            t = now + [years(-100), years(100)];
    	    obj = obj@GPS_base_class(t, nan(size(t)), nan(size(t)), method)
        end % GPS_NaN
    end % methods
end % classdef % GPS_NaN
