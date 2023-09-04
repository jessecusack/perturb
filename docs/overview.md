# This software suite is designed to process [Rockland Scientific](https://rocklandscientific.com) turbulence devices.

The input data is `.P` files from the Rockland device and 
GPS information for where and when the `.P` file was generated.
<br>
The outputs include:
* profiles with
  - A timestamp
  - A [geo-reference](GPS.md)
  - A depth reference
  - Turbulence/dissipation estimates
  - Other instrument sensor information, such as CTD, DO, Chlorophyll, Turbidity
* depth binned combined profiles
* time binned scalar instrument sensor information with a [geo-reference](GPS.md)

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
