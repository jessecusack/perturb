# This software suite is designed to process [Rockland Scientific](https://rocklandscientific.com) turbulence devices.

The input data is `.P` files from Rockland device(s).
<br>
The outputs include:
* Trimmed `.P` files when the final buffers are corrupt.
* Combined `.P` files for files what were ended due a file size constraint.
* The output of `odas_p2mat` for each `.P` file.
* For the profiles, either in depth or time:
  - The profiles within each `.P` file.
    * The FP07 sensor data is adjusted in time to match shear probe data using a cross correlation.
    * If a temperature reference exists, such as JAC_T, using all the profiles in this `.P` file:
      - The temperature reference data is shifted in time to match the shear probe data.
      - An in-situ calibration for each FP07 sensor is done against the temperature reference.
    * If a conductivity reference exists, such as JAC_C, it is adjusted in time to match the temperature reference using a cross correlation.
    * If a GPS reference exists, please see [GPS details](GPS.details.md) for how the GPS fix is attached to the profile.
  - Binned profile scalar data, in either depth or time, for each `.P` file.
  - Combined binned scalar data for all the `.P` files.
* For dissipation:
  - Dissipation estimates are calculated for each profile.
  - Binned dissipation estimates, in either depth or time, for all the profiles in a `.P` file.
  - Combinned binned dissipation estimates for all the `.P` files.
* For scalars, such as JAC_T, JAC_C, Chlorophyll, ...:
  - Time binned scalar data for the entire `.P` file, i.e. not just during profiles.
  - If a GPS reference exists, please see [GPS details](GPS.details.md) for how the GPS fix is attached to the profile.
  - Combined time binned scalar data for all the `.P` files.

[VMP250 Quickstart](VMP250.md)
<br>
[MicroRider Quickstart](MicroRider.md)
<br>
[How data flows through the system.](data_flow.md)
<br>
[The data file structure.](data_organization.md)
<br>
[MatLab files variable names and definitions.](matlab_variables.md)
<br>
[NetCDF files variable names and definitions.](netCDF.md)
<br>
[How to execute unit tests.](unit_tests.md)
