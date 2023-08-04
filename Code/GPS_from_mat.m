% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_from_mat <GPS_base_class
    methods
        function obj = GPS_from_mat(fn, method)
            arguments
    	        fn string {mustBeFile}
        		method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
                
    	    end % arguments
            %%
            a = load(fn).gps;
            obj = obj@GPS_base_class(a.t, a.lat, a.lon, method);
        end % GPS_from_mat
    end % methods
end % classdef % GPS_from_mat