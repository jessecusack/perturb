% Class holding the GPS time series for estimating a position
%
% This is a fixed location for all time.
%
% Dec-2023, Pat Welch, pat@mousebrains.com

classdef GPS_from_fixed <GPS_base_class
    properties
        latValue
        lonValue
    end % properaties

    methods
        function obj = GPS_from_fixed(lat, lon)
            arguments (Input)
                lat (1,1) double
                lon (1,1) double
            end % arguments Input
            arguments (Output)
                obj GPS_from_fixed
            end % arguments Output

            obj = obj@GPS_base_class("linear");
            obj.latValue = lat;
            obj.lonValue = lon;
        end % GPS_from_fixed

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_from_fixed
            end % arguments Input
            arguments (Output)
                obj GPS_from_fixed
            end % arguments Output

            obj = obj.addTimeLatLon(datetime("now"), obj.latValue, obj.lonValue);
        end % initialize
    end % methods
end % classdef % GPS_from_fixed