## SHINYAPP AND DATA COPY TO SERVER
## Uses scp to copy files to server side and ssh connection to generate permission to files
SSH_CONN <- ""  ## ssh username and connection. Ex. user@server.com
APP_DIR <- ""   ## where to upload directory of app in Server side. Ex. /data/shiny-server/osapredict/

if(TRUE){
  URL_DEPLOY <- paste0(SSH_CONN, ":", APP_DIR) ## Generated from SSH_CONN and APP_DIR. user@server.address.fi:/shiny-server-location/appname/
  ## Move app files
  fils <- c("shiny_osapred.Rmd", "global.R", "README.md", "README.html")
  for (fil in fils) {
    system(paste0("scp -r ",fil ," ", URL_DEPLOY))
  }
  ## Image files
  fils <- list.files("img/", full.names = T)
  for (fil in fils) {
    system(paste0("scp -r ",fil ," ", URL_DEPLOY,"img/"))
  }
  # Copy Data
  fils <- "data/"
  fils <- list.files(fils, full.names = T)
  for (fil in fils) {
    system(paste0("scp -r ",fil ," ", URL_DEPLOY,"data/"))
  }
  # Permissions Overwrite (check if needed)
  system(paste0("ssh ", SSH_CONN," 'find ", APP_DIR,"* -type f -exec chmod ug=rw,o=r {} \\;'"))
}
