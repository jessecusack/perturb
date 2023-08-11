%
% Super class for GPS classes
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_base_class
    properties
        tbl
        method
    end % properties

    methods
        function obj = GPS_base_class(time, latitude, longitude, method)
            arguments (Input)
                time (:,1) datetime {mustBeNonempty}
                latitude (:,1) double {mustBeNonempty}
                longitude (:,1) double {mustBeNonempty}
                method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
            end % arguments
            [time, ix] = unique(time);
            time.TimeZone = "UTC"; % Convert to UTC
            time.TimeZone = ""; % Drop the timezone for interpolation
            tbl = timetable(time);
            tbl.lat = latitude(ix);
            tbl.lon = longitude(ix);
            obj.tbl = tbl;
            obj.method = method;
        end % GPS_common

        function val = lat(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            val = interp1(obj.tbl.time, obj.tbl.lat, time, obj.method, "extrap");
        end % lat

        function val = lon(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            val = interp1(obj.tbl.time, obj.tbl.lon, time, obj.method, "extrap");
        end % lon

        function val = dt(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            tNearest = interp1(obj.tbl.time, obj.tbl.time, time, "nearest", "extrap");
            val = abs(seconds(tNearest - time));
        end % dt
    end % methods
end % classdef GPS_base_class