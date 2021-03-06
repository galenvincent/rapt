% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/analysis_functions.R
\name{local.den.onevol}
\alias{local.den.onevol}
\title{Helper for \code{\link{local.den.engine}}.}
\usage{
local.den.onevol(x, y, z, r, dz)
}
\arguments{
\item{x, y, z}{Shortest distance to boundary in the x, y, and z directions,
respectively.}

\item{r}{Distance to nearest neighbor of interest (radius of sphere)}

\item{dz}{z spacing for numeric integration}
}
\description{
Calculates the volume of a sphere that lies inside the domain given its
distance to the domain boundary in x, y, z, and its radius.
}
