% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rupture_probabilities.R
\name{Mw_exceedance_rate_truncated_gutenberg_richter}
\alias{Mw_exceedance_rate_truncated_gutenberg_richter}
\title{Evaluate the rate of earthquakes with magnitude >= Mw using a doubly
truncated Gutenberg Richter distribution.}
\usage{
Mw_exceedance_rate_truncated_gutenberg_richter(Mw, a, b, Mw_min, Mw_max)
}
\arguments{
\item{Mw}{Moment magnitude}

\item{a}{The a parameter}

\item{b}{The b parameter}

\item{Mw_min}{the lower truncated moment magnitude}

\item{Mw_max}{the upper truncated moment magnitude}
}
\value{
The rate of events with magnitude > Mw
}
\description{
The Gutenberg Richter distribution gives the number of earthquakes with
magnitude > Mw as:\cr
N_{GR}(x >= Mw) = 10^(a-bMw) \cr
where a and b are constants. Note 10^(a) is the rate of earthquakes with Mw >
0. \cr
By differentiating N_{GR} we can estimate the number of events with 
(Mw - dx/2 <= magnitude <= Mw +dx/2) as:\cr
N(Mw -dx/2 <= x <= Mw + dx/2) ~= dx * n(Mw) = dx * ([10^(a-bMw)] * bln(10)) \cr
where n(Mw) is the negative of the derivative of N(x>Mw). \cr
n(Mw) is like a scaled probability-density-function of the number of
earthquakes. Unlike a pdf, n(Mw) integrates to the rate of earthquakes,
instead of 1.\cr
For the truncated Gutenberg Richter distribution, n(Mw) is truncated between
lower and upper Mw limits (i.e. set to zero outside these limits). \cr
We then have the equivalent of N_{GR} for the truncated distribution as: \cr
N_{TGR}(x >= Mw) = 10^(-max(Mw, Mw_min)*b + a) - 10^(-Mw_max*b + a) \cr
Notice that now, 10^(a) is no-longer the rate of earthquakes with Mw >= 0 --
instead that rate is :\cr
N_{TGR}(x >= Mw_min) = 10^(a - b*Mw_min) - 10^(a - b*Mw_max) \cr
(because there are no events with magnitude <= Mw_min)
}
