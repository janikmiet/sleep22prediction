FROM rocker/r-ver:4.4.1
RUN apt-get update && apt-get install -y \
sudo \
gdebi-core \
pandoc \
pandoc-citeproc \
libcurl4-gnutls-dev \
libcairo2-dev \
libxt-dev \
xtail \
wget

## Install packages needed for running the app
RUN R -e "install.packages(c('rmarkdown', 'duckdb', 'DT', 'ggplot2', 'tidyr', 'arrow', 'RColorBrewer', 'flexdashboard', 'hrbrthemes', 'dplyr', 'paletteer', 'scales', 'ggplot2', 'ggthemes'), repos='https://cloud.r-project.org/')"


# Create the shiny user and group
RUN useradd -r -m shiny && \
    mkdir -p /srv/shiny-server/shiny_osaprediction && \
    chown -R shiny:shiny /srv/shiny-server/shiny_osaprediction
    
## Copy app to image
COPY ./app/ /srv/shiny-server/shiny_osaprediction


EXPOSE 3838
## RUN SHINY APP
CMD ["R", "-e", "rmarkdown::run('/srv/shiny-server/shiny_osaprediction/shiny_osapred.Rmd', shiny_args = list(host = '0.0.0.0', port = 3838))"]
