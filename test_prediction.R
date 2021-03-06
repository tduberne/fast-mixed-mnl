library(mixl)

data("Train", package="mlogit")
Train$ID <- Train$id
Train$CHOICE <- as.integer(Train$choice)
Nindividuals <- length(unique(Train$ID))

  mnl_test <- "
    ASC_B_RND 	= @ASC_B 	+ draw_2 * @SIGMA_B;
  
  U_A =             @B_price * $price_A / 1000 + @B_time * $time_A / 60 + @B_change * $change_A; 
  U_B = ASC_B_RND + @B_price * $price_B / 1000 + @B_timeB * $time_B / 60 ;
  "
#  Sys.setenv("PKG_CPPFLAGS"= sprintf("-I\"%s\"", system.file(package = "mixl", "include")))
  
  logLik_env <- mixl::specify_model(mnl_test, Train, compile=TRUE)
  
  #only take starting values that are needed
  est <- setNames(c(-1.03970347, -0.80712567, -0.95341969, -0.14061543,  0.19796530, -0.01888506), 
                  c("B_price", "B_time", "B_timeB", "B_change", "ASC_B","SIGMA_B"))
  
  availabilities <- mixl::generate_default_availabilities(Train, logLik_env$num_utility_functions)
  nDraws <- 5
  draws <- mixl::create_halton_draws(Nindividuals, 5, 1)
  
  model <- mixl::estimate(logLik_env, est, Train, availabilities, draws)
  
  model_preds <- mixl::probabilities(model, num_threads=1)
  
  model_preds
  
  expect_equal(dim(model_preds), c(nrow(Train), 4 + logLik_env$num_utility_functions))
  expect_equal(colnames(model_preds), c( "i", "ID", "choice_index", "p_choice", "p_1", "p_2"))

  #expect_equal(unname(model[6,]), c(1, 0, 0 ,1 , 0.6641238, 0.6641238, 0.3358762))