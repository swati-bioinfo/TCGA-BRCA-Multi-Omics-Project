FROM rocker/r-ver:4.3.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libxt-dev \
    && rm -rf /var/lib/apt/lists/*

COPY install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R

COPY dashboard_app /srv/shiny-server
COPY run.R /srv/shiny-server/run.R

EXPOSE 7860

CMD ["Rscript", "/srv/shiny-server/run.R"]
