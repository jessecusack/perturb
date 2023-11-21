# How GPS or dead reckoned fixes are attached to the data.

- For ***VMP*** up and down cast profiles, the fix for the entire profile is the fix at the start of the profile. See [mat2profile.m](../Code/mat2profile.m).
- For ***MR*** on a glider or AUV profiles, the fix is at the time of the observation. See [mat2profile.m](../Code/mat2profile.m).
- For scalar variables, using all the data in a `.P` file, see [ctd2binned.m](../Code/ctd2binned.m):
  *  ***VMP*** downcast a *Tow-Yo* model is built where:
    - On the downcast, the fix is at the start of the profile.
    - On the upcast, the fix is linearly interpolated in time from the end of the cast time to the start of the next profile, starting with the fix from the profile to the fix at the start of the next profile.
  * For ***MR*** the fix corresponding to the time is assigned to the data.
