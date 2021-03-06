% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/envelope_functions.R
\name{argmax}
\alias{argmax}
\title{Find the peaks of a finite data set using smoothing.}
\usage{
argmax(x, y, w = 1, ...)
}
\description{
This function fits a rolling polynomial interpolation to a set of data and
finds maximums and minimums in data based on these interpolating functoins.
See
\url{https://stats.stackexchange.com/questions/36309/how-do-i-find-peaks-in-a-dataset}
}
