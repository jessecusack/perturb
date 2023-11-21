% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_from_vectors <GPS_base_class
    properties
	    time
	    latitude
	    longitude
    end % properaties

    methods
        function obj = GPS_from_vectors(time, latitude, longitude, method)
            arguments (Input)
                time (:,1) datetime {mustBeVector}
                latitude (:,1) double {mustBeVector}
                longitude (:,1) double {mustBeVector}
                method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
            end % arguments Input
            arguments (Output)
                obj GPS_from_vectors
            end % arguments Output

            obj = obj@GPS_base_class(method);

            if ~isequal(size(time), size(latitude)) || ~isequal(size(time), size(longitude))
                error("Time, latitude, and longitude must all have the same size!");
            end % if size

	    if ~isdatetime(time)
                error("Time must be a vector of datetime objects, %s.", class(time))
            end % if isdatetime

            obj.time  = time;
            obj.latitude = latitude;
            obj.longitude = longitude;
        end % GPS_from_vectors

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_from_vectors
            end % arguments Input
            arguments (Output)
                obj GPS_from_vectors
            end % arguments Output

            obj = obj.addTimeLatLon(obj.time, obj.latitude, obj.longitude);
        end % initialize
    end % methods
end % classdef % GPS_from_vectors
