

## First Create Basedata for predictions for the Shiny and then you can run the shiny
source("global.R")
create_osapred(WRITE_DATA = TRUE)

## Launch to test locally
rmarkdown::run("shiny_osapred.Rmd")

## Deploy shiny app to server side. Check deploy script and add ssh addresses.
# source("deploy.R")


