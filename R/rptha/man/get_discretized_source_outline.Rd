% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/unit_sources.R
\name{get_discretized_source_outline}
\alias{get_discretized_source_outline}
\title{Outline of the discretized source}
\usage{
get_discretized_source_outline(discretized_source)
}
\arguments{
\item{discretized_source}{list containing unit sources information (e.g.
output of discretized_source_from_source_contours)}
}
\value{
matrix defining the 'outline' polygon of the discretized source
}
\description{
Convenience function to get the outline of the discretized source from its
unit_source_grid
}
