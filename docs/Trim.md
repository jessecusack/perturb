Dynamically find the depth where valid disspation estimates can start being computed.

See [trim_profiles](trim_profiles.m) for the code.

The algorithm does the following for each profile:
- Compute the depth binned variance for Ax, Ay, sh1, sh2, W_fast, Incl_Y, and Incl_X.
- Find the shallowest depth bin where the variance is below a threshold for each variable.
- Estimate the trim depth as the quantile of the variables.
