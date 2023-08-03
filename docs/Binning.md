# Bin the samples by depth bins.

See [binData](binData.m) for the code that uses these parameters.

The depth bins are integral multiples of *bin_method* and are the centroid of the bin.

*bin_method* specifies the method of aggregating data within a bin.

**Dissipations** 

Are assumed to be log normal, and the aggregation is done in log space, then unwound to linear space.

Aggregation across shear probes is also done in log space. For each fast sample, the mean of all the log dissipation estimates is found. If any of the log dissipation estimates are within log(*bin_dissRatio*)/2, then the *bin_method* is applied to them. Otherwise the minimum is taken.


