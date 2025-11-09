##----------------------------------------------------------------------------##
## This code puts together the file GBFOMCmapping.csv.                        ##
##                                                                            ##
## The file, GBFOMCmapping.csv, contains three variables, described           ##
## below. The file is meant to provide a way to merge Greenbook data with     ##
## FOMC meeting data. The primary data source are the Federal Reserve's       ##
## historical pages. Tom Stark provided helpful information                   ##
##                                                                            ##
## Date formats are all YYYYMMDD. So, September 26, 1992 is 19920926.         ##
##                                                                            ##
##    FOMCdate   : The (last) date of each FOMC meeting.                      ##
##                                                                            ##
##    GBpubDate  : The initial date of Greenbook publication.                 ##
##                                                                            ##
##    GBdate     : Date of the Greenbook data used in the Philadelphia        ##
##                 Fed's Greenbook Data Set. This will either be exactly      ##
##                 GBpubDate, or it will be a few days after (this occurs     ##
##                 if updated forecasts were made after the initial           ##
##                 publication). More information on when the differences     ##
##                 arise can be found in the comments of the code             ##
##                 getGBdates.py.                                             ##
##                                                                            ##
## First written by Miguel Acosta in 2015, last updated 3/4/2024              ##
##----------------------------------------------------------------------------##
from bs4 import BeautifulSoup as bs
from urllib.request import urlopen
from urllib.request import Request
from datetime import datetime as dt
from os import system as sys
from time import sleep
import re
import numpy as np
import pandas as pd
hdr = { 'User-Agent' : 'Mozilla/5.0 (Windows NT 6.1; Win64; x64)' }

def getMapping(url):
    pageSourceCode = str(urlopen(Request(url,headers=hdr)).read())
    pdfNames       = re.findall(r'[Ff][oO][mM][cC][0-9]{8}greenbook[0-9]{8}.pdf', pageSourceCode)
    # "New" refers to the fact that after a certain point in time, the
    # greenbook was posted as two parts, so the pdf name is different
    pdfNamesNew    = re.findall(r'[Ff][oO][mM][cC][0-9]{8}gbpt1[0-9]{8}.pdf', pageSourceCode)
    tealbookNames  = re.findall(r'[Ff][oO][mM][cC][0-9]{8}tealbooka[0-9]{8}.pdf', pageSourceCode)
    specialNames   = re.findall(r'[Ff][oO][mM][cC][0-9]{8}gbspecial[0-9]{8}.pdf', pageSourceCode)

    if not pdfNames:
        pdfNames = []
    if not tealbookNames:
        tealbookNames = []
    if not pdfNamesNew:
        pdfNamesNew = []
    if not specialNames:
        specialNames = []
    pdfNames.extend(pdfNamesNew)
    pdfNames.extend(tealbookNames)
    pdfNames.extend(specialNames)

    GBdates = []
    FOMCdates = []
    for p in pdfNames:
        FOMCdate = re.findall(r'[Ff][oO][mM][cC][0-9]{8}',p)[0][4:]
        GBdate = re.findall(r'[0-9]{8}.pdf',p)[0][:-4]
        FOMCdates.append(FOMCdate)
        GBdates.append(GBdate)
    return FOMCdates, GBdates



## Figure out which years are posted on the Fed's website
url = 'https://www.federalreserve.gov/monetarypolicy/fomc_historical_year.htm'
historical_page = urlopen(Request(url,headers=hdr)).read()
years = [int(mm) for mm in set(re.findall(r'fomchistorical([0-9]{4})\.htm',str(historical_page)))]

mapping = [[],[]]
for y in range(1967,max(years)+1):
    url = 'https://www.federalreserve.gov/monetarypolicy/fomchistorical' + str(y) + '.htm'
    sleep(1)
    print(y)
    mapping_y = getMapping(url)
    mapping[0].extend(mapping_y[0])
    mapping[1].extend(mapping_y[1])


# Create a dataframe to store the data--index if by the Greenbook publication date
mappingNP = pd.DataFrame(zip(*[mapping[0],mapping[1]]),index=mapping[1],columns=['FOMCdate','GBdate'])

# Manually enter entries in which the original Greenbook publication date
# is not the same as the GBdate from the Philadephia Fed's Greenbook Dataset.
# For all but the following three cases, these entries can be confirmed in
# the Philadelphia Fed's PDF dataset.
#   (1) The 02/06/1968 meeting has two entries in the Philadelphia Fed's
#       Greenbook dataset: one from 02/06/1968, and another from 01/31/1968.
#       The first entry is in the Philadelphia Fed's internal PDF files, and
#       since it has more forecasted periods, we use it here.
#   (2) The 06/18/1973 meeting data also comes from an internal record.
#   (3) The 04/15/1977 meeting data also comes from an internal record.
mappingNP.loc['19680131','GBdate'] = 19680206 # (1)
mappingNP.loc['19670712','GBdate'] = 19670717
mappingNP.loc['19680905','GBdate'] = 19680904
mappingNP.loc['19701110','GBdate'] = 19701111
mappingNP.loc['19710818','GBdate'] = 19710820
mappingNP.loc['19730613','GBdate'] = 19730618 # (2)
mappingNP.loc['19770413','GBdate'] = 19770415 # (3)
mappingNP.loc['19800312','GBdate'] = 19800314
mappingNP.loc['19910626','GBdate'] = 19910628
mappingNP.loc['19920624','GBdate'] = 19920626
mappingNP.loc['19930127','GBdate'] = 19930129
mappingNP.loc['19940128','GBdate'] = 19940131
mappingNP.loc['19940317','GBdate'] = 19940316
mappingNP.loc['19940629','GBdate'] = 19940630

# Fix one instance of the wrong FOMC meeting date being labeled by its first day.
mappingNP.loc['19721115','FOMCdate'] = 19721121

# Fixing a bug caught by Paul Bousquet (thank you!)
mappingNP.loc['20100422','GBdate'] = 20100421

# Add a variable
mappingNP['GBpubDate'] = mappingNP.index


# Print to csv
mappingNP.to_csv(path_or_buf = 'intermediates/GBFOMCmapping.csv',sep=',',index=False)
