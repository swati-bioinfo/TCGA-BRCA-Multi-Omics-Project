options(shiny.error = function() {
  try(writeLines(
    paste(Sys.time(), geterrmessage(), sep = " - "),
    "/srv/shiny-server/www/error_log.txt",
    append = TRUE
  ))
})
