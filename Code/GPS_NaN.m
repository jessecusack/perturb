% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_NaN <GPS_base_class
    methods
        function obj = GPS_NaN()
            arguments (Output)
                obj GPS_NaN
            end % arguments Output

            obj = obj@GPS_base_class("linear");
        end % GPS_NaN

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_NaN
            end % arguments Input
            arguments (Output)
                obj GPS_NaN
            end % arguments Output

            now = datetime();
            t = now + [years(-100), years(100)];
            obj = obj.addTimeLatLon(t, nan(size(t)), nan(size(t)));
        end % GPS_NaN
    end % methods
end % classdef % GPS_NaN