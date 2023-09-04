# Geo-reference

A Matlab class object supplies latitude, longitude, and the time difference of the nearest valid fix to an input timestamp.

There are multiple versions of derived GPS classes already existing:
- [GPS_NaN](../Code/GPS_NaN.m) Returns NaN for every latitude and longitude
- [GPS_from_csv](../Code/GPS_from_csv.m) Reads from a CSV file
- [GPS_from_mat](../Code/GPS_from_mat.m) Loads a Matlab `.mat` file
- [GPS_from_netCDF](../Code/GPS_from_netCDF.m) Loads a NetCDF file
- [GPS_from_vectors](../Code/GPS_from_vectors.m) Uses user supplied vectors of latitude, longitude, and timestamps.

All the above classes are derived from [GPS_base_class](../Code/GPS_base_class.m).

Example usage is shown in the [Examples](../Examples).

- [GPS_NaN](../Code/GPS_Nan.m) has no input arguments
- [GPS_from_csv](../Code/GPS_from_csv.m)
 - filename of the CSV file. (Required)
 - method interpolation method, see interp1 for allowed methods. (default: linear)
 - timeName column name of timestamps. These must be convertable into datetime objects. (default: t)
 - latName column name of latitudes. (default: lat)
 - lonName column name of longitudes. (default: lon)
- [GPS_from_mat](../Code/GPS_from_mat.m)
 - filename of the CSV file. (Required)
 - variableName name of variable in filename containing timeName, latName, and lonName. If empty, then timeName, latName, and lonName are not in a variable. (default: gps)
 - method interpolation method, see interp1 for allowed methods. (default: linear)
 - timeName column name of timestamps. These must be datetime objects. (default: t)
 - latName column name of latitudes. (default: lat)
 - lonName column name of longitudes. (default: lon)
- [GPS_from_netCDF](../Code/GPS_from_netCDF.m)
 - filename of the CSV file. (Required)
 - method interpolation method, see interp1 for allowed methods. (default: linear)
 - timeName column name of timestamps. These must be datetime objects. (default: t)
 - latName column name of latitudes. (default: lat)
 - lonName column name of longitudes. (default: lon)
- [GPS_from_vectors](../Code/GPS_from_vectors.m)
 - time vector of datetime objects (Required)
 - latitude vector of double latitudes (Required)
 - longitudes vector of double longitudes (Required)
 - method interpolation method, see interp1 for allowed methods. (default: linear)
