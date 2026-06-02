FROM rocker/r-ver:4.3.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libxt-dev \
    && rm -rf /var/lib/apt/lists/*

# Dev httpuv fixes WebSocket timeout on Hugging Face Spaces (runApp mode)
RUN Rscript -e "install.packages('remotes', repos = 'https://cloud.r-project.org')" \
    && Rscript -e "remotes::install_github('rstudio/httpuv', upgrade = 'never')"

COPY install_packages.R /tmp/install_packages.R
RUN Rscript /tmp/install_packages.R

RUN mkdir /app
COPY dashboard_app /app
COPY run.R /app/run.R

EXPOSE 7860

CMD ["Rscript", "/app/run.R"]
