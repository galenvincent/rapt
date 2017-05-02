#### marktable.pp3 ####
#' Extends \code{\link[spatstat]{marktable}} to \code{\link[spatstat]{pp3}}.
#'
#' \code{marktable.pp3}
marktable.pp3 <- function (X, R, N, exclude = TRUE, collapse = FALSE) {
  verifyclass(X, "pp3")
  if (!is.marked(X, dfok = FALSE))
    stop("point pattern has no marks")
  gotR <- !missing(R) && !is.null(R)
  gotN <- !missing(N) && !is.null(N)
  if (gotN == gotR)
    stop("Exactly one of the arguments N and R should be given")
  stopifnot(is.logical(exclude) && length(exclude) == 1)
  m <- marks(X)
  if (!is.factor(m))
    stop("marks must be a factor")
  if (gotR) {
    stopifnot(is.numeric(R) && length(R) == 1 && R > 0)
    p <- closepairs.pp3(X, R, what = "indices")
    pi <- p$i
    pj <- p$j
    if (!exclude) {
      n <- npoints(X)
      pi <- c(pi, 1:n)
      pj <- c(pj, 1:n)
    }
  }
  else {
    stopifnot(is.numeric(N) && length(N) == 1)
    ii <- seq_len(npoints(X))
    nn <- nnwhich(X, k = 1:N)
    if (N == 1)
      nn <- matrix(nn, ncol = 1)
    if (!exclude)
      nn <- cbind(ii, nn)
    pi <- as.vector(row(nn))
    pj <- as.vector(nn)
  }
  if (!collapse) {
    i <- factor(pi, levels = seq_len(npoints(X)))
    mj <- m[pj]
    mat <- table(point = i, mark = mj)
  }
  else {
    mi <- m[pi]
    mj <- m[pj]
    mat <- table(point = mi, neighbour = mj)
  }
  return(mat)
}
#### superimpose.pp3 ####
#' Extends \code{\link[spatstat]{superimpose}} to \code{\link[spatstat]{pp3}}.
#' @export
# Add ability to superimpose with marks
superimpose.pp3 <- function(..., W = NULL, check = F) {
  input.list <- list(...)
  df.list <- lapply(input.list, as.data.frame)
  df.comb <- Reduce(rbind, df.list)
  out.pp3 <-  createSpat(df.comb, win = W)
  return(out.pp3)
}
#### shift.pp3 ####
#' Extends \code{\link[spatstat]{shift}} to \code{\link[spatstat]{pp3}}.
shift.pp3 <- function (X, vec = c(0, 0, 0), ..., origin = NULL)
{
  verifyclass(X, "pp3")
  if (!is.null(origin)) {
    if (!missing(vec))
      warning("argument vec ignored; overruled by argument origin")
    if (is.numeric(origin)) {
      locn <- origin
    }
    else if (is.character(origin)) {
      origin <- pickoption("origin", origin,
                           c(midpoint = "midpoint", bottomleft = "bottomleft"))
      W <- X$domain
      locn <- switch(origin, midpoint = {
        c(mean(W$domain$xrange), mean(W$domain$yrange), mean(W$domain$zrange))
      }, bottomleft = {
        c(W$domain$xrange[1], W$domain$yrange[1], W$domain$zrange[1])
      })
    }
    else stop("origin must be a character string or a numeric vector")
    vec <- -locn
  }
  Y <- pp3(X$data$x + vec[1], X$data$y + vec[2], X$data$z + vec[3],
           xrange = X$domain$xrange + vec[1],
           yrange = X$domain$yrange + vec[2],
           zrange = X$domain$zrange + vec[3])
  attr(Y, "lastshift") <- vec
  return(Y)
}
#### inside.pp3 ####
#' Extends \code{\link[spatstat]{inside}} to \code{\link[spatstat]pp3}}.
#' @export
inside.pp3 <- function(points, domain = NULL) {
  if(is.null(domain)) {
    domain <- points$domain
  }
  if (length(points) == 0)
    return(logical(0))
  xr <- domain$xrange
  yr <- domain$yrange
  zr <- domain$zrange
  x <- points$data$x
  y <- points$data$y
  z <- points$data$z
  eps <- sqrt(.Machine$double.eps)
  frameok <- (x >= xr[1] - eps) & (x <= xr[2] + eps) &
    (y >= yr[1] - eps) & (y <= yr[2] + eps) &
    (z >= zr[1] - eps) & (z <= zr[2] + eps)
  return(frameok)
}
#### sample.ppp ####
#' Extends \code{\link[base]{sample}} to handle \code{\link[spatstat]{ppp}}.
sample.ppp <- function(X, size) {
  sam.n <- npoints(X)
  sam.pts <- sample(1:sam.n, size)
  sam.dat <- X[sam.pts]
  return(sam.dat)
}
#### sample.pp3 ####
#' Extends \code{\link[base]{sample}} to handle \code{\link[spatstat]{pp3}}.
sample.pp3 <- function(X, size) {
  sam.lab <- rownames(as.data.frame(X$data))
  sam.pts <- sample(sam.lab, size)
  sam.dat <- X[sam.pts]
  return(sam.dat)
}
#### findClusters.pp3 ####
#' Finds clusters by NN adjacency marks.
findClusters.pp3 <- function(X, mark, k = 1) {
  if(!(mark %in% marks(X)))
    stop('The specified mark does not exist in the pattern')
  else if(length(mark) != 1)
    stop('Only one mark may be tested')
  spl <- split(X)[[mark]]
  # required because pp3 functions don't work on marked pp3 by default
  class(spl) <- c('pp3', 'ppx')
  ind <- rownames.pp3(spl)
  fCl <- lapply(ind, function(x) {
    clus <- x
    rem <- rownames.pp3(X)
    nn <- 0
    while(length(nn) > 0) {
      rem <- setdiff(rem, nn)
      nn <- nncross(spl[clus], X[rem], k = 1:k, what = 'which')
      nn <- unlist(nn)
      nn <- rownames.pp3(X[rem])[nn]
      nn <- nn[marks(X[nn]) == mark]
      clus <- append(clus, nn)
    }
    clus <- sort(unique(clus))
    return(clus)
  })
  return(fCl)
}
#### intensity.pp3 ####
#' Extends \code{\link[spatstat]{intensity}} to \code{\link[spatstat]{pp3}}.
intensity.pp3 <- function(X, weights = NULL) {
  n <- npoints(X)
  a <- volume(domain(X))
  if (is.null(weights)) {
    if (is.multitype(X)) {
      mks <- marks(X)
      answer <- as.vector(table(mks))/a
      names(answer) <- levels(mks)
    }
    else answer <- n/a
    return(answer)
  } else
    warning('Weights is not yet implemented for pp3')
}

#### rownames.pp3 ####
#' Extends \code{\link[base]{rownames}} to \code{\link[spatstat]{pp3}}.
rownames.pp3 <- function(pat) {
  dat <- rownames(as.data.frame(pat))
  return(dat)
}
#### plot3d.pp3 ####
#' Plot a \code{\link[spatstat]{pp3}} in a manipulatable 3D plot.
#'
#' (requires the rgl library)
plot3d.pp3 <- function(X, ...) {
  rgl::plot3d(as.data.frame(X$data), ...)
}