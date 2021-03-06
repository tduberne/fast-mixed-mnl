// [[Rcpp::plugins(openmp)]]
// [[Rcpp::plugins(cpp11)]]        

#include <Rcpp.h>
#include "mixl/utility_function.h"

using Rcpp::DataFrame;
using Rcpp::NumericMatrix;
using Rcpp::NumericVector;
using Rcpp::CharacterVector;
using Rcpp::_;
using Rcpp::stop;

// [[Rcpp::export]]
NumericMatrix predict(NumericVector betas, DataFrame data,
                      int Nindividuals, NumericMatrix availabilities,
                      int num_threads=1) {
  
  omp_set_num_threads(num_threads);
  
  const int PRE_COLS = 4;
  
  int nCols = PRE_COLS + !===utility_length===!;
  NumericMatrix P(data.nrows(), nCols);
  
  CharacterVector colnames1(nCols);
  colnames1[0] = "i";
  colnames1[1] = "ID";
  colnames1[2] = "choice_index";
  colnames1[3] = "p_choice";
  for (int i=0; i < !===utility_length===!; i++) {
    
    std::ostringstream oss;
    oss << "p_" << i + 1;
    
    colnames1[PRE_COLS+i] = oss.str();
  }
  
  colnames(P) = colnames1;
  
  UF_args v(data, Nindividuals, availabilities, P);
  
  std::fill(v.P.begin(), v.P.end(), 0);
  
  if (!(v.data.containsElementNamed("ID") && v.data.containsElementNamed("CHOICE"))) {
    stop("Both ID and CHOICE columns need to be present in the data");
  }
  
  //delcare the variables that you will be using from the dataframe
  const NumericVector row_ids = v.data["ID"];
  const NumericVector choice = v.data["CHOICE"];
  
  NumericVector count;
  
  /////////////////////////////////////
  
  
  //betas
  !===beta_declarations===!
    
    
    //data
    !===data_declarations===!
    
    /////////////////////////////////////
    
#pragma omp parallel
{
  std::valarray<double> utilities(!===utility_length===!);  //specify here the number of alternatives
  
#pragma omp for
  for (int i=0; i < v.data.nrows(); i++) {
    
    int individual_index = row_ids[i]-1; //indexes should be for c, ie. start at 0
    //Rcpp::Rcout << "indv: " << individual_index << std::endl;
    
    std::fill(std::begin(utilities), std::end(utilities), 0.0);
    
    /////////////////////////
    
    !===draw_and_utility_declarations===!
      
      /////////////////////////
      
      //dont edit beflow this line
      for (unsigned k=0; k < utilities.size(); ++k) {
        utilities[k] = std::min(700.0, std::max(-700.0, utilities[k])); //trip utilities to +- 700 for compuational reasons
        utilities[k] = exp(utilities[k]); //take the exponential of each utility
      }
      
      double chosen_utility = utilities[choice[i]-1]; //this -1 is needed if the choices start at 1 (as they should)
    
      double sum_utilities = 0.0;
      NumericMatrix::ConstRow  choices_avail = v.availabilities( i , _ );
      
      for (unsigned k=0; k < utilities.size(); ++k) {
        sum_utilities += utilities[k] * choices_avail[k];
      }
      
      double pchoice = chosen_utility / sum_utilities;
      std::valarray<double> probabilities = utilities / sum_utilities;
        
      P(i, 0) = i;
      P(i, 1) = individual_index;
      P(i, 2) = choice[i];
      P(i, 3) = pchoice;
      for (unsigned k=0; k < utilities.size(); ++k) {
        P(i, PRE_COLS + k) = probabilities[k];
      } 
      
    
  }
  
}
return (P);
}

