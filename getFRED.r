getFRED <- function(seriesname) {
    url <- paste0('https://research.stlouisfed.org/fred2/data/', seriesname, '.txt')
    fname <- paste0(seriesname,'.txt')
    if (!file.exists(fname)) {
        ## Download the data from FRED
        download.file(url, destfile = fname, method = "wget")
    }
    FREDraw <- readLines(fname)

    # Where does the data start
    datastart = which(gsub(' ', '',FREDraw)=='DATEVALUE') - 2

    data <- read.table(fname, skip = datastart, header = TRUE)
    data$DATE <- as.numeric(format(as.Date(data$DATE), format='%Y%m%d'))

    return(data)
}    
