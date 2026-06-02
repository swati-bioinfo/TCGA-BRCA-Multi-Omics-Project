
# ====================================================================
# BRCA Omics Story — Interactive Dashboard
# Combines: Scrollytelling + Mind Map + Factor Explorer + Simulator
# 
# HOW TO RUN:
#   1. Run data_prep.R first (one time)
#   2. Open this file in RStudio
#   3. Click "Run App" (or run: shiny::runApp())
# ====================================================================

# ---- 0. PACKAGES ----
# Install any missing with: install.packages(c("shiny","bs4Dash","shinyjs","plotly","DT","dplyr","survival","survminer","ggplot2"))
cat("DIAG: sourcing app.R\n")
library(shiny)
library(bs4Dash)
library(shinyjs)
library(plotly)
library(DT)
library(dplyr)
library(survival)
library(survminer)
library(ggplot2)
library(umap)

# ---- 1. LOAD DATA ----
data_dir <- if (dir.exists("data")) "data" else file.path(dirname(getwd()), "dashboard_app/data")

cat("DIAG: data_dir =", data_dir, "\n")
cat("DIAG: dir.exists(data) =", dir.exists("data"), "\n")
cat("DIAG: dir.exists(/app/data) =", dir.exists("/app/data"), "\n")

tryCatch({
  patient_data <- read.csv(file.path(data_dir, "patient_data.csv"), row.names = 1)
  cat("DIAG: patient_data loaded OK,", nrow(patient_data), "rows\n")
}, error = function(e) cat("DIAG ERROR patient_data:", e$message, "\n"))

# Auto-compute UMAP if missing (so the patient map always works)
if (exists("patient_data") && !"umap_x" %in% colnames(patient_data)) {
  cat("Computing UMAP from factor scores...\n")
  factor_cols <- grep("^Factor[0-9]", names(patient_data), value = TRUE)
  if (length(factor_cols) >= 3) {
    umap_result <- umap(as.matrix(patient_data[, factor_cols]))
    patient_data$umap_x <- umap_result$layout[, 1]
    patient_data$umap_y <- umap_result$layout[, 2]
    write.csv(patient_data, file.path(data_dir, "patient_data.csv"))
    cat("  UMAP computed and saved to patient_data.csv\n")
  }
}

tryCatch({
  cox_os <- read.csv(file.path(data_dir, "cox_os.csv"))
  cat("DIAG: cox_os loaded OK,", nrow(cox_os), "rows\n")
}, error = function(e) cat("DIAG ERROR cox_os:", e$message, "\n"))

tryCatch({
  cox_adjusted <- read.csv(file.path(data_dir, "cox_adjusted_clinical_os.csv"))
  cat("DIAG: cox_adjusted loaded OK\n")
}, error = function(e) cat("DIAG ERROR cox_adjusted:", e$message, "\n"))

tryCatch({
  var_summary <- read.csv(file.path(data_dir, "factor_variance_summary.csv"))
  cat("DIAG: var_summary loaded OK\n")
}, error = function(e) cat("DIAG ERROR var_summary:", e$message, "\n"))

tryCatch({
  rmst <- read.csv(file.path(data_dir, "rmst_per_factor.csv"))
  cat("DIAG: rmst loaded OK\n")
}, error = function(e) cat("DIAG ERROR rmst:", e$message, "\n"))

tryCatch({
  top_features <- read.csv(file.path(data_dir, "top_features_per_factor.csv"))
  cat("DIAG: top_features loaded OK\n")
}, error = function(e) cat("DIAG ERROR top_features:", e$message, "\n"))

tryCatch({
  factor_desc <- read.csv(file.path(data_dir, "factor_descriptions.csv"))
  cat("DIAG: factor_desc loaded OK\n")
}, error = function(e) cat("DIAG ERROR factor_desc:", e$message, "\n"))

tryCatch({
  ref_km <- read.csv(file.path(data_dir, "reference_km.csv"))
  cat("DIAG: ref_km loaded OK\n")
}, error = function(e) cat("DIAG ERROR ref_km:", e$message, "\n"))

tryCatch({
  baseline_surv <- read.csv(file.path(data_dir, "baseline_survival.csv"))
  cat("DIAG: baseline_surv loaded OK\n")
}, error = function(e) cat("DIAG ERROR baseline_surv:", e$message, "\n"))

tryCatch({
  cox_multi <- readRDS(file.path(data_dir, "cox_multi.rds"))
  cat("DIAG: cox_multi loaded OK\n")
}, error = function(e) cat("DIAG ERROR cox_multi:", e$message, "\n"))

factor_names <- paste0("Factor", 1:15)
cox_coefs <- coef(cox_multi)


# ---- 2. UI ----
ui <- bs4DashPage(
  help = NULL,
  dark = NULL,
  header = dashboardHeader(
    title = NULL,
    skin = "light",
    status = "white",
    border = TRUE,
    sidebarIcon = NULL,
    controlbarIcon = icon("gears"),
    fixed = FALSE,
    tags$li(class = "nav-item header-brand",
      tags$a(class = "brand-link", href = "#",
        tags$span(class = "brand-text", "BRCA Navigator")
      )
    )
  ),
  sidebar = dashboardSidebar(
    skin = "light",
    status = "primary",
    elevation = 3,
    sidebarMenu(
      id = "sidebar_menu",
      menuItem("The Story", tabName = "story", icon = icon("book-open")),
      menuItem("Factor Explorer", tabName = "factors", icon = icon("chart-line")),
      menuItem("Patient Map", tabName = "map", icon = icon("map")),
      menuItem("Gene Explorer", tabName = "genes", icon = icon("dna")),
      menuItem("Survival Simulator", tabName = "simulator", icon = icon("heartbeat")),
      menuItem("Analysis Flow", tabName = "flow", icon = icon("project-diagram")),
      menuItem("About", tabName = "about", icon = icon("info-circle"))
    )
  ),
  body = dashboardBody(
    useShinyjs(),
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css?v=50"),
      tags$link(rel = "stylesheet", href = "https://fonts.googleapis.com/css2?family=Figtree:wght@300;400;500;600;700;800&display=swap"),
      tags$link(rel = "stylesheet",
        href = "https://cdn.jsdelivr.net/npm/intro.js@5.1.0/minified/introjs.min.css"),
      tags$script(src = "https://cdn.jsdelivr.net/npm/intro.js@5.1.0/minified/intro.min.js"),
      tags$script(HTML("
        document.addEventListener('DOMContentLoaded', function() {
          document.body.classList.add('sidebar-mini');
          var storyPage = document.getElementById('story-page');
          var dashPage = document.getElementById('dashboard-page');
          function showStory() {
            dashPage.style.display = 'none';
            storyPage.style.display = 'block';
            window.scrollTo(0, 0);
          }
          function showDashboard() {
            storyPage.style.display = 'none';
            dashPage.style.display = 'block';
            window.scrollTo(0, 0);
          }
          document.querySelector('.sidebar-menu').addEventListener('click', function(e) {
            var item = e.target.closest('.nav-link');
            if (!item) return;
            var val = item.getAttribute('data-value');
            if (val === 'story') showStory();
            else if (val) showDashboard();
          });
        });
        var sidebar = document.querySelector('.main-sidebar');
        if (sidebar) {
          sidebar.addEventListener('mouseenter', function() {
            document.body.classList.add('sidebar-expanded');
          });
          sidebar.addEventListener('mouseleave', function() {
            document.body.classList.remove('sidebar-expanded');
          });
        }
        Shiny.addCustomMessageHandler('show-dashboard', function(msg) {
          document.getElementById('story-page').style.display = 'none';
          document.getElementById('dashboard-page').style.display = 'block';
          window.scrollTo(0, 0);
        });
        Shiny.addCustomMessageHandler('show-story', function(msg) {
          document.getElementById('dashboard-page').style.display = 'none';
          document.getElementById('story-page').style.display = 'block';
          window.scrollTo(0, 0);
        });
      ")),
    ),
    # ---- STORY PAGE ----
    div(id = "story-page",
      # Chapter 1
      div(class = "story-section",
        div(class = "story-content", id = "story-1",
          div(class = "story-icon", "🧬"),
          h1("Breast Cancer Is Not One Disease"),
          p("It's a family of molecular subtypes, each behaving differently, producing different outcomes and treatment responses. We analyzed 636 breast cancer patients from TCGA database across 4 distinct molecular layers to find hidden patterns."),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 2
      div(class = "story-section",
        div(class = "story-content", id = "story-2",
          div(class = "story-number", "1"),
          h2("4 Layers of Molecular Data"),
          p("Think of a cancer cell as a complex factory. Instead of examining just one department, we inspected 4 critical systems simulatenously:"),
          p(style = "font-size:1.1rem; text-align:left;",
            "🧬 RNA (Gene expression): Which genes are currently active? ",
            "|🔗 Methylation (Epigenetics): Which genetic switches are flipped on or off? ",
            "|🧪 RPPA (Protein levels): Which proteins are working? ",
            "|📏 CNV (Copy Number Variation): Are any genes broken, missing or overrepresented? "
          ),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 3
      div(class = "story-section",
        div(class = "story-content", id = "story-3",
          div(class = "story-number", "2"),
          h2("MOFA2 Found 15 Hidden Patterns"),
          p("MOFA2 acts like a sophisticated filter, cutting through the molecular noise to reveal 15 hidden patterns (or latent factors) that explain the variation across patients at a deep biological level. Each factor captures a distinct cellular process."),
          p("Some factors are driven primarily by RNA activity, others by methylation patterns, and several weave together signals from multiple molecular layers at once."),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 4 - Factor 5
      div(class = "story-section",
        div(class = "story-content", id = "story-4",
          div(class = "story-number", "3"),
          h2("🥇 Factor 5: The Immune Guardian"),
          p("Factor 5 captures an immune checkpoint signature built around genes like TIGIT, ICOS and ZAP70 that essentially mobilize the body's natural defenses against the tumor."),
          p("Patients with high Factor 5 carried a 37% lower risk of mortality, making it the strongest protective signal we discovered in the entire analysis."),
          p(style = "font-size:1rem;", "What this means: If a patient's tumor shows this immune-active pattern, their prognosis is significantly better even after adjusting for age, stage and molecular subtype."),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 5 - Factor 7
      div(class = "story-section",
        div(class = "story-content", id = "story-5",
          div(class = "story-number", "4"),
          h2("🥈 Factor 7: The Delayed Shield"),
          p("Factor 7 was completely invisible to standard survival analysis at first, appearing insignificant with no clear protective signal. But when we shifted our approach and measured Restricted Mean Survival Time, an entirely different story emerged."),
          p("Patients with high Factor 7 lived an average of 95.6 days longer. The reason it was so easy to miss is that this protection unfolds slowly, taking roughly 3 years to fully appear."),
          p(style = "font-size:1rem;", "This is why we need multiple statistical approaches as some biological effects are genuinely delayed and standard Cox models miss them."),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 6 - Risk Factors
      div(class = "story-section",
        div(class = "story-content", id = "story-6",
          div(class = "story-number", "5"),
          h2("⚠️ The Risk Factors"),
          p("Not every pattern we uncovered were protective. Four factors emerged as clear danger signals (Factor 8, Factor 10, Factor 13 and Factor 14) each tied to significantly higher mortality risk, with increases spanning from 30% to nearly 50%."),
          p("Factor 14 ranked as the most important variable in our Random Survival Forest model, suggesting it captures a uniquely aggressive biology."),
          div(class = "story-arrow", "↓")
        )
      ),
      # Chapter 7 - Conclusion
      div(class = "story-section",
        div(class = "story-content", id = "story-7",
          div(class = "story-icon", "🎯"),
          h2("What This Means For Patients"),
          p("These 15 molecular patterns help us understand why some breast cancers are more aggressive than others even within the same clinical subtype."),
          p("Factor 5 (immune-active) and Factor 7 (delayed protection) could eventually guide treatment choices and prognosis discussions with patients."),
          p("The predicitve strength is real, not theoretical: Our 3-year model achieved an AUC of 0.705, confirming that these hidden molecular signatures carry genuine power to forecast what lies ahead."),
          p(style = "font-size:1.1rem;margin-top:20px;",
            "Navigate using the sidebar menu →")
        )
      )
    ),
    
    # ---- DASHBOARD PAGE ----
    div(id = "dashboard-page",
      tabItems(
        # ---- FACTOR EXPLORER ----
        tabItem(
          tabName = "factors",
          fluidRow(
            column(12,
              div(class = "desc-box",
                p(style = "margin:0;font-size:0.95rem;",
                  "Factor Explorer: Explore each of the 15 MOFA factors individually. View Kaplan–Meier survival curves, forest plots of hazard ratios across all factors and the top contributing genes for the selected factor.")
              )
            )
          ),
           fluidRow(
            column(12,
              helpText("Select a factor below to load its survival curves, forest plot, and clinical context.")
            )
          ),
          fluidRow(
            column(3,
              selectInput("selected_factor", "Select a Factor",
                choices = factor_names, selected = "Factor5")
            ),
            column(3,
              selectInput("cox_type", "Cox Model",
                choices = c("Unadjusted" = "unadj", "Adjusted (clinical)" = "adj"))
            )
          ),
          fluidRow(
            column(4,
              uiOutput("factor_summary_card")
            ),
            column(4,
              uiOutput("factor_cox_card")
            ),
            column(4,
              uiOutput("factor_rmst_card")
            )
          ),
          fluidRow(
            column(4,
              checkboxInput("subtypeFilter", "Basal-like only", value = FALSE),
              helpText("Filter to only Basal subtype patients. The KM curve and survival cards will recompute on this subset.")
            ),
            column(4, uiOutput("riskPercentile")),
            column(4, uiOutput("surv3yr"))
          ),
          fluidRow(
            column(12,
              plotlyOutput("factor_km_plot", height = "420px"),
              actionLink("showCalc_km", label = "How was this calculated?",
                         icon = icon("info-circle"), style = "margin-top: 5px;")
            )
          ),
          fluidRow(
            column(12,
              div(style = "background:#f1f5f9;border-radius:12px;padding:20px;margin-top:15px;",
                h5("📖 How to Read This"),
                p(style = "color:#475569;font-size:0.95rem;margin:0;",
                  "This graph shows how long each group of patients survived over time. ",
                  "The red line shows patients with a high score for this factor, the green line shows patients with a low score. ",
                  "If the lines are far apart, the factor has a strong link to survival. ",
                  "The p-value at the top tells you if the difference between the groups is statistically significant (p < 0.05 means yes). ",
                  "Hover over the lines to see exact survival percentages at any time point."
                )
              )
            )
          ),
          fluidRow(
            column(12,
              plotOutput("forestPlot", height = "480px")
            )
          ),
          fluidRow(column(12, div(style = "height:40px"))),
          fluidRow(
            column(12,
              uiOutput("factor_clinical_box")
            )
          )
        ),
        
        # ---- PATIENT MAP ----
        tabItem(
          tabName = "map",
          fluidRow(
            column(12,
              div(class = "desc-box",
                p(style = "margin:0;font-size:0.95rem;",
                  "Patient Map: Each point is a patient, projected into 2D via UMAP based on their 15 MOFA factor scores. Use the dropdown to highlight PAM50 subtype or survival status. Click and drag to draw a circle around a group of patients to see a survival curve for the selected group below.")
              )
            )
          ),
          fluidRow(
            column(4,
              wellPanel(
                selectInput("mapColor", "Color by:",
                  choices = c("PAM50 Subtype" = "subtype", "Survival Status" = "os_event")),
                helpText("Click and drag to draw a circle around a group of patients.")
              ),
              div(style = "background:#f1f5f9;border-radius:12px;padding:20px;margin-top:15px;",
                h5("📖 How to Read Patient Map"),
                p(style = "color:#475569;font-size:0.95rem;margin:0;",
                  "Each dot is one patient. Patients with similar molecular patterns sit close together on the map. ",
                  "Use the dropdown menu to color dots by cancer subtype (PAM50) or by survival status. ",
                  "Click and drag on the map to draw a circle around a group and a survival curve for those patients will appear below the map. ",
                  "Clusters of dots close together suggest those patients share similar biology."
                )
              )
            ),
            column(8,
              plotOutput("patientMap", height = "500px",
                brush = brushOpts(id = "mapBrush", resetOnNew = TRUE))
            )
          ),
          fluidRow(
            column(12,
              plotOutput("mapSurvival", height = "350px"),
              actionLink("showCalc_map", label = "How was this calculated?",
                         icon = icon("info-circle"), style = "margin-top: 5px;")
            )
          ),
          fluidRow(
            column(12,
              div(style = "background:#f1f5f9;border-radius:12px;padding:20px;margin-top:10px;",
                h5("📖 How to Read the Survival Curve"),
                p(style = "color:#475569;font-size:0.95rem;margin:0;",
                  "This graph shows how the selected group of patients survived over time. ",
                  "The purple line goes down as patients pass away. A line that stays high means better survival. ",
                  "The shaded band around the line shows the range of uncertainty (95% confidence interval). ",
                  "The more patients selected, the narrower the band and the more reliable the estimate."
                )
              )
            )
          )
        ),
        
        # ---- GENE EXPLORER ----
        tabItem(
          tabName = "genes",
          fluidRow(
            column(12,
              div(class = "desc-box",
                p(style = "margin:0;font-size:0.95rem;",
                  "🔍 Gene Explorer: Type a gene name to see which MOFA factors it belongs to, how its expression relates to Factor 5, and its hazard ratio across factors. Start typing or select from the dropdown below."
                )
              )
            )
          ),
          fluidRow(
            column(6,
              selectizeInput("gene_search", "Search for a gene",
                choices = NULL, selected = "TIGIT",
                options = list(placeholder = "Type a gene name..."))
            ),
            column(6,
              uiOutput("gene_hr_badge")
            )
          ),
          fluidRow(
            column(6,
              h5("Expression by Factor 5 Score", class = "mt-2"),
              plotlyOutput("gene_expression_plot", height = "400px"),
              actionLink("showCalc_gene", label = "How was this calculated?",
                         icon = icon("info-circle"), style = "margin-top: 5px;"),
              div(style = "background:#f1f5f9;border-radius:12px;padding:20px;margin-top:12px;",
                h5("📖 How to Read This"),
                p(style = "color:#475569;font-size:0.95rem;margin:0;",
                  "Each dot is a patient, colored by their cancer subtype (PAM50). ",
                  "The dot's position shows the gene's expression level (y-axis) vs their Factor 5 score (x-axis). ",
                  "The blue line shows the overall trend which means if it goes up, the gene is more active in immune-active tumors. ",
                  "If the dots are spread far from the line, the gene's expression varies a lot regardless of Factor 5."
                )
              )
            ),
             column(6,
               h5("PAM50 Subtypes", class = "mt-2"),
               div(style = "display:grid;grid-template-columns:1fr 1fr;gap:8px;",
                 div(style = "background:#F5F7E8;border-radius:8px;padding:10px 12px;border:1px solid #d5d8c8;",
                   span(style = "display:inline-block;width:10px;height:10px;border-radius:50%;background:#7A70BA;margin-right:6px;"),
                   strong("Luminal A"), div(style = "font-size:0.78rem;color:#64748b;margin-top:2px;","ER+/PR+, low prolif, ~46%")),
                 div(style = "background:#F5F7E8;border-radius:8px;padding:10px 12px;border:1px solid #d5d8c8;",
                   span(style = "display:inline-block;width:10px;height:10px;border-radius:50%;background:#B8963E;margin-right:6px;"),
                   strong("Luminal B"), div(style = "font-size:0.78rem;color:#64748b;margin-top:2px;","ER+/PR+, higher grade, ~18%")),
                 div(style = "background:#F5F7E8;border-radius:8px;padding:10px 12px;border:1px solid #d5d8c8;",
                   span(style = "display:inline-block;width:10px;height:10px;border-radius:50%;background:#B85450;margin-right:6px;"),
                   strong("Basal-like"), div(style = "font-size:0.78rem;color:#64748b;margin-top:2px;","Triple-neg, TP53 80%, ~15%")),
                 div(style = "background:#F5F7E8;border-radius:8px;padding:10px 12px;border:1px solid #d5d8c8;",
                   span(style = "display:inline-block;width:10px;height:10px;border-radius:50%;background:#9B6EB0;margin-right:6px;"),
                   strong("HER2-enriched"), div(style = "font-size:0.78rem;color:#64748b;margin-top:2px;","HER2 amp, targeted Rx, ~14%")),
                 div(style = "background:#F5F7E8;border-radius:8px;padding:10px 12px;border:1px solid #d5d8c8;",
                   span(style = "display:inline-block;width:10px;height:10px;border-radius:50%;background:#6B8F5E;margin-right:6px;"),
                   strong("Normal-like"), div(style = "font-size:0.78rem;color:#64748b;margin-top:2px;","Resembles normal, ~8%"))
               ),
               br(),
               p(style = "color:#64748b;font-size:0.85rem;margin:0;",
                 "Subtypes are determined by the PAM50 50-gene classifier. Colors match the legend in the expression plot.")
             )
          ),
          fluidRow(
            column(12,
              div(id = "gene-table-section", style = "background:#f8fafc;border:1px solid #B1B4C8;border-radius:10px;padding:20px;margin-top:16px;",
                h4("Top Genes by Factor", class = "mt-0 mb-3", style = "color:#0f172a;font-weight:700;padding-bottom:10px;border-bottom:2px solid #B1B4C8;"),
                DTOutput("all_genes_table")
              )
            )
          ),
        ),

        # ---- SURVIVAL SIMULATOR ----
        tabItem(
          tabName = "simulator",
          fluidRow(
            column(12,
              div(class = "desc-box",
                p(style = "margin:0;font-size:0.95rem;",
                  "Survival Simulator: Build a custom patient profile by adjusting MOFA factor scores and instantly see predicted survival outcomes, including 5-year survival probability, median survival time, and hazard ratio versus the average patient.")
              )
            )
          ),
          fluidRow(
            column(4,
              div(class = "simulator-card",
                h4("👤 Patient Profile", class = "mb-4"),
                lapply(c(5, 7, 8, 10, 13, 14), function(f) {
                  div(
                    style = "margin-bottom: 18px;",
                    tags$label(paste0("Factor ", f), class = "form-label", style = "font-weight:600;"),
                    div(style = "display:flex;justify-content:space-between;font-size:0.85rem;color:#64748b;",
                      span("Low"), span("High")
                    ),
                    sliderInput(paste0("sim_f", f), NULL,
                      min = -3, max = 3, value = 0, step = 0.1,
                      ticks = FALSE, width = "100%"
                    )
                  )
                }),
                actionButton("reset_sim", "Reset to Average", 
                  class = "btn btn-outline-primary btn-block mt-3"),
                actionButton("sim_protective", "🛡️ Protective Profile",
                  class = "btn btn-success btn-block mt-2"),
                actionButton("sim_risky", "⚠️ Risk Profile",
                  class = "btn btn-danger btn-block mt-2")
              )
            ),
            column(8,
              fluidRow(
                column(12,
                  div(class = "simulator-result",
                    fluidRow(
                      column(4,
                        div(class = "big-number", textOutput("sim_5yr_surv", inline = TRUE)),
                        div(class = "label", "5-Year Survival")
                      ),
                      column(4,
                        div(class = "big-number", style = "font-size:2.5rem;",
                          textOutput("sim_median_surv", inline = TRUE)),
                        div(class = "label", "Median Survival (days)")
                      ),
                      column(4,
                        div(class = "big-number", textOutput("sim_hr_display", inline = TRUE)),
                        div(class = "label", "Hazard Ratio vs Average")
                      )
                    )
                  )
                )
              ),
              fluidRow(
                column(12,
                  h5("Predicted Survival Curve", class = "mt-3"),
                  plotlyOutput("sim_km_plot", height = "400px")
                )
              ),
              fluidRow(
                column(12,
                  div(style = "background:#f1f5f9;border-radius:12px;padding:20px;margin-top:15px;",
                    h5("📖 How to Read This"),
                    p(style = "color:#475569;font-size:0.95rem;",
                      "Adjust the sliders to create a patient profile. The model uses the actual Cox regression coefficients
                      from our 636-patient analysis to predict survival. Blue line = your patient. Gray band = average patient.
                      Protective Profile: High Factor 5 (immune-active) + High Factor 7 (delayed protection).",
                      "Risk Profile: High Factors 8, 10, 13, 14 (aggressive biology)."
                    )
                  )
                )
              )
            )
          )
        ),
        
        # ---- ANALYSIS FLOW ----
        tabItem(
          tabName = "flow",
          fluidRow(
            column(12,
              div(class = "desc-box",
                p(style = "margin:0;font-size:0.95rem;",
                  "Analysis Flow: The complete analysis pipeline from raw data to survival prediction. Each step is described below with key details."))
            )
          ),
          
          # STEP 1: Data
          fluidRow(
            column(12,
              div(style = "background:#fff;border:1px solid #B1B4C8;border-radius:12px;padding:20px;margin-bottom:15px;",
                div(style = "display:flex;align-items:center;gap:15px;margin-bottom:10px;",
                  div(style = "background:#ccfbf1;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#115e59;font-size:1.2rem;", "1"),
                  div(style = "font-size:1.3rem;font-weight:700;color:#0f172a;", "Data Acquisition"),
                  div(style = "margin-left:auto;background:#e2e8f0;border-radius:20px;padding:4px 14px;font-size:0.85rem;color:#475569;", "636 patients")
                ),
                div(style = "display:flex;flex-wrap:wrap;gap:12px;",
                  div(style = "flex:1;min-width:130px;padding:12px;background:#f8fafc;border-radius:8px;text-align:center;",
                    div(style = "font-size:1.1rem;font-weight:700;color:#115e59;", "RNA-seq"),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "20,501 genes were taken to measure which genes are active")),
                  div(style = "flex:1;min-width:130px;padding:12px;background:#f8fafc;border-radius:8px;text-align:center;",
                    div(style = "font-size:1.1rem;font-weight:700;color:#115e59;", "DNA Methylation"),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "~485K probes were taken to determine Which genes are silenced")),
                  div(style = "flex:1;min-width:130px;padding:12px;background:#f8fafc;border-radius:8px;text-align:center;",
                    div(style = "font-size:1.1rem;font-weight:700;color:#115e59;", "RPPA Proteins"),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "281 proteins were taken to meausre which proteins are present")),
                  div(style = "flex:1;min-width:130px;padding:12px;background:#f8fafc;border-radius:8px;text-align:center;",
                    div(style = "font-size:1.1rem;font-weight:700;color:#94a3b8;", "Copy Number Variation - CNV"),
                    div(style = "font-size:0.85rem;color:#94a3b8;margin-top:4px;", " To check whether genes are accidentlly duplicated or deleted.Excluded after quality filtering"))
                )
              )
            )
          ),
          
          # Step 2: Preprocessing
          fluidRow(
            column(12,
              div(style = "background:#fff;border:1px solid #B1B4C8;border-radius:12px;padding:20px;margin-bottom:15px;",
                div(style = "display:flex;align-items:center;gap:15px;margin-bottom:10px;",
                  div(style = "background:#e0e7ff;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#4338ca;font-size:1.2rem;", "2"),
                  div(style = "font-size:1.3rem;font-weight:700;color:#0f172a;", "Preprocessing & Feature Selection")
                ),
                tags$ul(style = "color:#475569;font-size:0.95rem;line-height:1.8;margin:8px 0 0 0;padding-left:20px;",
                  tags$li("Removed duplicate tumor samples and kept one per patient to avoid bias"),
                  tags$li("KNN imputation for missing DNA methylation values"),
                  tags$li("Selected top variable features: 8,000 RNA genes, 8,000 methylation probes, 3,000 CNV genes"),
                  tags$li("Aligned all 4 data types so each column = same patient across all omics"),
                  tags$li("Final: 636 patients with RNA + Methylation + RPPA (CNV had 0 features after filtering)")
                )
              )
            )
          ),
          
          # Step 3: MOFA2
          fluidRow(
            column(12,
              div(style = "background:#fff;border:1px solid #B1B4C8;border-radius:12px;padding:20px;margin-bottom:15px;",
                div(style = "display:flex;align-items:center;gap:15px;margin-bottom:10px;",
                  div(style = "background:#fef3c7;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#92400e;font-size:1.2rem;", "3"),
                  div(style = "font-size:1.3rem;font-weight:700;color:#0f172a;", "MOFA2 — Multi-Omics Factor Analysis"),
                  div(style = "margin-left:auto;background:#fef3c7;border-radius:20px;padding:4px 14px;font-size:0.85rem;color:#92400e;", "15 latent factors")
                ),
                p(style = "color:#475569;font-size:0.95rem;margin:0;",
                  "MOFA2 overlays all 4 omics layers simultaneously to discover hidden patterns (factors) that explain variation across data types. ",
                  "Each patient gets a score (-3 to +3) per factor. The first 2 factors alone explain 47% of all coordinated variation:"),
                div(style = "margin-top:10px;",
                  tags$table(style = "width:100%;border-collapse:collapse;font-size:0.9rem;",
                    tags$tr(style = "background:#f1f5f9;font-weight:600;",
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "Factor"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "RNA %"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "Methyl %"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "RPPA %"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "Total %")),
                    tags$tr(tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "Factor 1"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "9.9"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "10.7"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "5.1"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "25.7")),
                    tags$tr(style = "background:#f8fafc;", tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "Factor 2"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "8.9"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "4.3"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "8.3"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "21.5")),
                    tags$tr(tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "Factor 3"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "0.1"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "11.2"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "0.1"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "11.5")),
                    tags$tr(style = "background:#f8fafc;", tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "Factor 5"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "3.2"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "3.9"),
                      tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;", "0.8"), tags$td(style = "padding:6px 10px;border:1px solid #B1B4C8;font-weight:600;", "8.0"))
                  )
                ),
                p(style = "color:#64748b;font-size:0.85rem;margin:8px 0 0 0;",
                  "Factors 3-4 are mostly methylation-driven. Factor 6 is mostly RNA-driven. Factors 7-15 each explain 1.5-5.1%.")
              )
            )
          ),
          
          # Step 4: Survival Analysis
          fluidRow(
            column(12,
              div(style = "background:#fff;border:1px solid #B1B4C8;border-radius:12px;padding:20px;margin-bottom:15px;",
                div(style = "display:flex;align-items:center;gap:15px;margin-bottom:10px;",
                  div(style = "background:#d1fae5;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#065f46;font-size:1.2rem;", "4"),
                  div(style = "font-size:1.3rem;font-weight:700;color:#0f172a;", "Survival Analysis — 5 Complementary Methods"),
                  div(style = "margin-left:auto;background:#d1fae5;border-radius:20px;padding:4px 14px;font-size:0.85rem;color:#065f46;", "OS endpoint")
                ),
                div(style = "display:flex;flex-wrap:wrap;gap:12px;margin-top:8px;",
                  div(style = "flex:1;min-width:140px;padding:14px;background:#f8fafc;border-radius:8px;",
                    div(style = "font-weight:700;color:#0f172a;", "Cox Regression"),
                    div(style = "font-size:0.85rem;color:#64748b;", "Hazard ratio per factor. Adjusted for age + stage. 5 significant factors (p < 0.05).")),
                  div(style = "flex:1;min-width:140px;padding:14px;background:#f8fafc;border-radius:8px;",
                    div(style = "font-weight:700;color:#0f172a;", "Kaplan-Meier Curves"),
                    div(style = "font-size:0.85rem;color:#64748b;", "High vs low factor score groups. Visual survival separation. Verified with tertile splits.")),
                  div(style = "flex:1;min-width:140px;padding:14px;background:#f8fafc;border-radius:8px;",
                    div(style = "font-weight:700;color:#0f172a;", "RMST"),
                    div(style = "font-size:0.85rem;color:#64748b;", "\"How many extra days?\" Factor 7: +95.6 days (p = 0.049) — delayed protective effect.")),
                  div(style = "flex:1;min-width:140px;padding:14px;background:#f8fafc;border-radius:8px;",
                    div(style = "font-weight:700;color:#0f172a;", "Random Survival Forest"),
                    div(style = "font-size:0.85rem;color:#64748b;", "ML model. Factor 14 is 3x more important than any other. C-index = 0.594.")),
                  div(style = "flex:1;min-width:140px;padding:14px;background:#f8fafc;border-radius:8px;",
                    div(style = "font-weight:700;color:#0f172a;", "Time-Dependent ROC"),
                    div(style = "font-size:0.85rem;color:#64748b;", "Best at 3-year prediction: AUC = 0.705. 1-yr: 0.42 (too few events). 5-yr: 0.613."))
                )
              )
            )
          ),
          
          # Step 5: Key Findings
          fluidRow(
            column(12,
              div(style = "background:#fff;border:1px solid #B1B4C8;border-radius:12px;padding:20px;margin-bottom:15px;",
                div(style = "display:flex;align-items:center;gap:15px;margin-bottom:10px;",
                  div(style = "background:#fce7f3;width:40px;height:40px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-weight:800;color:#831843;font-size:1.2rem;", "5"),
                  div(style = "font-size:1.3rem;font-weight:700;color:#0f172a;", "Key Findings — Protective & Risk Factors"),
                  div(style = "margin-left:auto;background:#fce7f3;border-radius:20px;padding:4px 14px;font-size:0.85rem;color:#831843;", "Clinical significance")
                ),
                div(style = "display:flex;flex-wrap:wrap;gap:12px;",
                  div(style = "flex:1;min-width:180px;padding:16px;background:#f8fafc;border-radius:10px;",
                    div(style = "font-weight:700;color:#065f46;font-size:1.05rem;", "🛡️ Factor 5 — Immune Checkpoint"),
                    div(style = "font-size:0.9rem;color:#475569;margin-top:4px;", "Top genes: TIGIT, ICOS, ZAP70, SIRPG, PLA2G2D"),
                    div(style = "font-size:0.9rem;color:#047857;margin-top:4px;", "HR = 0.63 (adjusted) — strongest protective factor"),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "Captures active T-cell immunity. Independent of age, stage, subtype.")),
                  div(style = "flex:1;min-width:180px;padding:16px;background:#f8fafc;border-radius:10px;",
                    div(style = "font-weight:700;color:#065f46;font-size:1.05rem;", "⌛ Factor 7 — Delayed Protection"),
                    div(style = "font-size:0.9rem;color:#475569;margin-top:4px;", "RMST: +95.6 days (p = 0.049) — Cox HR was 0.93 (NS)"),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "Protective effect only appears after ~3 years. RMST captures what Cox misses.")),
                  div(style = "flex:1;min-width:180px;padding:16px;background:#f8fafc;border-radius:10px;",
                    div(style = "font-weight:700;color:#991b1b;font-size:1.05rem;", "⚠️ Factors 8, 10, 13, 14 — Risk Factors"),
                    div(style = "font-size:0.9rem;color:#475569;margin-top:4px;", "HR range: 1.30 - 1.47. Primarily methylation-driven."),
                    div(style = "font-size:0.85rem;color:#64748b;margin-top:4px;", "Factor 14 was #1 in RSF (3x more important than any other). Novel biology."))
                ),
                div(style = "margin-top:12px;padding:12px;background:#fffbeb;border-radius:8px;font-size:0.9rem;color:#92400e;",
                  "3-year AUC = 0.705 — moderate accuracy. RSF C-index = 0.594. Multiple testing: no factor passed strict p.adj < 0.05 (limited power with ~100 deaths). ",
                  "Consistency across 5 methods strengthens confidence in findings.")
              )
            )
          )
        ),
        
        # ---- ABOUT ----
        tabItem(
          tabName = "about",
          fluidRow(
            column(8, offset = 2,
              div(style = "padding:40px 0;",
                h2("About This Project"),
                hr(),
                h4("Data Source"),
                p("TCGA-BRCA (The Cancer Genome Atlas — Breast Invasive Carcinoma).
                  636 patients with 4 omics layers: RNA-seq, DNA Methylation (450K), RPPA (protein), and Copy Number Variation."),
                p("All data retrieved from ", a("UCSC Xena", href = "https://xenabrowser.net", target = "_blank"), "."),
                h4("Built With"),
                p("R, Shiny, bs4Dash, Plotly, visNetwork, survival, MOFA2,
                  UCSCXenaTools, MultiAssayExperiment, DT, dplyr, ggplot2,
                  survminer, ranger, glmnet, timeROC, survRM2,
                  clusterProfiler, GEOquery"),
                h4("Disclaimer"),
                p("This dashboard is provided for research and educational purposes only.
                  The data and analyses are based on publicly available TCGA-BRCA data
                  from UCSC Xena and are not intended for clinical or medical use.
                  No warranties, express or implied, are made regarding the accuracy,
                  completeness, or suitability of the data or results. All analyses are
                  exploratory and should not be used for diagnostic or treatment decisions."),
                h4("Contact"),
                p("For questions, feedback, or collaboration inquiries, please contact:",
                  a("chauhanswati7799@gmail.com", href = "mailto:chauhanswati7799@gmail.com"),
                  " or ",
                  a("arcturexx@gmail.com", href = "mailto:arcturexx@gmail.com"))
              )
            )
          )
        )
      )
    )
  ),
  controlbar = dashboardControlbar(
    skin = "light",
    pinned = FALSE,
    collapsed = TRUE,
    overlay = TRUE,
    controlbarMenu(
      id = "controlbar_menu",
      controlbarItem(
        "History",
        h5("Recent Activity"),
        uiOutput("recentHistory"),
        hr(),
        helpText("Last 20 actions shown.")
      )
    )
  ),
  footer = dashboardFooter(
    left = "TCGA-BRCA MOFA2 Analysis",
    right = "Built with R/Shiny"
  )
)

# ---- 3. SERVER ----
server <- function(input, output, session) {
  cat("DIAG: server function called (session started)\n")
  
  # -- SCROLL ANIMATIONS --
  runjs("
    // Story scroll reveal
    const storyObserver = new IntersectionObserver((entries) => {
      entries.forEach((entry, i) => {
        if (entry.isIntersecting) {
          setTimeout(() => entry.target.classList.add('visible'), i * 120);
        }
      });
    }, { threshold: 0.25 });
    document.querySelectorAll('.story-content').forEach(el => storyObserver.observe(el));

    // Tooltip: position fixed on hover
    document.querySelectorAll('.factor-card').forEach(card => {
      const tooltip = card.querySelector('.card-tooltip');
      if (!tooltip) return;
      let hideTimer = null;
      card.addEventListener('mouseenter', () => {
        clearTimeout(hideTimer);
        const rect = card.getBoundingClientRect();
        tooltip.style.position = 'fixed';
        tooltip.style.top = (rect.bottom + 8) + 'px';
        tooltip.style.left = Math.max(10, Math.min(rect.left, window.innerWidth - 300)) + 'px';
        tooltip.style.zIndex = '99999';
        tooltip.style.width = Math.min(300, window.innerWidth - 20) + 'px';
        tooltip.style.visibility = 'visible';
        tooltip.style.opacity = '1';
      });
      card.addEventListener('mouseleave', () => {
        tooltip.style.visibility = 'hidden';
        tooltip.style.opacity = '0';
      });
    });

    // Simulator count-up animation
    function animateCountUp(el, target, suffix) {
      const numericTarget = parseFloat(target);
      if (isNaN(numericTarget)) { el.textContent = target; return; }
      const duration = 600;
      const steps = 30;
      const stepTime = duration / steps;
      let current = 0;
      const increment = numericTarget / steps;
      const timer = setInterval(() => {
        current += increment;
        if (current >= numericTarget) {
          el.textContent = target;
          clearInterval(timer);
        } else {
          el.textContent = current.toFixed(1) + (suffix || '');
        }
      }, stepTime);
    }

    Shiny.addCustomMessageHandler('animate-sim-results', function(msg) {
      requestAnimationFrame(function() {
        const el5 = document.getElementById('sim_5yr_surv');
        const elMed = document.getElementById('sim_median_surv');
        const elHr = document.getElementById('sim_hr_display');
        if (el5) animateCountUp(el5, msg.surv_5yr, '%');
        if (elMed) animateCountUp(elMed, msg.median_surv, '');
        if (elHr) animateCountUp(elHr, msg.hr_display, '');
      });
    });
  ")
  
  # -- REACTIVE VALUES --
  rv <- reactiveValues(
    selected_factor = "Factor5",
    cox_data = cox_os
  )

  observeEvent(input$selected_factor, {
    rv$selected_factor <- input$selected_factor
  })
  
  observeEvent(input$cox_type, {
    rv$cox_data <- if (input$cox_type == "adj") cox_adjusted else cox_os
  })

  # -- "HOW WAS THIS CALCULATED?" MODALS --
  observeEvent(input$showCalc_km, {
    showModal(modalDialog(title = "How This Was Calculated", size = "l", easyClose = TRUE,
      h4("Kaplan-Meier Survival Curve"),
      p("Patients are split into High and Low groups based on whether their factor score is above or below the median."),
      p("The Kaplan-Meier method estimates survival probability over time for each group. The log-rank test compares the two curves."),
      h4("Sample Size"),
      p("636 patients or approx 318 in each group (high/low)."),
      h4("Caveats"),
      tags$ul(
        tags$li("The median split is arbitrary. Other cutpoints may give different results."),
        tags$li("No adjustment for confounders. Use the Cox model hazard ratio for adjusted estimates."),
        tags$li("Wide confidence intervals at late time points due to fewer patients remaining.")
      ),
      footer = modalButton("Got it")
    ))
  })

  observeEvent(input$showCalc_map, {
    showModal(modalDialog(title = "How This Was Calculated", size = "l", easyClose = TRUE,
      h4("UMAP Projection"),
      p("UMAP (Uniform Manifold Approximation and Projection) reduces the 15-dimensional MOFA factor scores down to 2 dimensions for visualization. Each point represents one patient, positioned so that patients with similar multi-omics profiles appear close together."),
      h4("Brush Selection & Survival"),
      p("Click and drag on the UMAP plot to draw a circle around a group of patients. A Kaplan-Meier survival curve is then computed for the selected patients only, showing their estimated survival trajectory."),
      h4("Caveats"),
      tags$ul(
        tags$li("UMAP is a stochastic algorithm and running it again may produce a slightly different layout."),
        tags$li("2D projections necessarily distort some distances from the original 15D space."),
        tags$li("Survival estimates for small brushed groups may have wide confidence intervals.")
      ),
      footer = modalButton("Got it")
    ))
  })

  observeEvent(input$showCalc_gene, {
    showModal(modalDialog(title = "How This Was Calculated", size = "l", easyClose = TRUE,
      h4("Expression vs Factor 5 Score"),
      p("This plot shows the relationship between a gene's expression level and the patient's Factor 5 score. Since actual expression data varies by gene, the y-axis values are simulated using a linear model: expression = 0.3 × Factor5 + random noise, then rescaled to a 0–15 range. The trend line (blue) is a linear regression fit."),
      h4("Interpretation"),
      p("A positive slope means the gene tends to be more highly expressed as Factor 5 score increases. The colored points show PAM50 subtypes, revealing whether the relationship differs by molecular subtype."),
      h4("Caveats"),
      tags$ul(
        tags$li("Expression values are simulated for illustration. Real data would show gene-specific patterns."),
        tags$li("Factor 5 may not be the dominant factor for every gene shown here."),
        tags$li("The linear model is a simplification; true expression relationships can be non-linear.")
      ),
      footer = modalButton("Got it")
    ))
  })

  # -- RECENT HISTORY --
  history <- reactiveValues(entries = list())

  track_action <- function(action_type, detail) {
    entry <- list(
      type = action_type, detail = detail, time = Sys.time(),
      icon = switch(action_type,
        factor = "chart-bar", patient = "user",
        gene = "dna", map = "map", sim = "heartbeat", "circle")
    )
    history$entries <- c(list(entry), head(history$entries, 19))
  }

  observeEvent(input$selected_factor, {
    track_action("factor", paste("Explored", input$selected_factor))
  }, ignoreInit = TRUE)

  observeEvent(input$gene_search, {
    if (nchar(input$gene_search) > 0) {
      track_action("gene", paste("Searched gene:", input$gene_search))
    }
  }, ignoreInit = TRUE)

  output$recentHistory <- renderUI({
    req(length(history$entries) > 0)
    tags$div(lapply(seq_along(history$entries), function(i) {
      e <- history$entries[[i]]
      tags$div(
        style = "padding: 6px 0; border-bottom: 1px solid #B1B4C8; font-size: 0.9rem;",
        icon(e$icon, class = "fa-fw"),
        span(e$detail),
        br(),
        span(format(e$time, "%H:%M"), style = "font-size: 0.8em; color: #888;")
      )
    }))
  })
  
  # -- FACTOR EXPLORER --
  selected_cox <- reactive({
    df <- rv$cox_data
    df[df$Factor == rv$selected_factor, ]
  })
  
  output$factor_summary_card <- renderUI({
    f <- rv$selected_factor
    fnum <- as.numeric(gsub("Factor", "", f))
    desc <- factor_desc[factor_desc$factor == f, ]
    ve <- var_summary[var_summary$Factor == f, ]
    
    div(class = "factor-card card-analysis",
      div(class = "factor-title", f),
      div(style = "color:#64748b;font-size:0.9rem;margin:5px 0;",
        desc$top_genes[1]
      ),
      hr(),
      div(style = "display:flex;justify-content:space-between;",
        div(span("VE:", style = "color:#64748b;"), span(paste0(round(ve$Variance_Pct, 1), "%"), style = "font-weight:700;font-size:1.2rem;")),
        div(span("Category:", style = "color:#64748b;"), span(desc$category, style = "font-weight:600;"))
      ),
      div(class = "card-tooltip",
        strong(f), br(),
        "VE% (Variance Explained): how much of the total multi-omic variance this factor captures. Higher = more important. ",
        "Category groups factors by biological function (immune, proliferation, development, methylation). ",
        "Top genes are the genes with the strongest loadings on this factor."
      )
    )
  })
  
  output$factor_cox_card <- renderUI({
    cox_row <- selected_cox()
    hr <- round(cox_row$HR, 2)
    pval <- cox_row$p_value
    ci <- paste0("[", round(cox_row$CI_lower, 2), " – ", round(cox_row$CI_upper, 2), "]")
    
    is_protective <- hr < 1
    color_class <- if (is_protective) "protective" else "risk"
    icon <- if (is_protective) "🛡️" else "⚠️"
    
    div(class = paste("factor-card card-analysis", color_class),
      div(class = "factor-title", paste(icon, "Hazard Ratio")),
      div(class = "factor-hr", hr),
      div(style = "color:#64748b;font-size:0.85rem;", "95% CI: ", ci),
      div(style = paste0("font-weight:600;margin-top:5px;",
        ifelse(pval < 0.05, "color:#dc2626;", "color:#64748b;")),
        paste0("p = ", format.pval(pval, digits = 3)),
        if (pval < 0.05) " ★" else ""
      ),
      div(style = "color:#94a3b8;font-size:0.85rem;margin-top:5px;",
        if (is_protective) "Protective (lower risk)" else "Risk factor (higher risk)"
      ),
      div(class = "card-tooltip",
        strong("Hazard Ratio (HR)"), br(),
        "Measures how this factor affects survival risk.", br(),
        "HR = 1 — no effect | HR less than 1 — protective (lives longer) | HR greater than 1 — risk factor (shorter survival).", br(),
        "95% CI: the range of plausible values for the true HR. If the CI crosses 1, the result may not be significant.", br(),
        "p lower than 0.05 means the effect is statistically significant. ★ marks significant results."
      )
    )
  })
  
  output$factor_rmst_card <- renderUI({
    rmst_row <- rmst[rmst$Factor == rv$selected_factor, ]
    diff <- round(rmst_row$RMST_Diff_Days, 1)
    pval <- rmst_row$P_value
    ci <- paste0("[", round(rmst_row$CI_lower, 1), ", ", round(rmst_row$CI_upper, 1), "]")
    
    div(class = "factor-card card-analysis",
      div(class = "factor-title", "📊 RMST Difference"),
      div(class = "factor-hr", paste0(ifelse(diff > 0, "+", ""), diff, "d")),
      div(style = "color:#64748b;font-size:0.85rem;", "95% CI: ", ci),
      div(style = paste0("font-weight:600;margin-top:5px;",
        ifelse(pval < 0.05, "color:#dc2626;", "color:#64748b;")),
        paste0("p = ", format.pval(pval, digits = 3)),
        if (pval < 0.05) " ★" else ""
      ),
      div(style = "color:#94a3b8;font-size:0.85rem;margin-top:5px;",
        if (diff > 0) "Extra survival days (high vs low)" else "Fewer survival days (high vs low)"
      ),
      div(class = "card-tooltip",
        strong("RMST Difference"), br(),
        "Restricted Mean Survival Time: the average survival time difference in days between high and low groups, measured over a restricted time window (e.g., 3-5 years).", br(),
        "Positive value: high group lives longer on average. Negative: high group lives shorter.", br(),
        "Unlike Hazard Ratio, RMST works even when survival curves cross or the effect changes over time.", br(),
        "95% CI: range of plausible values. p less than 0.05 ★ = significant."
      )
    )
  })
  
  filtered_data <- reactive({
    if (input$subtypeFilter) {
      patient_data[patient_data$subtype == "Basal", ]
    } else {
      patient_data
    }
  })
  
  output$riskPercentile <- renderUI({
    if (!"risk_percentile" %in% colnames(patient_data)) {
      return(div(class = "factor-card card-prognosis", style = "background:#f8fafc;",
        div(class = "factor-title", "Risk Score"),
        div(style = "color:#94a3b8;font-size:0.85rem;", "Run scripts/02_risk_score.R first")))
    }
    val <- round(patient_data$risk_percentile[1], 0)
    div(class = "factor-card card-prognosis", style = paste0("background:", ifelse(val > 66, "#fef2f2", "#f0fdf4"), ";border-left-color:", ifelse(val > 66, "#dc2626", "#059669"), ";"),
      div(class = "factor-title", "📊 Risk Percentile"),
      div(class = "factor-hr", paste0(val, "%")),
      div(style = "color:#64748b;font-size:0.85rem;", paste0("Higher risk than ", val, "% of patients")),
      div(class = "card-tooltip",
        strong("Risk Percentile"), br(),
        "Compares this patient's overall risk score to everyone else in the cohort.", br(),
        "A value of ", strong(paste0(val, "%")), " means this patient has higher risk than ", val, "% of all patients.", br(),
        "The risk score is calculated from all 15 MOFA factor scores using a Cox proportional hazards model.",
        " Higher percentile = worse prognosis."
      )
    )
  })
  
  output$surv3yr <- renderUI({
    if (!"surv_3yr" %in% colnames(patient_data)) {
      return(div(class = "factor-card card-prognosis", style = "background:#f8fafc;",
        div(class = "factor-title", "3-Year Survival"),
        div(style = "color:#94a3b8;font-size:0.85rem;", "Run scripts/02_risk_score.R first")))
    }
    val <- round(patient_data$surv_3yr[1] * 100, 0)
    div(class = "factor-card card-prognosis", style = paste0("background:", ifelse(val < 50, "#fef2f2", "#f0fdf4"), ";border-left-color:", ifelse(val < 50, "#dc2626", "#059669"), ";"),
      div(class = "factor-title", "⏱️ 3-Year Survival"),
      div(class = "factor-hr", paste0(val, "%")),
      div(style = "color:#64748b;font-size:0.85rem;", "Predicted chance of surviving 3 years"),
      div(class = "card-tooltip",
        strong("3-Year Survival"), br(),
        "The predicted probability that a patient with this profile survives at least 3 years from diagnosis.", br(),
        "A value of ", strong(paste0(val, "%")), " means a ", val, "% chance of surviving 3 years.", br(),
        "Derived from the full Cox model using all 15 MOFA factor scores.",
        " Higher = better prognosis."
      )
    )
  })
  
  output$factor_km_plot <- renderPlotly({
    f <- rv$selected_factor
    dat <- filtered_data()
    scores <- dat[[f]]
    temp_df <- data.frame(
      os_time = dat$os_time,
      os_event = dat$os_event,
      group = factor(ifelse(scores > median(scores, na.rm = TRUE), "High", "Low"),
                     levels = c("Low", "High"))
    )
    fit <- survfit(Surv(os_time, os_event) ~ group, data = temp_df)
    s <- summary(fit)
    
    plot_df <- data.frame(
      time = s$time,
      surv = s$surv,
      upper = s$upper,
      lower = s$lower,
      group = as.character(s$strata)
    )
    plot_df$group <- sub("^group=", "", plot_df$group)
    
    plot_ly(plot_df, x = ~time, y = ~surv, color = ~group,
            colors = c("#6B8F5E", "#B85450"),
            type = "scatter", mode = "lines",
            line = list(width = 2.5),
            hovertemplate = "Time: %{x} days<br>Survival: %{y:.1%}<extra>%{fullData.name}</extra>") %>%
      layout(
        title = list(text = paste("KM Curve —", f), font = list(size = 14)),
        xaxis = list(title = "Time (days)", gridcolor = "#d0d0d0"),
        yaxis = list(title = "Survival Probability", gridcolor = "#d0d0d0",
                     tickformat = ".0%"),
        paper_bgcolor = "#F5F7E8",
        plot_bgcolor = "#ffffff",
        font = list(family = "Figtree"),
        hovermode = "x unified",
        legend = list(title = list(text = f))
      )
  })
  
  output$forestPlot <- renderPlot({
    cox <- cox_os
    cox$Factor <- factor(cox$Factor, levels = cox$Factor[order(cox$HR)])
    cox$Significant <- ifelse(cox$p_value < 0.05, "p < 0.05", "p >= 0.05")

    ggplot(cox, aes(x = HR, y = Factor, color = Significant)) +
      geom_point(size = 3) +
      geom_errorbarh(aes(xmin = CI_lower, xmax = CI_upper), height = 0.2) +
      geom_vline(xintercept = 1, linetype = "dashed", color = "#B85450") +
      scale_color_manual(values = c("p < 0.05" = "#6B8F5E",
                                     "p >= 0.05" = "#8E8BAE")) +
      scale_x_continuous(breaks = scales::pretty_breaks()) +
      labs(title = "Forest Plot — Hazard Ratios",
           subtitle = "HR < 1 = Protective (longer survival)   |   HR > 1 = Risk (shorter survival)\nDashed line: HR = 1 (no effect)",
           x = "Hazard Ratio (95% CI)",
           y = "",
           color = "Significance") +
      theme_minimal(base_size = 14) +
      theme(text = element_text(family = "Figtree"),
            plot.background = element_rect(fill = "#F5F7E8", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA),
            panel.grid.major = element_line(color = "#C5C8B8"),
            legend.position = "bottom",
            axis.text.y = element_text(size = 11))
  }, res = 120)

  output$factor_clinical_box <- renderUI({
    f <- rv$selected_factor
    
    # ---- Pre-compute all factor values for dynamic lookup ----
    hr_all <- setNames(round(cox_os$HR, 2), cox_os$Factor)
    ci_l_all <- setNames(round(cox_os$CI_lower, 2), cox_os$Factor)
    ci_u_all <- setNames(round(cox_os$CI_upper, 2), cox_os$Factor)
    pv_all <- setNames(cox_os$p_value, cox_os$Factor)
    rdiff_all <- setNames(round(rmst$RMST_Diff_Days), rmst$Factor)
    rpv_all <- setNames(rmst$P_value, rmst$Factor)
    vtot_all <- setNames(round(var_summary$Variance_Pct, 1), var_summary$Factor)
    vrna_all <- setNames(round(var_summary$RNA, 1), var_summary$Factor)
    vmeth_all <- setNames(round(var_summary$Methyl, 1), var_summary$Factor)
    vrppa_all <- setNames(round(var_summary$RPPA, 1), var_summary$Factor)
    
    fmt_p <- function(x) {
      if (is.na(x)) return("NA")
      if (x < 0.001) return("p < 0.001")
      if (x < 0.01) return(paste0("p = ", sprintf("%.3f", x)))
      return(paste0("p = ", sprintf("%.2f", x)))
    }
    
    # ---- Badge for current factor ----
    hr <- hr_all[f]
    pv <- pv_all[f]
    rdiff <- rdiff_all[f]
    rpv <- rpv_all[f]
    
    is_prot <- hr < 0.9 & pv < 0.1
    is_risk <- hr > 1.1 & pv < 0.1
    is_delayed <- abs(rdiff) > 50 & rpv < 0.1 & !is_prot & !is_risk
    
    badge <- if (is_prot) {
      list(text = "PROTECTIVE", bg = "#059669")
    } else if (is_risk) {
      list(text = "RISK FACTOR", bg = "#dc2626")
    } else if (is_delayed) {
      list(text = "DELAYED PROTECTION", bg = "#0e7490")
    } else {
      list(text = "NEUTRAL", bg = "#6b7280")
    }
    
    # ---- Factor-specific narrative ----
    clinical_notes <- list(
      "Factor1" = list(
        subtitle = "Basal / Immune Program",
        summary = sprintf("Factor 1 is the dominant multi-omic pattern in breast cancer, explaining %.1f%% of all coordinated molecular variation. It captures the biology of aggressive, basal-like (triple-negative) tumors which is a program involving the tumor's structural scaffolding (extracellular matrix remodeling), cell adhesion changes and immune signaling.", vtot_all[["Factor1"]]),
        clinical = "This factor is more active in tumors that are ER-negative (r = \u20130.16, p < 0.001) and of the Basal-like PAM50 subtype (r = \u20130.21, p < 0.001) which are the most aggressive breast cancers and lack hormone receptors and HER2 amplification. There is a weak association with younger age at diagnosis (r = \u20130.10, p = 0.05).",
        survival = sprintf("Despite capturing aggressive tumor biology, Factor 1 does NOT independently predict survival. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). The RMST difference is %+d days (%s) which is not statistically significant. This means the aggressive features Factor 1 captures are already assessed by standard clinical evaluation (subtype, grade, stage) and do not add independent prognostic information.", hr_all[["Factor1"]], fmt_p(pv_all[["Factor1"]]), ci_l_all[["Factor1"]], ci_u_all[["Factor1"]], rdiff_all[["Factor1"]], fmt_p(rpv_all[["Factor1"]])),
        omics = sprintf("Factor 1 is the most 'multi-omic' factor, that is, it draws signal from all three data types: RNA (%.1f%%), DNA methylation (%.1f%%), and protein/RPPA (%.1f%%). Top RNA markers include GABRP, C4orf7, STAC2, SAA1, and KRT14. Protein-level signature: low ER-alpha, low GATA3, low INPP4B. These are all consistent with ER-negative, basal-like biology. Key biological pathways involve cell-cell adhesion regulation, JAK-STAT immune signaling and extracellular matrix organization.", vrna_all[["Factor1"]], vmeth_all[["Factor1"]], vrppa_all[["Factor1"]]),
        bottom = "Describes the biology of aggressive breast cancers but does not independently predict outcomes. It is a descriptive biological factor, not a prognostic one."
      ),
      "Factor2" = list(
        subtitle = "Luminal / Hormone Program",
        summary = sprintf("Factor 2 represents the luminal, hormone-driven program, explaining %.1f%% of multi-omic variation. It is active in ER-positive, slow-growing tumors that retain features of normal breast tissue. This factor draws from both RNA expression (%.1f%%) and protein signaling (%.1f%%) pathways.", vtot_all[["Factor2"]], vrna_all[["Factor2"]], vrppa_all[["Factor2"]]),
        clinical = "This factor is more active in ER-positive tumors (r = +0.19, p < 0.001) and the Luminal PAM50 subtype (r = +0.36, p < 0.001) which are the most common and least aggressive form of breast cancer. No significant association with age or sex.",
        survival = sprintf("No significant survival effect despite association with favorable luminal biology. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). The expected protective effect of ER-positive, luminal status is evident in clinical practice but is not independently captured by this factor's molecular score in the Cox model.", hr_all[["Factor2"]], fmt_p(pv_all[["Factor2"]]), ci_l_all[["Factor2"]], ci_u_all[["Factor2"]], rdiff_all[["Factor2"]], fmt_p(rpv_all[["Factor2"]])),
        omics = sprintf("Primarily driven by RNA (%.1f%%) and protein/RPPA (%.1f%%) with minimal methylation contribution (%.1f%%). Top RNA markers: PTPRT, TUSC5, ATP1A2, NOVA1, ACTL8. Key proteins include ER-alpha, GATA3, and PR representing the classic hormone receptor pathway.", vrna_all[["Factor2"]], vrppa_all[["Factor2"]], vmeth_all[["Factor2"]]),
        bottom = "Captures the biology of ER-positive, luminal breast cancer but does not independently predict survival beyond standard clinical subtyping."
      ),
      "Factor3" = list(
        subtitle = "Methylation-Driven (Biologically Silent)",
        summary = sprintf("Factor 3 is a pure DNA methylation program, explaining %.1f%% of variation. It is almost entirely driven by methylation changes (%.1f%% of its signal comes from DNA methylation, with virtually no RNA or protein contribution). This factor has no association with any known clinical variable, suggesting it captures coordinated methylation at a set of CpG islands that are biologically independent of breast cancer subtype or patient characteristics.", vtot_all[["Factor3"]], vmeth_all[["Factor3"]]),
        clinical = "No significant associations with age, ER status, PAM50 subtype, or sex (all p > 0.1). This factor is completely independent of standard clinical and molecular classifications.",
        survival = sprintf("No survival effect whatsoever. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). This factor appears to be biologically neutral with respect to patient outcomes.", hr_all[["Factor3"]], fmt_p(pv_all[["Factor3"]]), ci_l_all[["Factor3"]], ci_u_all[["Factor3"]], rdiff_all[["Factor3"]], fmt_p(rpv_all[["Factor3"]])),
        omics = sprintf("Nearly pure methylation factor: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA features: C8orf42, HTR2C, CNTNAP4. The methylation probes involved are at CpG islands whose biological function remains unknown.", vrna_all[["Factor3"]], vmeth_all[["Factor3"]], vrppa_all[["Factor3"]]),
        bottom = "A biologically silent methylation pattern with no link to clinical variables or survival that likely reflects stochastic epigenetic variation or technical noise."
      ),
      "Factor4" = list(
        subtitle = "Age-Related Methylation",
        summary = sprintf("Factor 4 captures age-dependent epigenetic changes in the breast tumor microenvironment, explaining %.1f%% of total variation. It is primarily methylation-driven (%.1f%% of signal), representing coordinated DNA methylation changes that accumulate with age.", vtot_all[["Factor4"]], vmeth_all[["Factor4"]]),
        clinical = "Strongest association is with younger age at diagnosis (r = \u20130.22, p < 0.001) \u2014 higher Factor 4 scores are seen in younger patients. Also associated with female sex (r = +0.16, p < 0.001) and weakly with ER-positive status (r = +0.13, p = 0.001) and Luminal subtype (r = +0.08, p = 0.03).",
        survival = sprintf("No significant survival effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). Unlike earlier exploratory analyses, the scaled model does not show a risk trend for this factor, suggesting age-related methylation alone does not independently affect survival.", hr_all[["Factor4"]], fmt_p(pv_all[["Factor4"]]), ci_l_all[["Factor4"]], ci_u_all[["Factor4"]], rdiff_all[["Factor4"]], fmt_p(rpv_all[["Factor4"]])),
        omics = sprintf("Primarily methylation-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA features: TMEM179, ZNF692, BEX4, CHKB-CPT1B, PBX3.", vrna_all[["Factor4"]], vmeth_all[["Factor4"]], vrppa_all[["Factor4"]]),
        bottom = "Reflects age-related DNA methylation changes but does not independently predict survival outcomes."
      ),
      "Factor5" = list(
        subtitle = "Immune Checkpoint (Protective Signature)",
        summary = sprintf("Factor 5 is the most clinically important finding making it a protective immune signature that predicts better survival. It explains %.1f%% of multi-omic variation and captures active T-cell anti-tumor immunity. This is the only factor with statistically significant protective effects across multiple analyses.", vtot_all[["Factor5"]]),
        clinical = "Notably, Factor 5 shows NO significant association with age, ER status, PAM50 subtype, or sex (all p > 0.2). This is a key finding: the protective immune effect is INDEPENDENT of breast cancer subtype. Some Luminal tumors have it, some Basal tumors lack it, therefore, standard clinical classification (ER/PR/HER2) completely misses this immune variation.",
        survival = sprintf("STATISTICALLY SIGNIFICANT protective effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). Patients with a 1-unit higher Factor 5 score have %.0f%% lower risk of death at any moment. The effect persists and is even stronger after adjusting for age and stage (adjusted HR = 0.63, p = 0.004). RMST difference: %+d days (%s) which is directionally consistent but underpowered for this metric.", hr_all[["Factor5"]], fmt_p(pv_all[["Factor5"]]), ci_l_all[["Factor5"]], ci_u_all[["Factor5"]], (1 - hr_all[["Factor5"]]) * 100, rdiff_all[["Factor5"]], fmt_p(rpv_all[["Factor5"]])),
        omics = sprintf("Balanced multi-omic signal: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. The top RNA features tell a compelling story: TIGIT (immune checkpoint), ICOS (T-cell activation), ZAP70 (T-cell signaling), SIRPG (immune synapse), and PLA2G2D (inflammation). These are classic markers of active T-cell immunity. Protein features include cleaved caspase-7 (apoptosis) and Lck (T-cell signaling).", vrna_all[["Factor5"]], vmeth_all[["Factor5"]], vrppa_all[["Factor5"]]),
        bottom = "THE KEY CLINICAL FINDING: An immune checkpoint signature that independently predicts better survival, regardless of breast cancer subtype. If validated, a 5-gene test (TIGIT, ICOS, ZAP70, SIRPG, PLA2G2D) could identify patients who might benefit from immunotherapy."
      ),
      "Factor6" = list(
        subtitle = "Luminal / Proliferation Program",
        summary = sprintf("Factor 6 captures a luminal biology program with a proliferation component, explaining %.1f%% of variation. It is almost entirely RNA-driven (%.1f%%), representing gene expression changes in ER-positive, luminal tumors.", vtot_all[["Factor6"]], vrna_all[["Factor6"]]),
        clinical = "Very strongly associated with ER-positive status (r = +0.42, p < 0.001), Luminal PAM50 subtype (r = +0.46, p < 0.001), and female sex (r = +0.49, p < 0.001). This factor is essentially a molecular signature of ER+ luminal breast cancer biology.",
        survival = sprintf("No significant survival effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). Despite being a clear biological signal, this factor does not stratify patients by prognosis.", hr_all[["Factor6"]], fmt_p(pv_all[["Factor6"]]), ci_l_all[["Factor6"]], ci_u_all[["Factor6"]], rdiff_all[["Factor6"]], fmt_p(rpv_all[["Factor6"]])),
        omics = sprintf("Almost purely RNA-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA features: IL6ST (IL-6 signaling), GAS2L3 (cell cycle), DDI2, ASXL2, N4BP2. The protein features include cIAP (anti-apoptosis), MEK1 (proliferation signaling), and p27 (cell cycle regulation).", vrna_all[["Factor6"]], vmeth_all[["Factor6"]], vrppa_all[["Factor6"]]),
        bottom = "A descriptive molecular signature of ER-positive luminal breast cancer that confirms the biology but does not add prognostic value beyond standard subtyping."
      ),
      "Factor7" = list(
        subtitle = "Delayed Protection (RMST-Detected)",
        summary = sprintf("Factor 7 shows a unique survival pattern: it has no significant Cox effect but is the ONLY factor with statistically significant RMST (restricted mean survival time) benefit. This paradox occurs because Factor 7's protective effect is DELAYED. It appears only after several years of follow-up, which Cox regression (measuring instantaneous risk) misses, but RMST (measuring cumulative survival time) captures.", vtot_all[["Factor7"]]),
        clinical = "More active in ER-negative tumors (r = \u20130.16, p < 0.001) and non-luminal (basal-like) subtypes (r = \u20130.17, p < 0.001). Also associated with male/female differences (r = \u20130.19, p < 0.001). Associated with the aggressive tumor types, yet counterintuitively protective for survival.",
        survival = sprintf("Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f) which is not significant by standard Cox analysis. HOWEVER, the RMST difference is %+d days (%s) making it the ONLY statistically significant RMST benefit across all 15 factors. Patients with high Factor 7 live approximately %d days longer within 5 years. This delayed protective effect would be completely missed if only Cox regression were used.", hr_all[["Factor7"]], fmt_p(pv_all[["Factor7"]]), ci_l_all[["Factor7"]], ci_u_all[["Factor7"]], rdiff_all[["Factor7"]], fmt_p(rpv_all[["Factor7"]]), abs(rdiff_all[["Factor7"]])),
        omics = sprintf("Moderate multi-omic signal: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: PPAPDC1A, COL10A1, EPYC, FN1 (fibronectin), FNDC1 which are the genes involved in extracellular matrix and tissue remodeling. Protein-level features include anti-apoptotic Bcl-2 and activated Akt survival signaling.", vrna_all[["Factor7"]], vmeth_all[["Factor7"]], vrppa_all[["Factor7"]]),
        bottom = "A biologically intriguing delayed protective effect that standard Cox regression would miss. Factor 7 demonstrates why using multiple statistical approaches (Cox + RMST) is essential for discovering all survival-relevant biology."
      ),
      "Factor8" = list(
        subtitle = "Methylation-Driven Risk Factor",
        summary = sprintf("Factor 8 is a statistically significant risk factor, explaining %.1f%% of multi-omic variation. Patients with higher scores have worse survival. It draws from both RNA (%.1f%%) and DNA methylation (%.1f%%), suggesting a mixed mechanism involving epigenetic silencing and gene expression changes.", vtot_all[["Factor8"]], vrna_all[["Factor8"]], vmeth_all[["Factor8"]]),
        clinical = "Weakly associated with younger age (r = \u20130.12, p = 0.02) and non-luminal PAM50 subtypes (r = +0.10, p = 0.009). Not significantly associated with ER status. This pattern is more active in younger patients with non-luminal breast cancers.",
        survival = sprintf("STATISTICALLY SIGNIFICANT risk effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). Patients with a 1-unit higher Factor 8 score have %.0f%% higher mortality risk. The effect persists after adjusting for age and stage (adjusted HR = 1.30, p = 0.024). RMST: %+d days (%s).", hr_all[["Factor8"]], fmt_p(pv_all[["Factor8"]]), ci_l_all[["Factor8"]], ci_u_all[["Factor8"]], (hr_all[["Factor8"]] - 1) * 100, rdiff_all[["Factor8"]], fmt_p(rpv_all[["Factor8"]])),
        omics = sprintf("Balanced RNA/methylation signal: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: CFB (complement factor B), ADRA2C (adrenergic receptor), TTC22, MSI1, CLEC5A. Protein-level features include DUSP4 (MAPK phosphatase), PDCD4 (tumor suppressor), and 4E-BP1 (translation regulator).", vrna_all[["Factor8"]], vmeth_all[["Factor8"]], vrppa_all[["Factor8"]]),
        bottom = "A confirmed risk factor (significant in both adjusted and unadjusted models) that may reflect a pro-inflammatory or stress-response program associated with worse outcomes in younger patients."
      ),
      "Factor9" = list(
        subtitle = "Mixed Clinical Profile",
        summary = sprintf("Factor 9 shows a complex clinical profile, explaining %.1f%% of variation. It is associated with multiple clinical variables, suggesting it captures a broader, more heterogeneous biological program.", vtot_all[["Factor9"]]),
        clinical = "More active in younger patients (r = \u20130.15, p = 0.002), males (r = \u20130.23, p < 0.001), ER-negative tumors (r = \u20130.13, p = 0.001), and non-luminal subtypes (r = \u20130.18, p < 0.001). This pattern is most prominent in younger patients with aggressive, non-hormone-driven tumors.",
        survival = sprintf("No significant survival effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). Despite its broad clinical associations, Factor 9 does not independently predict survival.", hr_all[["Factor9"]], fmt_p(pv_all[["Factor9"]]), ci_l_all[["Factor9"]], ci_u_all[["Factor9"]], rdiff_all[["Factor9"]], fmt_p(rpv_all[["Factor9"]])),
        omics = sprintf("Primarily RNA-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: TFAP2B, CPNE7, GGT6, F7, COL10A1. Protein features include VEGFR2 (angiogenesis), E-Cadherin (cell adhesion), and beta-Catenin (Wnt signaling) which are consistent with a tumor microenvironment and invasion program.", vrna_all[["Factor9"]], vmeth_all[["Factor9"]], vrppa_all[["Factor9"]]),
        bottom = "A descriptive factor with broad clinical associations but no independent prognostic value. Reflects the complex biology of heterogeneous breast tumors."
      ),
      "Factor10" = list(
        subtitle = "Luminal-Associated Risk Factor",
        summary = sprintf("Factor 10 is a STATISTICALLY SIGNIFICANT risk factor that paradoxically associates with favorable Luminal biology. It explains %.1f%% of variation and is primarily RNA-driven. This factor captures a more aggressive subset within ER-positive, Luminal breast cancer.", vtot_all[["Factor10"]]),
        clinical = "Exceptionally strong associations with female sex (r = +0.63, p < 0.001), ER-positive status (r = +0.51, p < 0.001), and Luminal PAM50 subtype (r = +0.54, p < 0.001). These are the strongest clinical correlations of any factor. No association with age.",
        survival = sprintf("SIGNIFICANT RISK EFFECT. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). Patients with a 1-unit higher Factor 10 score have %.0f%% higher mortality risk, with a borderline-adjusted effect (adjusted HR = 1.30, p = 0.065). RMST difference: %+d days (%s). Despite correlating with favorable Luminal biology, this factor identifies higher-risk patients within that group, possibly Luminal B tumors.", hr_all[["Factor10"]], fmt_p(pv_all[["Factor10"]]), ci_l_all[["Factor10"]], ci_u_all[["Factor10"]], (hr_all[["Factor10"]] - 1) * 100, rdiff_all[["Factor10"]], fmt_p(rpv_all[["Factor10"]])),
        omics = sprintf("Nearly pure RNA-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: C19orf20, COL7A1 (collagen), WNT9A (Wnt signaling), SH3D20. The WNT9A and COL7A1 features suggest an extracellular matrix / developmental signaling component that may drive aggressiveness within ER-positive disease.", vrna_all[["Factor10"]], vmeth_all[["Factor10"]], vrppa_all[["Factor10"]]),
        bottom = "A confirmed risk factor that identifies aggressive tumors hiding within Luminal breast cancers. The WNT9A and COL7A1 signal may point to a developmental or EMT-like program driving worse outcomes in otherwise favorable ER-positive disease."
      ),
      "Factor11" = list(
        subtitle = "Protective Methylation Factor",
        summary = sprintf("Factor 11 shows a borderline protective effect despite being primarily methylation-driven (%.1f%% of signal). This is unusual because methylation factors are typically neutral or risk-associated. Explains %.1f%% of total variation.", vmeth_all[["Factor11"]], vtot_all[["Factor11"]]),
        clinical = "Moderately associated with female sex (r = +0.25, p < 0.001), ER-positive status (r = +0.21, p < 0.001), and Luminal PAM50 subtype (r = +0.23, p < 0.001). No significant age association. Its protective trend is consistent with its association with favorable luminal biology.",
        survival = sprintf("Borderline PROTECTIVE effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). The effect approaches significance and aligns with Factor 11's association with ER-positive, luminal tumors. The protective signal is modest but consistent across both Cox and RMST metrics.", hr_all[["Factor11"]], fmt_p(pv_all[["Factor11"]]), ci_l_all[["Factor11"]], ci_u_all[["Factor11"]], rdiff_all[["Factor11"]], fmt_p(rpv_all[["Factor11"]])),
        omics = sprintf("Primarily methylation-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: TBC1D1, EIF2AK2 (PKR), MGA, TSSC4, PDSS2. Protein features include FoxM1 (proliferation), P-Cadherin, and IGF1R signaling.", vrna_all[["Factor11"]], vmeth_all[["Factor11"]], vrppa_all[["Factor11"]]),
        bottom = "An unusual methylation factor with a borderline protective trend. Most methylation factors are neutral or risk-associated, making this pattern worth further investigation."
      ),
      "Factor12" = list(
        subtitle = "ER-Negative Associated Methylation",
        summary = sprintf("Factor 12 is a methylation-driven factor (%.1f%% of signal) that is more active in ER-negative breast cancers. Explains %.1f%% of total variation and may represent a distinct epigenetic subtype of hormone-receptor-negative disease.", vmeth_all[["Factor12"]], vtot_all[["Factor12"]]),
        clinical = "Negatively associated with ER-positive status (r = \u20130.22, p < 0.001), female sex (r = \u20130.17, p < 0.001), and Luminal subtype (r = \u20130.13, p = 0.001). More active in ER-negative, non-luminal tumors.",
        survival = sprintf("Non-significant risk trend. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). The direction is consistent with worse outcomes, aligning with the known poorer prognosis of ER-negative tumors.", hr_all[["Factor12"]], fmt_p(pv_all[["Factor12"]]), ci_l_all[["Factor12"]], ci_u_all[["Factor12"]], rdiff_all[["Factor12"]], fmt_p(rpv_all[["Factor12"]])),
        omics = sprintf("Primarily methylation-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: RPL13AP3, PPIAL4C, ZNF205, RPS18 which are predominantly ribosomal protein pseudogenes and may reflect epigenetic dysregulation of translation machinery in aggressive tumors.", vrna_all[["Factor12"]], vmeth_all[["Factor12"]], vrppa_all[["Factor12"]]),
        bottom = "Captures epigenetically distinct ER-negative breast cancers. The predominance of ribosomal pseudogenes among its top RNA features is intriguing and warrants further study."
      ),
      "Factor13" = list(
        subtitle = "LASSO-Selected Risk Factor",
        summary = sprintf("Factor 13 is a STATISTICALLY SIGNIFICANT risk factor in the scaled analysis, explaining %.1f%% of variation. It is largely methylation-driven (%.1f%% of signal) and was identified as the top predictor by LASSO regression.", vtot_all[["Factor13"]], vmeth_all[["Factor13"]]),
        clinical = "Only a weak positive correlation with PAM50 luminal markers (r = +0.09, p = 0.02). No significant associations with age, sex, or ER status. Essentially independent of known clinical variables, yet it carries a clear risk signal.",
        survival = sprintf("STATISTICALLY SIGNIFICANT risk effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). Patients with a 1-unit higher Factor 13 score have %.0f%% higher mortality risk. The effect is borderline in adjusted analysis (adjusted HR = 1.30, p = 0.077), suggesting some confounding with clinical variables. RMST: %+d days (%s). LASSO also identified Factor 13 as the single most important predictor, confirming this is a robust risk signal despite weak clinical correlations.", hr_all[["Factor13"]], fmt_p(pv_all[["Factor13"]]), ci_l_all[["Factor13"]], ci_u_all[["Factor13"]], (hr_all[["Factor13"]] - 1) * 100, rdiff_all[["Factor13"]], fmt_p(rpv_all[["Factor13"]])),
        omics = sprintf("Mixed methylation/RPPA signal: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: TEX28, OR2T10, SNORA42 (snoRNA), TSPY1, SULT6B1. Protein features include GAPDH, GATA6, GATA3, and PR which are mixed lineage markers.", vrna_all[["Factor13"]], vmeth_all[["Factor13"]], vrppa_all[["Factor13"]]),
        bottom = "A confirmed risk factor validated by both Cox regression and LASSO. Its lack of strong clinical correlations suggests it captures a novel biological risk pathway distinct from known clinical markers."
      ),
      "Factor14" = list(
        subtitle = "Top RSF Risk Factor (Methylation-Driven)",
        summary = sprintf("Factor 14 is the most important factor in the Random Survival Forest (RSF) machine learning model AND now shows a statistically significant Cox effect. It explains %.1f%% of variance and is primarily methylation-driven. The convergence of both machine learning and Cox methods confirms its role as a robust risk factor.", vtot_all[["Factor14"]]),
        clinical = "Negatively correlated with Luminal subtype (r = \u20130.14, p < 0.001) and female sex (r = \u20130.16, p < 0.001). Weak negative association with ER status (r = \u20130.07, p = 0.08). More active in non-luminal, potentially basal-like or HER2-enriched tumors.",
        survival = sprintf("STATISTICALLY SIGNIFICANT risk effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f) in the univariate model. The effect is even stronger after adjusting for age and stage (adjusted HR = 1.44, p = 0.017). RMST difference: %+d days (%s). The RSF importance score (%.4f) remains the highest across all factors, and the Cox analysis now independently confirms its significance.", hr_all[["Factor14"]], fmt_p(pv_all[["Factor14"]]), ci_l_all[["Factor14"]], ci_u_all[["Factor14"]], rdiff_all[["Factor14"]], fmt_p(rpv_all[["Factor14"]]), 0.0194),
        omics = sprintf("Primarily methylation-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: SPNS1 (sphingolipid transport), DMXL2, NACA2, MTRF1L, TMOD2. The biological function of this factor remains largely unknown, making it an exciting target for future research.", vrna_all[["Factor14"]], vmeth_all[["Factor14"]], vrppa_all[["Factor14"]]),
        bottom = "THE TOP-RANKED RISK FACTOR across both Cox and RSF analyses. Its methylation-driven nature and unknown biological function make it the highest priority for future investigation. The convergence of two independent analytical methods (Cox + RSF) provides strong evidence this represents an entirely novel prognostic pathway."
      ),
      "Factor15" = list(
        subtitle = "ER-Positive Associated Methylation",
        summary = sprintf("Factor 15 is a methylation-driven factor (%.1f%% of signal) associated with ER-positive breast cancers, explaining %.1f%% of multi-omic variation. Its biological role remains unclear.", vmeth_all[["Factor15"]], vtot_all[["Factor15"]]),
        clinical = "Positively correlated with ER-positive status (r = +0.16, p < 0.001) and weakly with female sex (r = +0.08, p = 0.04). No significant association with age or PAM50 subtype. This methylation pattern is more active in ER+ tumors but does not track with any specific molecular subtype.",
        survival = sprintf("No significant effect. Hazard ratio: HR = %.2f (%s, 95%% CI: %.2f\u2013%.2f). RMST difference: %+d days (%s). Factor 15 appears to be a biologically neutral methylation pattern associated with ER-positive disease.", hr_all[["Factor15"]], fmt_p(pv_all[["Factor15"]]), ci_l_all[["Factor15"]], ci_u_all[["Factor15"]], rdiff_all[["Factor15"]], fmt_p(rpv_all[["Factor15"]])),
        omics = sprintf("Primarily methylation-driven: RNA = %.1f%%, Methylation = %.1f%%, RPPA = %.1f%%. Top RNA: RAB43, MTRF1L, C11orf10, RPL13AP20, ATP13A3. Protein features include Chk2 pT68 (DNA damage checkpoint), SCD, PDCD4, and eEF2 which hints at a stress/DNA damage response component.", vrna_all[["Factor15"]], vmeth_all[["Factor15"]], vrppa_all[["Factor15"]]),
        bottom = "A methylation pattern linked to ER-positive disease with no prognostic impact. Likely represents epigenetic heterogeneity within ER+ breast cancers that does not affect clinical outcomes."
      )
    )
    
    note <- clinical_notes[[f]]
    if (is.null(note)) {
      note <- list(
        subtitle = "",
        summary = "Clinical association data not available for this factor.",
        clinical = "",
        survival = "",
        omics = "",
        bottom = ""
      )
    }
    
    div(id = "clinical-box", style = "background:#F5F7E8;border:1px solid #D5D8C8;border-radius:10px;padding:24px;",
      
      # Header row: title + badge
      div(style = "display:flex;align-items:center;gap:12px;margin-bottom:4px;",
        h4(paste(f, "\u2014", note$subtitle), class = "mt-0 mb-0",
           style = "color:#000000;font-weight:700;font-size:1.15rem;"),
        span(style = paste0("background:", badge$bg, ";color:#ffffff;font-size:0.68rem;font-weight:700;padding:3px 10px;border-radius:20px;text-transform:uppercase;letter-spacing:0.5px;white-space:nowrap;"),
             badge$text)
      ),
      tags$hr(style = "border-color:#D5D8C8;margin:12px 0;"),
      
      # Summary paragraph
      p(style = "color:#1e293b;font-size:0.92rem;line-height:1.7;margin-bottom:14px;", note$summary),
      
      # Two-column: Clinical Profile + Survival Impact
      div(style = "display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:14px;",
        div(style = "background:#EBEED5;border-radius:8px;padding:14px;",
          p(style = "margin:0 0 6px 0;font-weight:700;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.4px;color:#475569;",
            "Clinical Profile"),
          p(style = "margin:0;color:#1e293b;font-size:0.86rem;line-height:1.65;", note$clinical)
        ),
        div(style = "background:#EBEED5;border-radius:8px;padding:14px;",
          p(style = "margin:0 0 6px 0;font-weight:700;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.4px;color:#475569;",
            "Survival Impact"),
          p(style = "margin:0;color:#1e293b;font-size:0.86rem;line-height:1.65;", note$survival)
        )
      ),
      
      # Molecular Drivers
      div(style = "background:#EBEED5;border-radius:8px;padding:14px;margin-bottom:14px;",
        p(style = "margin:0 0 6px 0;font-weight:700;font-size:0.78rem;text-transform:uppercase;letter-spacing:0.4px;color:#475569;",
          "Molecular Drivers"),
        p(style = "margin:0;color:#1e293b;font-size:0.86rem;line-height:1.65;", note$omics)
      ),
      
      # Bottom line with colored accent bar
      div(style = paste0("background:", if (is_prot) "#ecfdf5" else if (is_risk) "#fef2f2" else "#EBEED5", ";border-left:4px solid ", badge$bg, ";border-radius:6px;padding:12px 16px;"),
        p(style = paste0("margin:0;color:", if (is_prot) "#065f46" else if (is_risk) "#991b1b" else "#475569", ";font-size:0.85rem;line-height:1.5;font-weight:500;"),
          note$bottom)
      )
    )
  })
  
  # -- PATIENT MAP --
  output$patientMap <- renderPlot({
    req(input$mapColor)
    if (!"umap_x" %in% colnames(patient_data)) {
      plot.new(); text(0.5, 0.5, "Computing UMAP coordinates... refresh in a moment", cex = 1.5)
      return()
    }
    pd <- patient_data
    pd$subtype[pd$subtype == ""] <- "Unknown"
    color_col <- input$mapColor
    if (color_col == "os_event") {
      pd$os_event <- factor(pd$os_event, levels = c(0, 1), labels = c("Alive", "Deceased"))
    }
    tryCatch({
      p <- ggplot(pd, aes(x = umap_x, y = umap_y, color = .data[[color_col]])) +
        geom_point(size = 2.5, alpha = 0.7) +
        scale_color_manual(
          values = c(
            "LumA" = "#7A70BA", "LumB" = "#B8963E",
            "Basal" = "#B85450", "Her2" = "#9B6EB0",
            "Normal" = "#6B8F5E", "Unknown" = "#8E8BAE",
            "Alive" = "#7A70BA", "Deceased" = "#B85450"
          )
        ) +
        theme_minimal(base_size = 14) +
        labs(title = "Patient Map — UMAP of MOFA Factor Scores",
             x = "UMAP 1", y = "UMAP 2") +
        theme(text = element_text(family = "Figtree"),
              plot.background = element_rect(fill = "#ffffff", color = NA),
              panel.background = element_rect(fill = "#ffffff", color = NA),
              panel.border = element_rect(color = "#d0d0d0", fill = NA),
              legend.position = "bottom")
      p
    }, error = function(e) {
      plot.new(); text(0.5, 0.5, paste("Map error:", e$message), cex = 1.0, col = "#B85450")
    })
  })
  
  output$mapSurvival <- renderPlot({
    if (!"umap_x" %in% colnames(patient_data)) {
      plot.new(); text(0.5, 0.5, "Map coordinates not available", cex = 1.2)
      return()
    }
    if (is.null(input$mapBrush)) {
      plot.new(); text(0.5, 0.5, "Draw a circle on the map above to see survival for the selected group", cex = 1.2)
      return()
    }
    brushed <- brushedPoints(patient_data, input$mapBrush)
    if (nrow(brushed) < 5) {
      plot.new(); text(0.5, 0.5, "Select at least 5 patients to show survival curve", cex = 1.2)
      return()
    }
    tryCatch({
      brushed$os_event <- as.numeric(brushed$os_event)
      brushed$os_time <- as.numeric(brushed$os_time)
      fit <- survfit(Surv(os_time, os_event) ~ 1, data = brushed)
      ggsurvplot(fit, data = brushed, risk.table = FALSE,
                 title = "Survival — Selected Group",
                 xlab = "Days", ylab = "Survival",
                 palette = "#7A70BA", ggtheme = theme_minimal(base_size = 13))$plot +
        theme(text = element_text(family = "Figtree"),
              plot.background = element_rect(fill = "#ffffff", color = NA),
              panel.background = element_rect(fill = "#ffffff", color = NA))
    }, error = function(e) {
      plot.new(); text(0.5, 0.5, paste("Survival error:", e$message), cex = 0.9, col = "#B85450")
    })
  })

  # -- GENE EXPLORER --
  observe({
    all_genes <- unique(unlist(strsplit(top_features$Top_Features, "; ")))
    updateSelectizeInput(session, "gene_search", choices = all_genes, server = TRUE)
  })
  
  gene_factor <- reactive({
    gene <- input$gene_search
    if (is.null(gene) || gene == "") return(NULL)
    
    results <- data.frame()
    for (f in factor_names) {
      feat_row <- top_features[top_features$Factor == f & top_features$View == "RNA", ]
      if (nrow(feat_row) > 0) {
        genes <- unlist(strsplit(feat_row$Top_Features, "; "))
        if (gene %in% genes) {
          cox_row <- cox_os[cox_os$Factor == f, ]
          results <- rbind(results, data.frame(
            factor = f,
            loading = which(genes == gene) / length(genes),
            hr = round(cox_row$HR, 2),
            pval = cox_row$p_value,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
    results
  })
  
  output$gene_hr_badge <- renderUI({
    gf <- gene_factor()
    if (is.null(gf) || nrow(gf) == 0) return(NULL)
    
    best <- gf[which.min(gf$pval), ]
    div(
      h5("Strongest Association:"),
      div(style = paste0("font-size:1.5rem;font-weight:700;",
        ifelse(best$hr < 1, "color:#059669;", "color:#dc2626;")),
        paste0(best$factor, " — HR = ", best$hr)
      )
    )
  })
  
  output$gene_expression_plot <- renderPlotly({
    gene <- input$gene_search
    if (is.null(gene) || gene == "") return(NULL)
    
    f5_score <- patient_data$Factor5
    set.seed(42)
    sim_expr <- f5_score * 0.3 + rnorm(length(f5_score), 0, 0.8)
    sim_expr <- scales::rescale(sim_expr, to = c(0, 15))
    
    subtype <- patient_data$subtype
    subtype[subtype == ""] <- "Unknown"
    plot_df <- data.frame(
      factor5 = f5_score,
      expression = sim_expr,
      subtype = subtype
    )
    
    p <- ggplot(plot_df, aes(x = factor5, y = expression)) +
      geom_point(aes(color = subtype), alpha = 0.5, size = 1.5) +
      geom_smooth(method = "lm", color = "#7A70BA", se = TRUE, alpha = 0.2) +
      scale_color_manual(values = c(
        "LumA" = "#7A70BA", "LumB" = "#B8963E",
        "Basal" = "#B85450", "Her2" = "#9B6EB0",
        "Normal" = "#6B8F5E", "Unknown" = "#8E8BAE"
      )) +
      labs(x = "Factor 5 Score", y = paste0(gene, " Expression (simulated)"),
           color = "Subtype") +
      theme_minimal(base_size = 14) +
      theme(text = element_text(family = "Figtree"),
            plot.background = element_rect(fill = "#F5F7E8", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA),
            legend.position = "bottom")
    
    ggplotly(p, tooltip = c("x", "y", "color")) %>%
      layout(
        paper_bgcolor = "#F5F7E8",
        plot_bgcolor = "#ffffff",
        font = list(family = "Figtree"),
        showlegend = TRUE,
        margin = list(b = 130, l = 60, r = 40, t = 40),
        legend = list(orientation = "h", y = -0.45, x = 0.5, xanchor = "center")
      )
  })
  
  output$all_genes_table <- renderDT({
    datatable(top_features, options = list(
      pageLength = 50, lengthMenu = c(25, 50, 100),
      scrollX = TRUE, searching = TRUE, ordering = TRUE,
      dom = "Bfrtilp",
      columnDefs = list(list(className = "dt-center", targets = "_all"))
    ), rownames = FALSE) %>%
      formatStyle(columns = c("Factor", "View", "Top_Features"), fontSize = "85%")
  })
  
  # -- SURVIVAL SIMULATOR --
  sim_profile <- reactive({
    scores <- sapply(c(5, 7, 8, 10, 13, 14), function(f) {
      input[[paste0("sim_f", f)]] %||% 0
    })
    names(scores) <- paste0("Factor", c(5, 7, 8, 10, 13, 14))
    scores
  })
  
  # Reset to average
  observeEvent(input$reset_sim, {
    for (f in c(5, 7, 8, 10, 13, 14)) {
      updateSliderInput(session, paste0("sim_f", f), value = 0)
    }
  })
  
  # Protective profile
  observeEvent(input$sim_protective, {
    updateSliderInput(session, "sim_f5", value = 2)
    updateSliderInput(session, "sim_f7", value = 1.5)
    updateSliderInput(session, "sim_f8", value = -1)
    updateSliderInput(session, "sim_f10", value = -0.5)
    updateSliderInput(session, "sim_f13", value = -0.5)
    updateSliderInput(session, "sim_f14", value = -1)
  })
  
  # Risk profile
  observeEvent(input$sim_risky, {
    updateSliderInput(session, "sim_f5", value = -1.5)
    updateSliderInput(session, "sim_f7", value = -1)
    updateSliderInput(session, "sim_f8", value = 2)
    updateSliderInput(session, "sim_f10", value = 1.5)
    updateSliderInput(session, "sim_f13", value = 1.5)
    updateSliderInput(session, "sim_f14", value = 2)
  })
  
  # Compute predicted survival
  sim_prediction <- reactive({
    profile <- sim_profile()
    
    full_scores <- setNames(rep(0, 15), factor_names)
    full_scores[names(profile)] <- profile
    
    lp <- sum(cox_coefs * full_scores)
    hr <- exp(lp)
    
    pred_surv <- baseline_surv$surv ^ exp(lp)
    
    # 5-year survival
    idx_5yr <- which.min(abs(baseline_surv$time - 1825))
    surv_5yr <- pred_surv[idx_5yr]
    
    # Median survival
    med_idx <- which(pred_surv <= 0.5)
    med_surv <- if (length(med_idx) > 0) baseline_surv$time[med_idx[1]] else NA
    
    list(
      lp = lp,
      hr = hr,
      time = baseline_surv$time,
      surv = pred_surv,
      surv_5yr = surv_5yr,
      median_surv = med_surv
    )
  })
  
  output$sim_5yr_surv <- renderText({
    s <- sim_prediction()$surv_5yr
    paste0(round(s * 100, 1), "%")
  })
  
  output$sim_median_surv <- renderText({
    m <- sim_prediction()$median_surv
    if (is.na(m)) ">1825" else as.character(round(m))
  })
  
  output$sim_hr_display <- renderText({
    hr <- sim_prediction()$hr
    paste0(round(hr, 2), "×")
  })

  # Animate sim results on slider release
  observeEvent(sim_profile(), {
    pred <- sim_prediction()
    session$sendCustomMessage("animate-sim-results", list(
      surv_5yr = paste0(round(pred$surv_5yr * 100, 1), "%"),
      median_surv = if (is.na(pred$median_surv)) ">1825" else as.character(round(pred$median_surv)),
      hr_display = paste0(round(pred$hr, 2), "×")
    ))
  })
  
  output$sim_km_plot <- renderPlotly({
    pred <- sim_prediction()
    
    plot_df <- data.frame(
      time = pred$time,
      surv = pred$surv,
      type = "Your Patient"
    )
    ref_df <- data.frame(
      time = ref_km$time,
      surv = ref_km$surv,
      type = "Average Patient"
    )
    combined <- rbind(plot_df, ref_df)
    
    p <- plot_ly() %>%
      add_lines(data = combined[combined$type == "Average Patient", ],
                x = ~time, y = ~surv,
                name = "Average Patient",
                line = list(color = "#94a3b8", width = 2, dash = "dash"),
                hovertemplate = "Time: %{x} days<br>Survival: %{y:.1%}<extra>Average</extra>") %>%
      add_lines(data = combined[combined$type == "Your Patient", ],
                x = ~time, y = ~surv,
                name = "Your Patient",
                line = list(color = "#7A70BA", width = 3),
                hovertemplate = "Time: %{x} days<br>Survival: %{y:.1%}<extra>Your Patient</extra>") %>%
      layout(
        xaxis = list(title = "Time (days)", gridcolor = "#d0d0d0",
                     range = c(0, max(combined$time, na.rm = TRUE))),
        yaxis = list(title = "Survival Probability", gridcolor = "#d0d0d0",
                     tickformat = ".0%", range = c(0, 1)),
        paper_bgcolor = "#F5F7E8",
        plot_bgcolor = "#ffffff",
        font = list(family = "Figtree"),
        hovermode = "x unified",
        legend = list(x = 0.02, y = 0.02)
      )
    
    # Add 5-year reference line
    p <- p %>%
      add_segments(x = 1825, xend = 1825, y = 0, yend = 1,
                   line = list(color = "#fbbf24", width = 1, dash = "dot"),
                   showlegend = FALSE,
                   hovertemplate = "5 years<extra></extra>")
    
    p
  })
  
  # -- SIDEBAR CONTROL --
  observeEvent(input$sidebar_menu, {
    if (input$sidebar_menu == "story") {
      session$sendCustomMessage("show-story", "")
    } else {
      session$sendCustomMessage("show-dashboard", "")
    }
  })
}

# ---- 4. RUN ----
cat("DIAG: calling shinyApp(ui, server)\n")
shinyApp(ui, server)
cat("DIAG: after shinyApp - should not print (blocking)\n")
