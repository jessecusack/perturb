# Transform *VMP* `.P` files into binned data

## You will need the ODAS library which can be obtained directly from Rockland

For a simple example to run on your code see [ASTRAL.m](ASTRAL.m)

Hopefully, everything is parameterized and one just needs to call `processVMPfiles` 
with the appropriate [parameters](Parameters.md)

---

The data flow for
[https://rocklandscientific.com/products/profilers/vmp-250/](VMP) `.P` files
is:
- New/updated `.P` files are transformed into .mat files using `odas_p2mat`
- New/updated `.mat` files
  - The file is split into profiles.
  - The cross correlation peak is found between the FP07 and JAC_T thermistors for each profile.
  - The JAC_T and JAC_C are shifted by the weighted median lag found from the cross correlations.
  - A fit with all the profiles FP07 and JAC_T is done.
  - The FP07 temperatures are recomputed using the fit and overwrite the T?_(fast|slow) data.
  - Using all the JAC_T and JAC_C data for all the profiles, a weighted median lag is computed from all the cross correlations.
  - JAC_C is shifted.
  - A GPS fix is assigned to each profile.
  - Seawater properties are computed for each profile.
  - The profiles are saved into a single `.mat` file.
- New/updated profile `.mat` files are binned and saved into binned `.mat` files
- New/updated binned `.mat` files are combined togeter into a `combo.mat` file.
- `combo.mat` is output in *NetCDF* format to `combo.nc`

See [combo description](Combo.md) for information about the contents of `combo.mat`

The `.P` files are located by joining `p_file_root` and `p_file_pattern`
The outputs are saved into a similar structure as the original `.P` files.

The profiles and binned directories have a hash attached to their name which is unique to the input parameters. If you change any parameter, a new directory try will probably be generated.

# TODO:
- Add chi
- Bottom crash detection
- BBL stress
- dissipation combining smarter
- CTD salinity spikes/thermal mass/...
