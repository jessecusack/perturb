# Description of `combo.mat`

`combo.mat` is the binned output of processVMPfiles and contains the information
for all the profiles.

It consists of two variables:
- *info* is a table with one row per profile
- *tbl* is a table with one row per depth bin

*info* columns of interest:
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

Except for the *bin* column, all columns in *tbl* are the number of casts wide by the number of depth bins tall.

*tbl* columns of interest:
- *bin* depbth bin centroid in decibars
- *t* time at each depth bin
- *P* pressure/depth in each depth bin (decibars)
- *JAC_T* calibrated temperature in each depth bin
- *JAC_C* calibrated conductivity in each depth bin
- *JAC_SP* practical salinity from JAC_T and JAC_C in each depth bin (From GSW)
- *JAC_SA* absolute salinity from JAC_T and JAC_C in each depth bin (From GSW)
- *JAC_sigma* sigma from JAC_T and JAC_C in each depth bin (From GSW)
- *JAC_theta* theta from JAC_T and JAC_C in each depth bin (From GSW)
- *JAC_rho* density from JAC_T and JAC_C in each depth bin, (kg/m^3 - 1000) (From GSW)
- *DO* disolved oxygen in each depth bin, if any of the VMPs are equipped with a DO sensor.
- *Chlorophyll* chlorophyll in each depth bin, if any of the VMPs are equipped with a fluorometer.
- *Turbidity* trubidity in each depth bin, if any of the VMPs are equipped with a fluorometer.
- *T1_slow*, *T2_slow*, *T1_fast*, and *T2_fast* temperature from FP07 sensors. If `fp07_calibrate` is enabled, these are from the FP07 calibration process.
- *e* is a top down dissipation estimate in each depth bin
- *e_bbl* is a bottom up dissipation estimate in each depth bin
- *e* is the dissipation estimate using a top down FFT in each depth bin

To make a plot of the top down dissipation using `pcolor` one can do:

`a = load("combo.mat");`
`pcolor(a.info.t0, a.tbl.bin, log10(a.tbl.e));`
