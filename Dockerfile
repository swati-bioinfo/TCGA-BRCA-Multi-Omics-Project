FROM rocker/shiny:4.3.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libxt-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    && rm -rf /var/lib/apt/lists/*

COPY dashboard_app /srv/shiny-server

RUN Rscript -e "options(repos = c(CRAN = 'https://packagemanager.posit.co/cran/__linux__/jammy/latest'), install.packages.check.source = 'no'); source('/srv/shiny-server/packages.R')"

EXPOSE 7860

CMD ["R", "-e", "shiny::runApp('/srv/shiny-server', host='0.0.0.0', port=7860)"]
