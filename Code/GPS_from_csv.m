% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_from_csv <GPS_base_class
    properties
        filename
        timeName
        latName
        lonName
    end % properaties

    methods
        function obj = GPS_from_csv(fn, method, timeName, latName, lonName)
            arguments (Input)
                fn string {mustBeFile}
                method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
                timeName string {mustBeNonempty} = "t"
                latName string {mustBeNonempty} = "lat"
                lonName string {mustBeNonempty} = "lon"
            end % arguments Input
            arguments (Output)
                obj GPS_from_csv
            end % arguments Output

            obj = obj@GPS_base_class(method);
            obj.filename = fn;
            obj.timeName = timeName;
            obj.latName = latName;
            obj.lonName = lonName;
        end % GPS_from_csv

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_from_csv
            end % arguments Input
            arguments (Output)
                obj GPS_from_csv
            end % arguments Output

            a = readtable(obj.filename);
            obj = obj.addTimeLatLon(a.(obj.timeName), a.(obj.latName), a.(obj.lonName));
        end % initialize
    end % methods
end % classdef % GPS_from_csv