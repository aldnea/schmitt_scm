################################################################################
# Partial R Port of Magness & Makovi (2023)
# "The Mainstreaming of Marx: Measuring the Effect of the Russian Revolution
#  on Karl Marx's Influence"
#
# Original Stata code by Michael Makovi
# R port adapted to read ngram data from a single CSV file
#
# REQUIREMENTS:
#   install.packages(c("here", "Synth", "tidyverse", "writexl"
#   "parallel","future.apply","progressr"))
#
# INPUT:
#   ../schmitt_scm/data/processed/ngram_clean_schmitt.csv
#   - First column: "year"
#   - First row: author names (capitalized, spaces between first/last)
#   - Cell values: ngram citation counts (English)
#   ../schmitt_scm/data/processed/author_labels_schmitt.csv
#
# This script performs the synthetic control method (SCM) analysis and
# calculates the joint post-std p-value.
# It writes the per-year treated Ngram frequency, per-year synthetic Ngram
# frequency, per-year gap, per-year percent difference, list of donor weights,
# v-weights by predictor, balance table comparing treated and synthetic by
# predictor, joint post-std p-value, and post/pre RMSPE ratios by author to
# ../schmitt_scm/results/Treatment_[YEAR]/synth_results_[YEAR].xlsx).
# It outputs a graph comparing the actual and synthetic Ngram frequency over
# the window from the beginning of the pre-treatment period to the end of the
# post-treatment period to
# ../schmitt_scm/results/Treatment_[YEAR]/synth_plot_[YEAR].pdf)
#
# This ports the core analysis from
# "2_marx_synthetic_control_perform_synth.do", using the R `Synth` package
# (which implements the same Abadie, Diamond & Hainmueller method as Stata's
# `synth`, but does not have the same list of available optimizers).
################################################################################

# ==============================================================================
# 0. SETUP
# ==============================================================================

library(here)
library(tidyverse)
library(Synth)
library(writexl)
library(parallel)
library(future.apply)
library(progressr)

handlers(global = TRUE)

set.seed(8675309)

# Create results directory
results_dir <- here("results")
dir.create(results_dir, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# 1. AUTHOR METADATA
# ==============================================================================
# Load from the author indicators CSV (one row per author).
# Columns: Name, Year (ignored), Political, ConservativeRevolution, OriginalLanguage,
#           wrote_English, wrote_German, wrote_French, wrote_Spanish,
#           wrote_Italian, wrote_Greek, wrote_Latin,
#           YearofPublication, YearofTranslationtoEnglish

metadata_file <- here("data", "processed", "author_labels_schmitt.csv")
cat("Loading author metadata from:", metadata_file, "\n")

author_metadata <- read.csv(metadata_file, stringsAsFactors = FALSE) %>%
    distinct(Name, .keep_all = TRUE) %>%        # De-duplicate if needed
    mutate(
        Name = str_replace_all(Name, "\\.", ""),
        Name = str_replace_all(Name, "-", ""),
        Name = str_squish(Name)
    )

# ==============================================================================
# 2. LOAD AND RESHAPE NGRAM DATA
# ==============================================================================

ngram_file <- here("data", "processed", "ngram_clean_schmitt.csv")
cat("Loading ngram data from:", ngram_file, "\n")

ngram_wide <- read.csv(ngram_file, check.names = FALSE)

# The first column should be "year"; all others are author names
# Reshape from wide to long
year_col <- names(ngram_wide)[1]
author_cols <- names(ngram_wide)[-1]

ngram_long <- ngram_wide %>%
    pivot_longer(
        cols = all_of(author_cols),
        names_to = "Name",
        values_to = "cite_English"
    ) %>%
    rename(Year = all_of(year_col))

# Clean up names: remove extra spaces, dots, hyphens
ngram_long <- ngram_long %>%
    mutate(
        Name = str_replace_all(Name, "\\.", ""),
        Name = str_replace_all(Name, "-", ""),
        Name = str_squish(Name)
    )

# Replace NAs with 0
ngram_long <- ngram_long %>%
    mutate(cite_English = replace_na(cite_English, 0))

cat("Loaded", n_distinct(ngram_long$Name), "authors,",
    n_distinct(ngram_long$Year), "years\n")

# ==============================================================================
# 3. MERGE NGRAM DATA WITH AUTHOR METADATA
# ==============================================================================

# Clean metadata names the same way
author_metadata <- author_metadata %>%
    mutate(
        Name = str_replace_all(Name, "\\.", ""),
        Name = str_replace_all(Name, "-", ""),
        Name = str_squish(Name)
    )

# Merge
panel <- ngram_long %>%
    inner_join(author_metadata, by = "Name")

cat("After merge:", n_distinct(panel$Name), "authors matched\n")

# Check which authors from the list were NOT matched
requested_authors <- author_metadata$Name
matched_authors <- unique(panel$Name)
unmatched <- setdiff(requested_authors, matched_authors)
if (length(unmatched) > 0) {
    cat("WARNING: The following authors from metadata were NOT found in ngram CSV:\n")
    cat(paste(" -", unmatched, collapse = "\n"), "\n")
}

# ==============================================================================
# 4. HELPER FUNCTIONS
# ==============================================================================

minmax_normalize <- function(x) {
  mn <- min(x, na.rm = TRUE)
  mx <- max(x, na.rm = TRUE)
  if (mx == mn) return(rep(0, length(x)))
  (x - mn) / (mx - mn)
}

#' Normalize key variables in the panel to [0,1] (min-max)
normalize_panel <- function(df) {
    stopifnot(min(df$cite_English, na.rm = TRUE) == 0)
    df$cite_English <- df$cite_English / max(df$cite_English, na.rm = TRUE)
    for (v in c("YearofPublication", "YearofTranslationtoEnglish")) {
        if (v %in% names(df) && any(!is.na(df[[v]]))) {
            df[[v]] <- minmax_normalize(df[[v]])
        }
    }
    df
}

#' Assign numeric IDs to authors for Synth
assign_ids <- function(df) {
    authors <- sort(unique(df$Name))
    id_map <- tibble(Name = authors, unit_id = seq_along(authors))
    df %>% left_join(id_map, by = "Name")
}

#' Run a single synthetic control and return the synth output
#' This wraps the Synth::synth() function
run_synth <- function(df, treated_name, treatment_year, pre_start,
                      pre_end, post_end, outcome_var = "cite_English",
                      predictors = NULL,
                      special_predictors = NULL) {

    # Assign IDs
    df <- assign_ids(df)

    treated_id <- df %>% filter(Name == treated_name) %>% pull(unit_id) %>% unique()
    control_ids <- df %>% filter(Name != treated_name) %>% pull(unit_id) %>% unique()

    if (length(treated_id) == 0) stop("Treated unit '", treated_name, "' not found in data")
    if (length(control_ids) == 0) stop("No control units available")

    # Default predictors
    if (is.null(predictors)) {
        predictors <- c("YearofPublication",
                        "wrote_English", "wrote_German", "wrote_French",
                        "wrote_Greek", "wrote_Latin", "wrote_Italian",
                        "wrote_Spanish",
                        "YearofTranslationtoEnglish", "ConservativeRevolution", "Political")
    }

    # Default special predictors: outcome averaged in 3-year windows
    # Only include windows that fall entirely within the pre-treatment period
    if (is.null(special_predictors)) {
        # Generate windows: 3 years on, 3 years off, counting back from pre_end
        windows <- list()
        win_end <- pre_end
        while (win_end - 2 >= pre_start) {
            windows <- c(windows, list(list(outcome_var, (win_end - 2):win_end, "mean")))
            win_end <- win_end - 6  # skip 3 years
        }
        special_predictors <- windows
    }

    # Filter predictors that actually vary in the data
    valid_predictors <- predictors[sapply(predictors, function(p) {
        if (!p %in% names(df)) return(FALSE)
        vals <- df[[p]]
        if (all(is.na(vals))) return(FALSE)
        length(unique(vals[!is.na(vals)])) > 1
    })]

    # Prepare the dataprep object
    dp <- dataprep(
        foo = as.data.frame(df),
        predictors = valid_predictors,
        predictors.op = "mean",
        special.predictors = special_predictors,
        dependent = outcome_var,
        unit.variable = "unit_id",
        unit.names.variable = "Name",
        time.variable = "Year",
        treatment.identifier = treated_id,
        controls.identifier = control_ids,
        time.predictors.prior = pre_start:pre_end,
        time.optimize.ssr = pre_start:pre_end,
        time.plot = pre_start:post_end
    )

    # Run synth
    # nlminb chosen because BFGS fails to converge on authors of sufficiently
    # abnormal e.g. "YearofPublication" values
    synth_out <- synth(dp, "nlminb")

    list(
        synth_out = synth_out,
        dataprep_out = dp,
        treated_name = treated_name,
        treated_id = treated_id,
        control_ids = control_ids,
        treatment_year = treatment_year,
        pre_start = pre_start,
        pre_end = pre_end,
        post_end = post_end
    )
}

#' Compute placebo (in-space) p-values
#' Runs synth for every unit as if it were treated, then computes
#' RMSPE ratios to get permutation-based p-values
run_placebo_test <- function(df, treated_name, treatment_year,
                              pre_start, pre_end, post_end,
                              outcome_var = "cite_English",
                              predictors = NULL,
                              special_predictors = NULL,
                              verbose = TRUE) {

    all_names <- sort(unique(df$Name))

    # Storage for RMSPE ratios
    rmspe_ratios <- numeric(length(all_names))
    names(rmspe_ratios) <- all_names

    pre_years <- pre_start:pre_end
    post_years <- (treatment_year):post_end

    plan(multisession, workers = detectCores() - 1)

    # Compute list of RSMPE ratios, parallelized
    with_progress({
      p <- progressor(along = all_names)
      rmspe_list <- future_lapply(seq_along(all_names), function(i) {
        p(all_names[i])
        nm <- all_names[i]
        tryCatch({
          res <- run_synth(df, nm, outcome_var = outcome_var,
                         treatment_year = treatment_year,
                         pre_start = pre_start, pre_end = pre_end,
                         post_end = post_end,
                         predictors = predictors,
                         special_predictors = special_predictors)
          gaps <- res$dataprep_out$Y1plot - (res$dataprep_out$Y0plot %*% res$synth_out$solution.w)
          years_plot <- as.numeric(rownames(res$dataprep_out$Y1plot))
          gap_df <- data.frame(Year = years_plot, gap = as.numeric(gaps))
          pre_gaps <- gap_df$gap[gap_df$Year < treatment_year]
          post_gaps <- gap_df$gap[gap_df$Year >= treatment_year]
          pre_rmspe <- sqrt(mean(pre_gaps^2))
          post_rmspe <- sqrt(mean(post_gaps^2))
          if (pre_rmspe > 0) post_rmspe / pre_rmspe else NA_real_
        }, error = function(e) NA_real_)
      }, future.seed=TRUE)
    })

    plan(sequential)  # clean up
    Sys.sleep(2)

    rmspe_ratios <- setNames(unlist(rmspe_list), all_names)

    # Compute p-value: fraction of units with RMSPE ratio >= treated unit's ratio
    treated_ratio <- rmspe_ratios[treated_name]
    valid_ratios <- rmspe_ratios[!is.na(rmspe_ratios)]
    p_value <- mean(valid_ratios >= treated_ratio)

    # Standardized p-values for each post-treatment year
    # (simplified: we return the joint post-treatment RMSPE ratio p-value)

    list(
        rmspe_ratios = rmspe_ratios,
        treated_ratio = treated_ratio,
        joint_post_std_p = p_value,
        n_placebos = sum(!is.na(rmspe_ratios)) - 1  # exclude treated
    )
}

#' Save synth results to Excel
save_synth_results <- function(synth_result, placebo_result = NULL,
                               output_dir, label = "") {

    dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

    res <- synth_result
    dp <- res$dataprep_out
    so <- res$synth_out

    # Outcomes: actual vs synthetic
    Y_treated <- as.numeric(dp$Y1plot)
    Y_synth <- as.numeric(dp$Y0plot %*% so$solution.w)
    years <- as.numeric(rownames(dp$Y1plot))

    outcomes <- tibble(
        Year = years,
        Y_Treated = Y_treated,
        Y_Synthetic = Y_synth,
        Gap = Y_treated - Y_synth,
        Pct_Diff = ifelse(Y_synth != 0, (Y_treated - Y_synth) / Y_synth * 100, NA)
    )

    # Donor weights
    w <- as.numeric(so$solution.w)
    x0_ids <- as.numeric(colnames(dp$X0))
    id_to_name <- setNames(dp$names.and.numbers$unit.names,
                            dp$names.and.numbers$unit.numbers)
    weights <- tibble(
      Name = id_to_name[as.character(x0_ids)],
      Weight = w
    ) %>% arrange(desc(Weight))

    # V-weights (predictor importance)
    v <- as.numeric(diag(so$solution.v))
    predictor_names <- colnames(dp$X1)
    v_weights <- tibble(
        Predictor = predictor_names,
        V_Weight = v
    )

    # Balance table
    balance <- tibble(
        Predictor = predictor_names,
        Treated = as.numeric(dp$X1),
        Synthetic = as.numeric(dp$X0 %*% so$solution.w)
    )

    sheets <- list(
        Outcomes = outcomes,
        `Donor Weights` = weights,
        `V-Weights` = v_weights,
        `Balance Table` = balance
    )

    # Add placebo results if available
    if (!is.null(placebo_result)) {
        pr <- placebo_result
        pval_df <- tibble(
            Statistic = c("Joint post/pre RMSPE ratio (treated)",
                          "p-value (joint post std)",
                          "Number of placebos"),
            Value = c(pr$treated_ratio,
                      pr$joint_post_std_p,
                      pr$n_placebos)
        )
        sheets[["P-Values"]] <- pval_df

        ratios_df <- tibble(
            Name = names(pr$rmspe_ratios),
            RMSPE_Ratio = pr$rmspe_ratios
        ) %>% arrange(desc(RMSPE_Ratio))
        sheets[["RMSPE Ratios"]] <- ratios_df
    }

    fname <- file.path(output_dir, paste0("synth_results", label, ".xlsx"))
    write_xlsx(sheets, fname)
    cat("Results saved to:", fname, "\n")

    # Save plot
    pdf(file.path(output_dir, paste0("synth_plot", label, ".pdf")), width = 10, height = 7)
    plot(years, Y_treated, type = "l", lwd = 2, col = "black",
         xlab = "Year", ylab = "Citations (normalized)",
         main = paste0("Synthetic Control: ", res$treated_name, ", treatment year: ", res$treatment_year),
         ylim = range(c(Y_treated, Y_synth)))
    lines(years, Y_synth, lwd = 2, col = "red", lty = 2)
    abline(v = res$treatment_year, lty = 3, lwd = 2, col = "gray50")
    legend("topleft", legend = c("Actual", "Synthetic"),
           col = c("black", "red"), lty = c(1, 2), lwd = 2)
    dev.off()

    invisible(sheets)
}

# ==============================================================================
# 5. PREPARE BASE DATASETS (equivalent to Stata "snapshots")
# ==============================================================================

# Base panel: all authors, drop any with missing cite_English or YearofTranslationtoEnglish
base_panel <- panel %>%
    filter(!is.na(cite_English), !is.na(YearofTranslationtoEnglish))

cat("\nBase panel:", n_distinct(base_panel$Name), "authors\n")

# Snapshot equivalent: Carl Schmitt, 1950-2016, English
snapshot_cs_1950_2016 <- base_panel %>%
    filter(Year >= 1950, Year <= 2016) %>%
    normalize_panel()

cat("Snapshot (1950-2016):", n_distinct(snapshot_cs_1950_2016$Name), "authors,",
    n_distinct(snapshot_cs_1950_2016$Year), "years\n")

# ==============================================================================
# 6. BASELINE SYNTHETIC CONTROL
# ==============================================================================

    cat("\n========================================\n")
    cat("BASELINE SCM: Carl Schmitt, treatment 1974\n")
    cat("========================================\n")

    baseline_dir_0 <- file.path(results_dir, "Treatment_1974")

    baseline_result_0 <- tryCatch({
        run_synth(snapshot_cs_1950_2016, "Carl Schmitt",
                  treatment_year = 1974,
                  pre_start = 1950, pre_end=1973, post_end=1984)
    }, error = function(e) {
        cat("ERROR in baseline synth:", conditionMessage(e), "\n")
        NULL
    })

    cat("\n========================================\n")
    cat("BASELINE SCM: Carl Schmitt, treatment 1983\n")
    cat("========================================\n")

    baseline_dir_1 <- file.path(results_dir, "Treatment_1983")

    baseline_result_1 <- tryCatch({
        run_synth(snapshot_cs_1950_2016, "Carl Schmitt",
                  treatment_year = 1983,
                  pre_start = 1950, pre_end=1982, post_end=1993)
    }, error = function(e) {
        cat("ERROR in baseline synth:", conditionMessage(e), "\n")
        NULL
    })

    cat("\n========================================\n")
    cat("BASELINE SCM: Carl Schmitt, treatment 1994\n")
    cat("========================================\n")

    baseline_dir_2 <- file.path(results_dir, "Treatment_1994")

    baseline_result_2 <- tryCatch({
        run_synth(snapshot_cs_1950_2016, "Carl Schmitt",
                  treatment_year = 1994,
                  pre_start = 1950, pre_end=1993, post_end=2016)
    }, error = function(e) {
        cat("ERROR in baseline synth:", conditionMessage(e), "\n")
        NULL
    })

    cat("\n========================================\n")
    cat("BASELINE SCM: Carl Schmitt, treatment 1965\n")
    cat("========================================\n")

    baseline_dir_3 <- file.path(results_dir, "Treatment_1965")

    baseline_result_3 <- tryCatch({
        run_synth(snapshot_cs_1950_2016, "Carl Schmitt",
                  treatment_year = 1965,
                  pre_start= 1950, pre_end=1964, post_end=1973)
    }, error = function(e) {
        cat("ERROR in baseline synth:", conditionMessage(e), "\n")
        NULL
    })

      if (!is.null(baseline_result_0)) {
          cat("\nRunning placebo tests (this may take a while)...\n")
          baseline_placebo_0 <- tryCatch({
              run_placebo_test(snapshot_cs_1950_2016, "Carl Schmitt",
                               treatment_year = 1974,
                               pre_start = 1950, pre_end = 1973, post_end = 1984)
          }, error = function(e) {
              cat("ERROR in placebo test:", conditionMessage(e), "\n")
              NULL
          })

          save_synth_results(baseline_result_0, baseline_placebo_0, baseline_dir_0, label="_1974")
          cat("\nBaseline p-value (joint post std):",
              ifelse(!is.null(baseline_placebo_0), baseline_placebo_0$joint_post_std_p, "N/A"), "\n")
      }

      if (!is.null(baseline_result_1)) {
          cat("\nRunning placebo tests (this may take a while)...\n")
          baseline_placebo_1 <- tryCatch({
              run_placebo_test(snapshot_cs_1950_2016, "Carl Schmitt",
                               treatment_year = 1983,
                               pre_start = 1950, pre_end = 1982, post_end = 1993)
          }, error = function(e) {
              cat("ERROR in placebo test:", conditionMessage(e), "\n")
              NULL
          })

          save_synth_results(baseline_result_1, baseline_placebo_1, baseline_dir_1, label="_1983")
          cat("\nBaseline p-value (joint post std):",
              ifelse(!is.null(baseline_placebo_1), baseline_placebo_1$joint_post_std_p, "N/A"), "\n")
      }

      if (!is.null(baseline_result_2)) {
          cat("\nRunning placebo tests (this may take a while)...\n")
          baseline_placebo_2 <- tryCatch({
              run_placebo_test(snapshot_cs_1950_2016, "Carl Schmitt",
                               treatment_year = 1994,
                               pre_start = 1950, pre_end = 1993, post_end = 2016)
          }, error = function(e) {
              cat("ERROR in placebo test:", conditionMessage(e), "\n")
              NULL
          })

          save_synth_results(baseline_result_2, baseline_placebo_2, baseline_dir_2, label="_1994")
          cat("\nBaseline p-value (joint post std):",
              ifelse(!is.null(baseline_placebo_2), baseline_placebo_2$joint_post_std_p, "N/A"), "\n")
      }

        if (!is.null(baseline_result_3)) {
          cat("\nRunning placebo tests (this may take a while)...\n")
          baseline_placebo_3 <- tryCatch({
              run_placebo_test(snapshot_cs_1950_2016, "Carl Schmitt",
                               treatment_year = 1965,
                               pre_start = 1950, pre_end = 1964, post_end = 1973)
          }, error = function(e) {
              cat("ERROR in placebo test:", conditionMessage(e), "\n")
              NULL
          })

          save_synth_results(baseline_result_3, baseline_placebo_3, baseline_dir_3, label="_1965")
          cat("\nBaseline p-value (joint post std):",
              ifelse(!is.null(baseline_placebo_3), baseline_placebo_3$joint_post_std_p, "N/A"), "\n")
      }
