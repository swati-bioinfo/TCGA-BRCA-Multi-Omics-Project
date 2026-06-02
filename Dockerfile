FROM rocker/shiny:4.3.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libxt-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dev httpuv for WebSocket reliability
RUN installGithub.r rstudio/httpuv

# Install CRAN packages
RUN install2.r --error --skipinstalled \
    bs4Dash \
    shinyjs \
    plotly \
    DT \
    survminer \
    umap

# Install Bioc packages
RUN Rscript -e "install.packages('BiocManager',repos='https://cloud.r-project.org');BiocManager::install('MultiAssayExperiment',update=FALSE,ask=FALSE)"

COPY dashboard_app /srv/shiny-server
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 7860

CMD ["/usr/bin/shiny-server"]
