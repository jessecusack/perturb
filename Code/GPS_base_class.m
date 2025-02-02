%
% Super class for GPS classes
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_base_class
    properties
        tbl
        method
        qFixed
    end % properties

    methods
        function obj = GPS_base_class(method)
            arguments (Input)
                method string ...
                    {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
            end % arguments

            obj.method = method;
            obj.tbl = table();
        end % GPS_common

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_base_class
            end % arguments Input
            arguments (Output)
                obj GPS_base_class
            end % arguments Output

            disp(obj)
            error("No initialization method provided.")
        end % initialize

        function obj = addTimeLatLon(obj, time, latitude, longitude)
            arguments (Input)
                obj GPS_base_class
                time (:,1) datetime {mustBeNonempty}
                latitude (:,1) double {mustBeNonempty}
                longitude (:,1) double {mustBeNonempty}
            end
            arguments (Output)
                obj GPS_base_class
            end

            if ~isdatetime(time)
                error("Time must be a vector of datetime objects, %s", class(time));
            end % if isdatetime

            if ~isequal(size(time), size(latitude)) || ~isequal(size(time), size(longitude))
                error("Time, latitude, and longitude must all have the same size.")
            end % if isdatetime

            [~, ix] = unique(time);
            ix = ix(~isnat(time(ix)));
            
            time.TimeZone = "UTC"; % Convert to UTC
            time.TimeZone = ""; % Drop the timezone for interpolation
            obj.tbl = timetable(time(ix));
            obj.tbl.lat = latitude(ix);
            obj.tbl.lon = longitude(ix);
            obj.tbl = rmmissing(obj.tbl);
            obj.tbl = obj.tbl(~isinf(obj.tbl.lat) & ~isinf(obj.tbl.lon), :);

            obj.qFixed = size(obj.tbl,1) == 1;

        end

        function val = lat(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            if obj.qFixed
                val = obj.tbl.lat + zeros(size(time));
            else
                val = interp1(obj.tbl.Time, obj.tbl.lat, time, obj.method, "extrap");
            end
        end % lat

        function val = lon(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            if obj.qFixed
                val = obj.tbl.lon + zeros(size(time));
            else
                val = interp1(obj.tbl.Time, obj.tbl.lon, time, obj.method, "extrap");
            end
        end % lon

        function val = dt(obj, time)
            arguments (Input)
                obj GPS_base_class
                time datetime
            end % arguments Input
            arguments (Output)
                val double
            end % arguments Output

            if obj.qFixed
                tNearest = time + zeros(size(time));
            else
                tNearest = interp1(obj.tbl.Time, obj.tbl.Time, time, "nearest", "extrap");
            end
            val = abs(seconds(tNearest - time));
        end % dt
    end % methods
end % classdef GPS_base_class
