options(
  repos = c(CRAN = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"),
  install.packages.check.source = "no"
)

pkgs <- c("bs4Dash", "shinyjs", "plotly", "DT", "survminer", "umap")
for (pkg in pkgs) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
  }
}

if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}
if (!requireNamespace("MultiAssayExperiment", quietly = TRUE)) {
  BiocManager::install("MultiAssayExperiment", update = FALSE, ask = FALSE)
}
