% Class holding the GPS time series for estimating a position
%
% June-2023, Pat Welch, pat@mousebrains.com

classdef GPS_from_mat <GPS_base_class
    properties
        filename
        variableName
        timeName
        latName
        lonName
    end % properaties

    methods
        function obj = GPS_from_mat(fn, variableName, method, timeName, latName, lonName)
            arguments (Input)
                fn string {mustBeFile}
                variableName string {mustBeNonempty} = "gps"
                method string {mustBeMember(method, ["linear", "nearest", "previous", "pchip", "cubic", "v5cubic", "makima", "spline"])} ...
                    = "linear"
                timeName string {mustBeNonempty} = "t"
                latName string {mustBeNonempty} = "lat"
                lonName string {mustBeNonempty} = "lon"
            end % arguments Input
            arguments (Output)
                obj GPS_from_mat
            end % arguments Output

            obj = obj@GPS_base_class(method);
            obj.filename = fn;
            obj.variableName = variableName;
            obj.timeName = timeName;
            obj.latName = latName;
            obj.lonName = lonName;
        end % GPS_from_mat

        function obj = initialize(obj)
            arguments (Input)
                obj GPS_from_mat
            end % arguments Input
            arguments (Output)
                obj GPS_from_mat
            end % arguments Output

            a = load(obj.filename);

            if ~ismissing(obj.variableName)
                a = a.(obj.variableName);
            end % ~ ismissing

            if isstruct(a)
                names = string(fieldnames(a));
            elseif istable(a)
                names = string(a.Properties.VariableNames);
            else
                error("Unknown object, %s, in %s", class(a), obj.filename);
            end

            if ~ismember(obj.timeName, names)
                error("Time variable name, %s, is not in %s", obj.timeName, obj.filename);
            end

            if ~ismember(obj.latName, names)
                error("Latitude variable name, %s, is not in %s", obj.latName, obj.filename);
            end

            if ~ismember(obj.lonName, names)
                error("Longitude variable name, %s, is not in %s", obj.lonName, obj.filename);
            end

            obj = obj.addTimeLatLon(a.(obj.timeName), a.(obj.latName), a.(obj.lonName));
        end % initialize
    end % methods
end % classdef % GPS_from_mat
