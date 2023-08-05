# perturb - a microstructure processing toolbox for Rockland Scientific instruments

***Required external softwware:***
- [Matlab](https://www.mathworks.com/products/matlab.html) (Tested with R2023a)
- [ODAS Library](https://rocklandscientific.com/support/tools/software-versions) (Tested with ODAS-4.5.1)

[VMP250 Quickstart](docs/VMP250.md)
<br>
[MicroRider Quickstart](docs/MicroRider.md)
<br>
[Overview of the system.](docs/overview.md)
<br>
[How data flows through the system.](docs/data_flow.md)
<br>
[The data file structure.](docs/data_organization.md)
<br>
[MatLab files variable names and definitions.](docs/matlab_variables.md)
<br>
[NetCDF files variable names and definitions.](docs/netCDF.md)
<br>
[How to execute unit tests.](docs/unit_tests.md)

## Authors
* Jesse Cusack, [Oregon State University](https://ceoas.oregonstate.edu)
* Fucent Wei, [Oregon State University](https://ceoas.oregonstate.edu)
* Pat Welch, [Oregon State University](https://ceoas.oregonstate.edu)

### References:
- [Rockland Scientific](https://rocklandscientific.com)
- [ATOMIX Shear Probe Wiki](https://wiki.app.uib.no/atomix/index.php?title=Shear_probes)

# TODO:
- Add chi
- Bottom crash detection
- BBL stress
- CTD salinity spikes/thermal mass/...
- documentation within the code
- camel cast to snake case
- unit tests
- invalid GPS
