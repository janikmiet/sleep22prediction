

## First Create Basedata for predictions for the Shiny and then you can run the shiny
source("./app/global.R")
create_osapred(WRITE_DATA = TRUE)

## Launch to test locally
rmarkdown::run("./app/shiny_osapred.Rmd")

## Deploy shiny app to server side. Check deploy script and add ssh addresses.
# source("deploy.R")


