# packages.R — Required R packages for BRCA Navigator
# Hugging Face Spaces will install these on startup

required_packages <- c(
  "shiny", "bs4Dash", "shinyjs", "plotly", "DT",
  "dplyr", "survival", "survminer", "ggplot2", "umap"
)

for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org", dependencies = TRUE)
  }
}

# Bioconductor package
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}
if (!requireNamespace("MultiAssayExperiment", quietly = TRUE)) {
  BiocManager::install("MultiAssayExperiment")
}
