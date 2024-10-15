## SHINYAPP AND DATA COPY TO OSTPRE.UEF.FI
if(TRUE){
  ## Move app files
  fils <- c("shiny_osapred.Rmd", "global.R", "README.md", "README.html")
  for (fil in fils) {
    system(paste0("scp -r ",fil ," janimie@ostpre.uef.fi:/data/shiny-server/osapredict/"))
  }
  ## Image files
  fils <- list.files("img/", full.names = T)
  for (fil in fils) {
    system(paste0("scp -r ",fil ," janimie@ostpre.uef.fi:/data/shiny-server/osapredict/img/"))
  }
  system("ssh janimie@ostpre.uef.fi 'find /data/shiny-server/osapredict/img/* -type f -exec chmod ug=rw,o=r {} \\;'")
  # Copy Data
  fils <- "data/"
  fils <- list.files(fils, full.names = T)
  for (fil in fils) {
    system(paste0("scp -r ",fil ," janimie@ostpre.uef.fi:/data/shiny-server/osapredict/data/"))
  }
  # permisson
  system("ssh janimie@ostpre.uef.fi 'find /data/shiny-server/osapredict/* -type f -exec chmod ug=rw,o=r {} \\;'")
}
