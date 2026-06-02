FROM rocker/shiny:4.3.2

RUN apt-get update && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libfontconfig1-dev \
    libcairo2-dev \
    libxt-dev \
    && rm -rf /var/lib/apt/lists/*

# Install dev httpuv for WebSocket reliability
RUN install2.r --error --skipinstalled remotes && installGithub.r rstudio/httpuv

# Install CRAN packages (no --skipinstalled: force-consistency with pre-installed pkgs)
RUN install2.r --error \
    shiny \
    bs4Dash \
    shinyjs \
    plotly \
    DT \
    survminer \
    umap \
    dplyr \
    survival \
    ggplot2

# Verify all packages load correctly
RUN Rscript -e "for(pkg in c('shiny','bs4Dash','shinyjs','plotly','DT','dplyr','survival','survminer','ggplot2','umap')) { cat('Loading',pkg,'...'); suppressPackageStartupMessages(library(pkg,character.only=TRUE)); cat('OK\n') }" && echo "All packages loaded successfully"

# Install Bioc packages
RUN Rscript -e "install.packages('BiocManager',repos='https://cloud.r-project.org');BiocManager::install('MultiAssayExperiment',update=FALSE,ask=FALSE)"

COPY dashboard_app /srv/shiny-server
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

RUN chown -R shiny:shiny /srv/shiny-server

# Simulate Shiny Server sourcing app.R (errors in top-level code will fail build)
RUN Rscript -e "\
  options(warn=2); \
  tryCatch({ \
    source('/srv/shiny-server/app.R', local=TRUE); \
    cat('=== APP SOURCED SUCCESSFULLY ===\n'); \
    obj <- try(shinyApp(ui, server)); \
    cat('shinyApp class:', paste(class(obj), collapse=', '), '\n'); \
  }, error = function(e) { \
    cat('!!! SOURCE ERROR:', conditionMessage(e), '\n'); \
    q(status=1, save='no'); \
  })"

# Verify data files load correctly
RUN Rscript -e "\
  data_dir <- '/srv/shiny-server/data'; \
  files <- c('patient_data.csv','cox_os.csv','cox_adjusted_clinical_os.csv',\
             'factor_variance_summary.csv','rmst_per_factor.csv',\
             'top_features_per_factor.csv','factor_descriptions.csv',\
             'reference_km.csv','baseline_survival.csv','cox_multi.rds'); \
  for(f in files) { \
    path <- file.path(data_dir, f); \
    if(grepl('\\\\.rds$', f)) { \
      x <- try(readRDS(path), silent=TRUE); \
    } else { \
      x <- try(read.csv(path), silent=TRUE); \
    }; \
    if(inherits(x, 'try-error')) { \
      cat('FAIL:', f, '-', attr(x,'condition')$message, '\n'); \
      q(status=1); \
    } else { \
      cat('OK:', f, '-', nrow(x), 'rows\n'); \
    } \
  }; \
  cat('All data files loaded\n')"

EXPOSE 7860

RUN Rscript -e "sink('/srv/shiny-server/www/build_info.txt'); cat('BUILD TIME:', date(), '\n'); cat('R version:', R.version.string, '\n'); cat('Packages:\n'); for(pkg in c('shiny','bs4Dash','shinyjs','plotly','DT','dplyr','survival','survminer','ggplot2','umap')) cat(' ', pkg, '-', as.character(packageVersion(pkg)), '\n'); sink()"

CMD ["/usr/bin/shiny-server"]
