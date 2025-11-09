/******************************************************************************/
/* Code to replicate and update Romer and Romer (2004) shocks                 */
/*                                                                            */
/* By: Miguel Acosta                                                          */
/******************************************************************************/

/******************************************************************************/ 
/* Preliminaries                                                              */ 
/******************************************************************************/ 
/* Update Fed-Funds target from FRED again? */ 
local reloadFFR 0

/******************************************************************************/
/* Read in Romer & Romer replication material                                 */
/******************************************************************************/
import excel using inputs/RomerandRomerDataAppendix.xls, /*
  */   first clear sheet("DATA BY MEETING")

/* Clean up dates */ 
tostring MTGDATE, replace
replace MTGDATE = "0" + MTGDATE if strlen(MTGDATE)==5
gen fomc = date(MTGDATE,"MD19Y")
replace fomc = mdy(2,11,1987) if fomc == mdy(2,12,1987)

/* Convert to numeric */ 
foreach vv of varlist RESID* GR* IG* {
    destring `vv', replace force 
}


/* Save for later */
tempfile RR
save `RR', replace 

/******************************************************************************/
/* Load FFR from FRED if desired                                              */
/******************************************************************************/
if `reloadFFR' {
    run set_fred_key.do /* a simple do file to set your fred key */ 
    import fred DFEDTARU DFEDTAR DFEDTARL, clear

    /* Thanks to Hyeonseo Lee for pointing out new timing of DEFEDTARU       */ 
    /* and DFEDTARL: no change until the day after the FOMC starting in 2017 */
    sort daten
    gen FDFEDTARL = DFEDTARL[_n+1]
    gen FDFEDTARU = DFEDTARU[_n+1]

    /* Use target when available, and midpoint of range thereafter */ 
    gen FFR = DFEDTAR
    replace FFR = (FDFEDTARU + FDFEDTARL)/2 if missing(FFR) & year(daten)>=2017
    replace FFR = ( DFEDTARU +  DFEDTARL)/2 if missing(FFR) & year(daten)< 2017

    /* These are all daily series, but not available every day */
    sort daten    
    gen LFFR = FFR[_n-1]
    gen DFFR = FFR - LFFR
    rename daten fomc

    keep fomc FFR DFFR LFFR
    save intermediates/FFRfred.dta, replace
}


/******************************************************************************/
/* Load Philadelphia Fed Greenbook dataset                                    */
/******************************************************************************/
/* Created in getGBdates.py*/ 
import delimited using intermediates/GBFOMCmapping.csv, /*
  */   stringcols(_all) clear case(preserve)

gen fomc   = date(FOMCdate,"YMD")

/* Merge on each sheet */ 
foreach sheet in gRGDP gPGDP UNEMP {
    preserve 
    import excel intermediates/gbweb_row_format.xlsx, clear first sheet(`sheet')
    cap tostring GBdate, replace 
    tempfile temp
    save `temp', replace
    restore
    merge 1:1 GBdate using `temp', keep(match master) nogen 
}

gen gb = date(GBdate,"YMD")

/* Will need this for determining forecast horizon */ 
gen gbYQ   = yq(year(gb),quarter(gb))

/* A few discrepancies between RR and Philly Fed                             */
/* (not correcting Philly Fed 1977 April values -- those seem to be updates) */
/* Most of these have subsequently been replaced by Philly Fed after some    */
/* correpondence                                                             */ 
replace gRGDPF2 = 0.1 if gb == mdy(12,10,1969)
replace gPGDPB1 = 3.7 if gb == mdy( 5,12,1976)
replace gRGDPB1 = 2.2 if gb == mdy( 7, 1,1987)
replace gRGDPB2 = 4.8 if gb == mdy( 7, 1,1987)
replace gRGDPB1 = 4.6 if gb == mdy( 3,22,1995)


/******************************************************************************/
/* Merge datasets                                                             */
/******************************************************************************/
/* Merge in FF target */
merge 1:1 fomc using intermediates/FFRfred.dta, keep(match master) nogen 

/* Merge in Romer & Romer data  */
merge 1:1 fomc using `RR', gen(merge_rr)

/* A couple of additions that Romer & Romer have but I cannot find in the */ 
/* original  Greenbooks -- the GBs on the Fed's website don't forecast    */
/* this far in the future                                                 */ 
replace gRGDPF2 = GRAY2 if gb == mdy(1,29,1969)
replace gPGDPF2 = GRAD2 if gb == mdy(1,29,1969)
replace gPGDPF3 = 3.5   if gb == mdy(6,18,1969)
replace gRGDPF3 = -0.1  if gb == mdy(6,18,1969)

/* Use Romer & Romer target FFR values when available */ 
replace FFR = OLDTARG + DTARG if !missing(OLDTARG)
replace DFFR = DTARG if !missing(DTARG)
replace LFFR = OLDTARG if !missing(OLDTARG)


/******************************************************************************/
/* Just to make sure that I am computing forecast revisions correctly,        */
/* replace Philly Fed forecasts in *levels* with R&R forecasts in levels,     */
/* then take differences.                                                     */
/******************************************************************************/
drop if fomc == mdy(10,6,1979)
sort fomc


/* Back-casts */ 
gen     gRGDPB1RR = gRGDPB1
replace gRGDPB1RR = GRAYM if !missing(GRAYM)

gen     gPGDPB1RR = gPGDPB1
replace gPGDPB1RR = GRADM if !missing(GRADM)

/* Forecasts */ 
foreach h in 0 1 2 { 
    gen     gRGDPF`h'RR = gRGDPF`h'
    replace gRGDPF`h'RR = GRAY`h' if !missing(GRAY`h')

    gen     gPGDPF`h'RR = gPGDPF`h'
    replace gPGDPF`h'RR = GRAD`h' if !missing(GRAD`h')
}
/* Don't have 3-quarter-ahead  from Romer and Romer  */ 
gen gRGDPF3RR = gRGDPF3
gen gPGDPF3RR = gPGDPF3

/* Unemployment rate is in levels */ 
gen UNEMPF0RR = UNEMPF0
replace UNEMPF0RR = GRAU0 if !missing(GRAU0)

/******************************************************************************/
/* create forecast revisions                                                  */
/******************************************************************************/
/* "suff" is either Philly Fed ("") or Philly-fed replaced with RR when*/
/* possible                                                            */
foreach suff in "" RR {
    /* P = inflation, R = GDP */ 
    foreach vv in P R {
        /* back-cast */ 
        gen     Dg`vv'GDPB1`suff' = g`vv'GDPB1`suff' - g`vv'GDPB1`suff'[_n-1] /*
        */      if gbYQ == gbYQ[_n-1]
        replace Dg`vv'GDPB1`suff' = g`vv'GDPB1`suff' - g`vv'GDPF0`suff'[_n-1] /*
        */      if gbYQ >  gbYQ[_n-1]

        /* forecast */ 
        foreach hh in 0 1 2 {
            local hh1 = `hh' + 1
            gen      Dg`vv'GDPF`hh'`suff' = /*
            */       g`vv'GDPF`hh'`suff' - g`vv'GDPF`hh'`suff'[_n-1]  /* 
            */       if gbYQ == gbYQ[_n-1]
            replace  Dg`vv'GDPF`hh'`suff' = /*
            */       g`vv'GDPF`hh'`suff' - g`vv'GDPF`hh1'`suff'[_n-1] /*
            */       if gbYQ >  gbYQ[_n-1]
        }
    }
}
    
/******************************************************************************/ 
/* Create residuals                                                           */ 
/******************************************************************************/ 
/* Exact replication */ 
reg  DFFR LFFR GRADM GRAD0 GRAD1 GRAD2 IGRDM IGRD0 IGRD1 IGRD2 GRAYM /*
  */ GRAY0 GRAY1 GRAY2 IGRYM IGRY0 IGRY1 IGRY2 GRAU0 if !missing(RESID)
predict shock_rep_exact if !missing(RESID), resid

/* Using reconstructed variables -- slight differences because I */ 
/* don't have 3-quarter-ahead RR variables                       */ 
reg  DFFR LFFR gRGDPB1RR gRGDPF0RR gRGDPF1RR gRGDPF2RR DgRGDPB1RR DgRGDPF0RR /*
  */ DgRGDPF1RR DgRGDPF2RR gPGDPB1RR gPGDPF0RR gPGDPF1RR gPGDPF2RR /*
  */ DgPGDPB1RR DgPGDPF0RR DgPGDPF1RR DgPGDPF2RR UNEMPF0RR if !missing(RESID)
predict shock_rep if !missing(RESID), resid


/* Using Philly-Fed values */ 
reg DFFR LFFR gRGDPB1 gRGDPF0 gRGDPF1 gRGDPF2 DgRGDPB1 DgRGDPF0 DgRGDPF1 /*
  */ DgRGDPF2 gPGDPB1 gPGDPF0 gPGDPF1 gPGDPF2 DgPGDPB1 DgPGDPF0 DgPGDPF1 /*
  */ DgPGDPF2 UNEMPF0 if merge_rr == 3
predict shock_repsamp, resid


/* Using Philly-Fed all the way through */ 
reg DFFR LFFR gRGDPB1 gRGDPF0 gRGDPF1 gRGDPF2 DgRGDPB1 DgRGDPF0 DgRGDPF1 /*
  */ DgRGDPF2 gPGDPB1 gPGDPF0 gPGDPF1 gPGDPF2 DgPGDPB1 DgPGDPF0 DgPGDPF1 /*
  */ DgPGDPF2 UNEMPF0 
predict shock_update, resid

/* Look at correlations */ 
cor shock_* RESID

/******************************************************************************/
/* Save output                                                                */
/******************************************************************************/ 
rename (RESID shock_update) (rr_original rr_update)
format fomc %tdCY-N-D
outsheet fomc DFFR rr_original rr_update using output/rrshocks.csv, replace  comma
