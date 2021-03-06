% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/unit_sources.R
\name{get_unit_source_from_discretized_source}
\alias{get_unit_source_from_discretized_source}
\title{Coordinates of a single unit source}
\usage{
get_unit_source_from_discretized_source(discretized_source, unit_source_index)
}
\arguments{
\item{discretized_source}{List holding the discretized_source information (e.g. output
of discretized_source_from_source_contours)}

\item{unit_source_index}{Vector of length 2 giving the index of the desired
unit source (down-dip, along-strike)}
}
\value{
List containing unit source information
}
\description{
Convenience function to extract coordinates of a single unit source from the
discretized_source list
}
