# Combining binned data is handled by:
- [glue_widthwise](../Code/glue_widthwise.m)
- [glude-lengthwise](../Code/glue_lengthwise.m)

The glue functions are called by:
- [ctd2combo](../Code/ctd2combo.m)
- [profiles2combo](../Code/profiles2combo.m)
- [diss2combo](../Code/diss2combo.m)

The `combo.mat` files are structures with at least two tables:
- ***info*** table is information for each profile or input file
- ***tbl*** table is the combined binned data.

The ***info*** tables will contain some combination of the following columns:
- *name* is the input `.P` filename minus the *p_file_root* portion of the path and the `.P` filename suffix.
- *t0* is the start time of the profile
- *t1* is the end time of the profile
- *lat* is the latitude at *t0* in decimal degrees north
- *lon* is the longitude at *t0* in decimal degrees east
- *dtGPS* is the time between the actual GPS fix and *t0* in seconds
- *minDepth* is the minimum depth of the profile in decibars
- *maxDepth* is the maximum depth of the profile in decibars
- *trimDepth* is the depth the top trimming algorithm found in decibars
- *trimMaxDepth* is the maximum depth of all the estimates for this profile in decibars
- *bottomDepth* is the estimated depth from bottom crashing in decibars, or *maxDepth* + 1 if `bbl_use` is not enabled.
- *nSlow* is the number of slow entries in the profile
- *nFast* is the number of fast entries in the profile

For depth bining, all the columns in *tbl*, except for *bin* are n casts. *bin* is the depth binned.

For time binning, all the columns in *tbl* are vectors. *bin* is the time bin.

*tbl* will contain some combination of the following columns:
- *bin* depth bin centroid in meters or time as a [Matlab datetime](https://www.mathworks.com/help/matlab/ref/datetime.html).
- *t* time at each bin
- *P* pressure/depth in each bin (decibars)
- *JAC_T* calibrated temperature in each bin
- *JAC_C* calibrated conductivity in each bin
- *JAC_SP* practical salinity from JAC_T and JAC_C in each (From [GSW](https://www.teos-10.org/pubs/gsw/html/gsw_contents.html))
- *JAC_SA* absolute salinity from JAC_T and JAC_C in each bin (From [GSW](https://www.teos-10.org/pubs/gsw/html/gsw_contents.html))
- *JAC_sigma* sigma from JAC_T and JAC_C in each bin (From [GSW](https://www.teos-10.org/pubs/gsw/html/gsw_contents.html)GSW)
- *JAC_theta* theta from JAC_T and JAC_C in each bin (From [GSW](https://www.teos-10.org/pubs/gsw/html/gsw_contents.html))
- *JAC_rho* density from JAC_T and JAC_C in each bin, (kg/m^3 - 1000) (From [GSW](https://www.teos-10.org/pubs/gsw/html/gsw_contents.html))
- *DO* disolved oxygen in each bin, if any of the VMPs are equipped with a DO sensor.
- *Chlorophyll* chlorophyll in each bin, if any of the VMPs are equipped with a fluorometer.
- *Turbidity* trubidity in each bin, if any of the VMPs are equipped with a fluorometer.
- *T1_slow*, *T2_slow*, *T1_fast*, and *T2_fast* temperature from FP07 sensors. If `fp07_calibrate` is enabled, these are from the FP07 calibration process.
- *e_1* and *e_2* is a top down dissipation estimate in each bin.
- 
To make a plot of the dissipation using `pcolor` one can do:

`a = load("diss_combo_0000/combo.mat");`
`pcolor(a.info.t0, a.tbl.bin, log10(a.tbl.epsilonMean));`
