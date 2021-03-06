% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/rapt-multi.R
\name{multiples}
\alias{multiples}
\title{Provides a vector of multiplicity orders; this may be attached to the ATO
for further processing.}
\usage{
multiples(mind)
}
\arguments{
\item{mind}{A list of integers. The output from \code{\link{indexMultiples}}.}
}
\value{
A vector of integers corresponding to the multiplicity of each hit in
  the ATO that generated the list. The order corresponds to the order in the
  ATO.
}
\description{
\code{multiples} takes the output list of first hit indicies returned by
\code{indexMultiples} and creates a single vector of the multiplicity of each
hit.
}
\seealso{
\code{\link{indexMultiples}}
}
