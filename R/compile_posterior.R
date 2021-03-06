
#' @export 
posteriors <- function(model, indiv_data=NULL, code_output_file=NULL) {
  
  data_cols <- extract_var(paste(model$rnd_equations[,'equation'], collapse="\n"),data_pattern)
  if (length(data_cols) == 0) data_cols <- NULL
  
  if (missing(indiv_data) | is.null(indiv_data)) {
    indiv_data <- extract_indiv_data(model$data, data_cols)
  }
  
  #handle basic mnl case without and draws
  if(!model$is_mixed | (!is.null(model$nDraws) & model$nDraws == 0)) {
    f <- compile_posterior_function(model$rnd_equations, names(model$estimate), FALSE, code_output_file)
    
    f(model$estimate, model$probabilities, model$Nindividuals, indiv_data)

  } else { 
    f <- compile_posterior_function(model$rnd_equations, names(model$estimate), TRUE, code_output_file)
    
    f(model$estimate, model$probabilities,
      model$Nindividuals, indiv_data,
      model$draws, model$nDraws)
  }
}


#' @export 
parse_equations <- function(utility_script) {
  random_regex <- "\\b(\\w*_RND)\\s*=\\s*([^;]*)"
  a  <- stringr::str_match_all(utility_script, random_regex)
  a <- a[[1]][,c(2,3),drop=F]
  if (!is.null(a) && length(dim(a)) >= 2) colnames(a) <- c("name", "equation")
  a
}


compile_posterior_function <- function(rnd_equations, betas, is_mixed, output_file=NULL) {
  
  #posterior_template <- readr::read_file("inst/include/mixl/cpp_posteriors.cpp")
  if (is_mixed) {
    template_filename <- "cpp_posteriors.cpp"
  } else {
    template_filename <- "cpp_mnl_posteriors.cpp"
  }
  
  posterior_template <- readr::read_file(system.file("include", "mixl", template_filename, package = "mixl"))
  
  
  #rnd_equations <- model$rnd_equations
  names <- rnd_equations[,"name"]
  equations <- rnd_equations[,'equation']
  
  beta_var_init_text <- 'double {beta_name} = betas["{beta_name}"];'
  beta_inits_vec <- sapply(betas, function (beta_name) stringr::str_glue(beta_var_init_text)) #vector creation
  beta_declarations <- paste(beta_inits_vec, collapse="\n")
  
  data_cols <- extract_var(paste(equations, collapse="\n"),data_pattern)
  data_var_init_text <- 'const NumericVector {data_prefix}{col_name} = data["{col_name}"];'
  data_inits_vec <- sapply(data_cols, function (col_name) stringr::str_glue(data_var_init_text)) #vector creation
  data_declarations <- paste(data_inits_vec, collapse="\n")
  
  data_subs <- setNames (paste0(data_prefix, data_cols , "[i]"), paste0("\\$", data_cols, "\\b"))

  num_rnd_vars <- length(names)
  
  col_names <- paste0("colnames1[i++] = \"", names, "\";", collapse = "\n")
  
  random_paramters <- (paste0("indiv_B_means(i, rnd_idx++) += probabilities(i,d) * (", equations, ");", collapse="\n"))
                       
  code <- stringr::str_glue(posterior_template, .open="!===", .close="===!")
  
  ccode_w_data  <- stringr::str_replace_all(code, data_subs)
  
  if (!is.null(output_file)) {
    readr::write_file(ccode_w_data, output_file)
  }
  
  f_env <- new.env()
  Rcpp::sourceCpp(code=ccode_w_data, env = f_env)
  
  return (f_env$mixl_posteriors)
  
  }