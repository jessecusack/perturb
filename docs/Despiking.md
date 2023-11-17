# The despike parameters are used when calculating dissipation

See [calc_diss_shear](../Code/calc_diss_shear.m) for the code that uses these parameters.

The *despike_sh_*  are used for the shear probes, *sh1* and *sh2*.

The *despike_A_*  are used for the acceleration sensors, *Ax* and *Ay*.

See the *ODAS documentation* detailed descriptions of the despike parameters.

- *thres* Threshold value for the ratio of the instantaneous rectified signal to its smoothed version.
- *smooth* The cut-ff frequency of the first-order Butterworth filter that is used to smooth the rectified input signal.
- *N_FS* Multiplied by sampling frequency and is the spike removal scale.
