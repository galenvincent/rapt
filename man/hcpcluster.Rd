% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cluster_functions.R
\name{hcpcluster}
\alias{hcpcluster}
\title{Generate spherical clusters with hexagonal close packed spacing.}
\usage{
hcpcluster(csep_r, R, sigma1, sigma2, win, background, filepath)
}
\arguments{
\item{csep_r}{Cluster separation radius. That is, the radius of the spheres
in the HCP structure.}

\item{R}{Cluster radius.}

\item{sigma1}{Inter cluster density. Value between 0 and 1.}

\item{sigma2}{Background density. Value between 0 and 1.}

\item{win}{A \code{\link[spatstat]{box3}} object containing the window of the
cluster set you want to make.}

\item{background}{Either \code{'poisson'} or \code{'rcp'}. Whether to have
Poission distributed points or RCP points for the points in the clusters and
in the background.}

\item{filepath}{Needed if \code{background = 'rcp'}. Vector with the filepath
to [1] the FinalConfig file of the RCP pattern desired, [2] the system file
of the RCP pattern desired}
}
\value{
A list of [[1]] A \code{\link[spatstat]{pp3}} object containing the
  cluster points, [[2]] The overall intensity of the point pattern; Total
  number of points/total volume.
}
\description{
Generates perfectly spherical clusters with structred order of hexagonal
close packing (HCP). Can define cluster separation, cluster radius, inter
cluster density, background density, and window size.
}
