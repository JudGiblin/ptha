% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gutenberg_richter_densities.R
\name{rtruncGR}
\alias{rtruncGR}
\title{Random samples from truncated Gutenberg Richter distribution}
\usage{
rtruncGR(n, b, mw_min, mw_max = Inf)
}
\arguments{
\item{n}{integer giving desired number of samples}

\item{b}{Gutenberg-Richter b value}

\item{mw_min}{Minimum mw}

\item{mw_max}{Maximum mw}
}
\value{
vector with random Mw values
}
\description{
Note corresponding functions ptruncGR, qtruncGR, dtruncGR, rtruncGR.
}
\examples{
#
# Make 300 random Mw samples
#
random_Mws = rtruncGR(300, b=0.7, mw_min=5.0, mw_max=Inf)
#
# Estimate 'b' with maximum likelihood
#
negloglik_truncGR<-function(b, data, mw_min, mw_max){
    -sum(log(dtruncGR(data, b=b, mw_min=mw_min, mw_max=mw_max)))
}
fit_inf_mw_max = optimize(negloglik_truncGR, interval=c(0, 2), data=random_Mws, 
    mw_min=5.0, mw_max=Inf, tol=1e-12)
#
# Because mw_max = Inf, this should give Aki's maximum likelihood estimator
# = 1/(ln(10) * (mean(data) - mw_min))
aki_estimator = 1/(log(10) * ( mean(random_Mws) - 5.0))
stopifnot(abs(fit_inf_mw_max$minimum - aki_estimator) < 1.0e-06)

#
# If mw_max < Inf, then the maximum likelihood b-value will not be the same
# as Aki's estimator, since we are using a truncated GR distribution
#
random_Mws = rtruncGR(300, b=0.7, mw_min=5.0, mw_max=8.8)
fit_finite_mw_max = optimize(negloglik_truncGR, interval=c(0, 2), data=random_Mws, 
    mw_min=5.0, mw_max=8.8)
aki_estimator = 1/(log(10) * ( mean(random_Mws) - 5.0))

}
