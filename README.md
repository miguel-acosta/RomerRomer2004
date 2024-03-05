# Romer & Romer (2004) updates

These files update the monetary policy shock series of Romer & Romer (RR)
(AER, 2004). I primarily use Greenbook data from the Philadelphia
Fed, and have checked/corrected all values that differ between that
dataset and the original RR dataset. I use the RR Fed Funds target
from their replication material when available, then values from FRED
thereafter.


## Details
 The file `getGBdates.py` creates a dataset of the mapping between
 FOMC and Greenbook (now Tealbook) dates by scraping the Fed's
 website and making some manual corrections where applicable.
 It creates `intermediates/GBFOMCmapping.csv`

The file `rrreplication.do` replicates the shocks. It requires
the Romer & Romer replication dataset as input, and saves the
csv file `output/rrshocks.csv`. The variables therein are
1. fomc: the date of the FOMC meeting
2. rr_original: the shocks from the RR replication file
3. rr_update: updated shocks

I am happy to answer any questions, and update this
if more-recent data are available--just send me an email.