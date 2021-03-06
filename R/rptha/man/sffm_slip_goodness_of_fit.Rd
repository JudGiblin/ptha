% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sffm_fit_simulate_earthquake.R
\name{sffm_slip_goodness_of_fit}
\alias{sffm_slip_goodness_of_fit}
\title{Goodness of fit for SFFM parameters}
\usage{
sffm_slip_goodness_of_fit(reg_par, tg_rast, verbose = FALSE,
  default_seed = 1, NumRandSf = 200,
  sffm_pars = .sffm_default_model_parameters)
}
\arguments{
\item{reg_par}{= vector of 2 proposed regression parameters (kcxN, kcyN) **in numerical
space**. A 3rd parameter may be accepted in some cases, depending on the
values of reg_par allowed in sffm_pars$spectral_amplitude_function. See
\code{?sffm_simulate} for more details on 'numerical space' and 'physical space'}

\item{tg_rast}{slip matrix or raster to compute the goodness of fit for}

\item{verbose}{TRUE/FALSE -- Verbose error messages}

\item{default_seed}{integer -- passed to set.seed for reproducible fitting
with random fault generation (original .Random.seed is restored at the end)}

\item{NumRandSf}{integer. Number of slip distributions simulated to compute the
goodness-of-fit of the model}

\item{sffm_pars}{environment containing configuration parameters}
}
\value{
A goodness-of-fit measure -- minimising this will lead to the 'best'
        model fit
}
\description{
Given regression parameters, compute a goodness-of-fit statistic of the
model with reg_par and data (tg_mat), based on Davies et al. (2015), Equation
5. Most users would not call this routine directly (see sffm_fit_parameters 
for parameter estimation). \cr
}
\references{
Davies et al. (2015), 
Tsunami inundation from heterogeneous earthquake slip distributions:
Evaluation of synthetic source models, J. Geophys. Res. Solid Earth, 120,
6431-6451, doi:10.1002/2015JB012272. \cr
}
