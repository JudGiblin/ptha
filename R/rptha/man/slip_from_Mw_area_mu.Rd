% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rupture_scaling.R
\name{slip_from_Mw_area_mu}
\alias{slip_from_Mw_area_mu}
\title{Compute mean slip on a rupture of a given area, moment magnitude Mw, and}
\usage{
slip_from_Mw_area_mu(Mw, area, mu = 3e+10, constant = 9.05)
}
\arguments{
\item{Mw}{Moment magnitude}

\item{area}{area of rupture (km^2)}

\item{mu}{Shear Modulus (Pascals)}

\item{constant}{value of constant passed to \code{M0_2_Mw}}
}
\value{
slip in m
}
\description{
Compute mean slip on a rupture of a given area, moment magnitude Mw, and
}
\examples{
s0 = slip_from_Mw_area_mu(9.0, 100e+03) # Should be close to 10m

}
