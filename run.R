port <- as.integer(Sys.getenv("PORT", "7860"))
options(shiny.trace = TRUE)
cat("DIAG: Starting Shiny app on port", port, "\n")
shiny::runApp("/app", host = "0.0.0.0", port = port, launch.browser = FALSE)
