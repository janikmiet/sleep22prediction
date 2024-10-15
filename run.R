

## First Create Basedata for predictions for the Shiny and then you can run the shiny
source("global.R")
create_osapred(WRITE_DATA = TRUE)

## Launch
rmarkdown::run("shiny_osapred.Rmd")

## Deploy shiny app to ostpre.uef.fi
source("deploy.R")


