#Functions to analyze and produce results from data

#### k3metrics ####
#' Extract metrics from 3D K function output
#'
#' Takes as inputs the results from \code{\link{anomK3est}} function performed
#' on a clustered data set. Returns five different metrics of this result.
#'
#' @param rvals.new The radius values from the \code{\link{anomK3est}}. These
#'   need to be trimmed so that they start past the inhibition radius of the
#'   underlying RCP pattern.
#' @param tvals.new The returned K values from the \code{\link{anomK3est}}.
#'   These need to be trimmed to the same indices as rvals.new.
#'
#' @return A list of [[1]] Km, [[2]] Rm, [[3]] Rdm, [[4]] Rddm, [[5]] Kdm for
#'   the input K function. If no first K peak is found, returns a list of 5
#'   NaNs.

k3metrics <- function(rvals.new, tvals.new, toplot) {
  peak.info <- argmax(rvals.new, tvals.new, w = 3, span = 0.08)

  if(any(is.infinite(tvals.new))){
    return(list(NA, NA, NA, NA, NA))
  }

  #lines(rvals.new, peak.info$y.hat)
  #points(peak.info$x,tvals.new[peak.info$i],pch = 6, cex = 2, col="red")
  if(is.na(peak.info$x[1])){
    return(list(NA, NA, NA, NA, NA))
  }
  span <- (peak.info$x[1]/7)*(0.3)
  peak.info <- argmax(rvals.new, tvals.new, w = 3, span = span)

  peak.info$deriv <- finite_deriv(rvals.new, peak.info$y.hat)
  #points(rvals.new,peak.info$deriv)
  peak.info$derivsm <- argmax(rvals.new, -1*peak.info$deriv, w = 3,
                              span = span)
  peak.info$derivsm_neg <- argmax(rvals.new, peak.info$deriv, w = 3,
                                  span = span)

  peak.info$dderiv <- finite_deriv(rvals.new, -1*peak.info$derivsm$y.hat)
  peak.info$dderivsm <- argmax(rvals.new, peak.info$dderiv, w = 3,
                               span = span)
  #points(rvals.new,peak.info$dderiv)

  peak.info$ddderiv <- finite_deriv(rvals.new, peak.info$dderivsm$y.hat)
  peak.info$ddderivsm <- argmax(rvals.new, peak.info$ddderiv, w = 3,
                                span = span)
  #points(rvals.new, peak.info$ddderiv)
  lb <- peak.info$i[1]
  ub <- (peak.info$derivsm$i[1] + peak.info$derivsm_neg$i[1])/2
  if(is.na(ub)) {
    ub <- length(rvals.new)
  }
  Rddm_ind <- peak.info$ddderivsm$i[peak.info$ddderivsm$i >
                                      lb & peak.info$ddderivsm$i < ub][1]

  # stuff if you want to plot
  #browser()
  if(toplot == TRUE) {
    plot(rvals.new, tvals.new, type = "n")

    lines(rvals.new, peak.info$y.hat)
    points(peak.info$x, tvals.new[peak.info$i], pch = 6, cex = 2, col="red")

    lines(rvals.new, -peak.info$derivsm$y.hat, lwd = 2, col = "red")
    points(peak.info$derivsm$x, peak.info$deriv[peak.info$derivsm$i],
           col="blue", cex = 2)

    lines(rvals.new, peak.info$dderivsm$y.hat, lwd = 2, col = "purple")
    points(peak.info$dderivsm$x, peak.info$dderiv[peak.info$dderivsm$i],
           col="green", cex = 2, pch = 19)

    lines(rvals.new, peak.info$ddderivsm$y.hat,lwd = 2, col = "blue")
    points(rvals.new[Rddm_ind], peak.info$ddderiv[Rddm_ind],
           col="green", cex = 1, pch = 19)
  }

  return(list(peak.info$y.hat[peak.info$i[1]], #Km
              peak.info$x[1], #Rm
              peak.info$derivsm$x[1], #Rdm
              rvals.new[Rddm_ind[1]], #Rddm
              -peak.info$derivsm$y.hat[peak.info$derivsm$i[1]])) #Kdm
}

localk3metrics <- function(kl, start){
  span <- NA
  i <- 1
  while(is.na(span)){
    r.n <- kl$r[start:nrow(kl)]
    t.n <- kl[start:nrow(kl),i+3]

    peak.info <- argmax(r.n, t.n, w = 3, span = 0.1)
    span <- (peak.info$x[1]/7)*(0.3)

    i <- i + 1
  }

  np <- ncol(kl)-3
  pks <- rep(0,np)
  # for(i in 1:np){
  #   t.n <- kl[15:nrow(kl),i+3]
  #   a <- argmax(r.n, t.n, w = 3, span = span)
  #   pks[i] <- a$x[1]
  # }

  nsamp <- 2000
  pks2 <- rep(0,nsamp)
  pts <- sample(1:np, nsamp, replace = FALSE)
  for(i in 1:nsamp){
    t.n <- kl[15:nrow(kl),pts[i]]
    a <- argmax(r.n, t.n, w = 3, span = span)
    pks2[i] <- a$x[1]
  }

  b <- var(pks2, na.rm = TRUE)
  return(b)
}

#### kseries2 ####
#' Helper function to allow for parallelization of metric extraction from
#' cluster simulations
#'
#' This function takes a single RCP pattern and creates and tests the K function
#' metrics on different cluster properties passed into the function. Used to
#' parallelize large sets of cluster property runs.
#'
#' @param j The index of the RCP pattern to run (note that this might only be
#'   able to be applied on the mines HPC under Galen's account right now as
#'   written)
#' @param p The total number of RCP patterns available.
#' @param tot A list of cluster properties to test. This should be a list of
#'   vectors containing c(r, den, rb, gbp).
#' @param maxr Maximum r to calculate K function to.
#' @param nr Number of r values to evaluate k function at.
#' @param toSub A vector of values to substitute for the \code{\link{anomK3est}}
#'   function.
#' @param hpc Whether or not using the hpc.
#' @param s seed.
#'
#' @return Matrix containing 5 metrics and the seed value for each parameter
#'   combination given in the \code{tot} list.
kseries2 <- function(j, p ,tot, maxr, nr, toSub, hpc = TRUE, s){
  #t1 <- Sys.time()
  under.nums <- seq(2,(p+1),1)
  under.nums[length(under.nums)] <- 1
  over.nums <- seq(1,p,1)

  #upload
  if(hpc == FALSE){
    under <- read.rcp(paste('~/Research/point_patterns/Final/FinalConfig',toString(under.nums[j]),sep=""),paste('~/Research/point_patterns/Final/system',toString(under.nums[j]),sep=""),scaleUp = TRUE,newRadius = 0.5)
    over <- read.rcp(paste('~/Research/point_patterns/Final/FinalConfig',toString(over.nums[j]),sep=""),paste('~/Research/point_patterns/Final/system',toString(over.nums[j]),sep=""),scaleUp = TRUE,newRadius = 0.5)
  }else{
    under <- read.rcp(paste('~/scratch/Rcode/FinalConfigs/FinalConfig',toString(under.nums[j]),sep=""),paste('~/scratch/Rcode/systems/system',toString(under.nums[j]),sep=""),scaleUp = TRUE,newRadius = 0.5)
    over <- read.rcp(paste('~/scratch/Rcode/FinalConfigs/FinalConfig',toString(over.nums[j]),sep=""),paste('~/scratch/Rcode/systems/system',toString(over.nums[j]),sep=""),scaleUp = TRUE,newRadius = 0.5)
  }

  under.big <- stitch.size(under, boxSize = c(60,60,60))
  over.big <- stitch.size(over, boxSize = c(60,60,60))

  set.seed(s)
  cnt <- j*length(tot)*round(runif(1, 1, 10000))

  outtemp <- matrix(NA, nrow = length(tot), ncol = 5)

  for(i in 1:length(tot)){
    print(i)
    if(length(tot[[1]]) == 4){
      cluster <- makecluster(under.big,over.big,0.5,0.5,type="cr",speed="superfast",
                             cr=tot[[i]][1],
                             den = tot[[i]][2],
                             rb = TRUE, rbp = tot[[i]][1]*tot[[i]][3],
                             gb = TRUE, gbp = c(0, tot[[i]][4]),
                             s = cnt)
    }else{
      cluster <- makecluster(under.big,over.big,0.5,0.5,type="cr",speed="superfast",
                             cr=tot[[i]][1],
                             den = tot[[i]][2],
                             gb = TRUE, gbp = c(0, tot[[i]][3]),
                             s = cnt)
    }
    if(is.numeric(cluster)){
      outtemp[i,] <- c(NA, NA, NA, NA, NA)
      a <- as.data.frame(1)
      if(hpc == TRUE){
        if(i > 1){
          file.remove(paste("~/scratch/Rcode/junk/",toString(j),"_",toString(i-1),".csv", sep = ""))
        }
        write.csv(a, file = paste("~/scratch/Rcode/junk/",toString(j),"_",toString(i),".csv", sep = ""))
      }else{
        if(i > 1){
          file.remove(paste("~/Research/junk/",toString(j),"_",toString(i-1),".csv", sep = ""))
        }
        write.csv(a, file = paste("~/Research/junk/",toString(j),"_",toString(i),".csv", sep = ""))
      }
      next
    }
    result <- anomK3est(cluster[[1]],toSub,maxr,nr)
    rvals <- result$r
    tvals <- result$trans

    # get out that peak info son
    rvals.new <- rvals[15:length(rvals)]
    tvals.new <- tvals[15:length(rvals)]
    #get those metrics out
    metrics <- k3metrics(rvals.new, tvals.new, FALSE)
    #locmetric <- localk3metrics(result, 15)

    outtemp[i,] <- c(metrics[[1]], metrics[[2]], metrics[[3]], metrics[[4]], metrics[[5]])

    rm(cluster, result, rvals, tvals, rvals.new, tvals.new)
    gc()

    cnt <- cnt + 1

    a <- as.data.frame(1)

    if(hpc == TRUE){
      if(i > 1){
        file.remove(paste("~/scratch/Rcode/junk/",toString(j),"_",toString(i-1),".csv", sep = ""))
      }
      write.csv(a, file = paste("~/scratch/Rcode/junk/",toString(j),"_",toString(i),".csv", sep = ""))
    }else{
      if(i > 1){
        file.remove(paste("~/Research/junk/",toString(j),"_",toString(i-1),".csv", sep = ""))
      }
      write.csv(a, file = paste("~/Research/junk/",toString(j),"_",toString(i),".csv", sep = ""))
    }

  }

  #t2 <- Sys.time()
  #print(t2-t1)

  rm(over, under, over.big, under.big)

  return(outtemp)
}


#### bdist.points3.multi ####
#' Returns the shortest distances to boundaries in the x, y, and z directions
#' separately.
#'
#' @param X The point pattern for analysis. A \code{\link[spatstat]{pp3}}
#'   object.
#' @return An object containing the shortest distance to the closest three
#'   boundaries for each point in the pattern X.

bdist.points3.multi <- function (X){

  verifyclass(X, "pp3")

  x <- X$data$x
  y <- X$data$y
  z <- X$data$z
  d <- X$domain

  xmin <- min(d$xrange)
  xmax <- max(d$xrange)
  ymin <- min(d$yrange)
  ymax <- max(d$yrange)
  zmin <- min(d$zrange)
  zmax <- max(d$zrange)

  result <- data.frame(x = pmin.int(x - xmin, xmax - x), y =  pmin.int(y - ymin, ymax - y), z = pmin.int(z - zmin, zmax - z))

  return(result)
}

#### local.den.onevol ####
#' Helper for \code{\link{local.den.engine}}.
#'
#' Calculates the volume of a sphere that lies inside the domain given its
#' distance to the domain boundary in x, y, z, and its radius.
#'
#' @param x,y,z Shortest distance to boundary in the x, y, and z directions,
#'   respectively.
#' @param r Distance to nearest neighbor of interest (radius of sphere)
#' @param dz z spacing for numeric integration
local.den.onevol <- function(x, y, z, r, dz){

  if(x > r & y > r & z > r){ #If sphere lies fully inside, just return the full sphere volume
    return((4/3)*pi*r^3)
  }

  # If not, calculate the volume inside (SEE MATHEMATICA NOTEBOOK FOR DERIVATIONS)
  Rcalc <- function(z,r){return(sqrt(r^2 - abs(z)^2))} # Plane intersection circle radius at z value from center of sphere of radius r
  Cseg <- function(x,R){return(R^2 * acos(x/R) - x * sqrt(R^2 - x^2))} # Area of circular segment a distance x from center of circle with radius R
  Iseg <- function(x,y,R){return(0.5 * (sqrt((R - x)*(R + x)) - y) * (sqrt((R - y)*(R + y)) - x) -
                                   0.5 * sqrt(R^2 - sqrt((R - x) * (R + x)) * y - sqrt((R - y) * (R + y)) * x) * sqrt(R^2 + sqrt((R - x) * (R + x)) * y + sqrt((R - y) * (R + y)) * x) +
                                   R^2 * acos(sqrt(R^2 + sqrt(R^2 - x^2) * y + sqrt(R^2 - y^2) * x)/(R*sqrt(2))))} # Area of intersection of two circular segments
  Carea <- function(x,y,z,zmax,R){ # The outside area of a circle of radius R at some x, y in the xy plane a distance z from the center of the sphere
    if(z >= zmax){
      return(pi * R^2)
    }else if (sqrt(x^2 + y^2) < R){
      return(Cseg(x,R) + Cseg(y,R) - Iseg(x, y, R))
    }else if(x < R & y < R){
      return(Cseg(x,R) + Cseg(y,R))
    }else if(x < R & y >= R){
      return(Cseg(x,R))
    }else if(x >= R & y < R){
      return(Cseg(y,R))
    }else{
      return(0)
    }}

  # numeric integration
  zseq <- seq(-r,r,by = dz)

  return((4/3)*pi*r^3 - sum(sapply(zseq, function(q){Carea(x,y,q,z,Rcalc(q,r))*dz})))
}

#### local.den.engine ####
#' Find the local intensity density estimate based on nearest neighbors.
#'
#' Helper for \code{\link{nndensity.pp3}}.
#'
#' @param bdist Result from \code{\link{bdist.points3.multi}} giving shortest
#'   distance to boundary in the x, y, and z directions.
#' @param nnk Result from \code{\link[spatstat]{nndist}} or
#'   \code{\link[spatstat]{nncross}} containing nearest neighbor distances.
#' @param k Vector of nn#s to calculate estimate for.
#' @param dz The spacing for numeric integration over the z direction to
#'   determine edge corrections.
#' @param par \code{TRUE} or \code{FALSE}: whether or not to calculate in
#'   parallel
#' @param cores If \code{par = TRUE}, this is the number of cores to use for the
#'   parallel calculation.
#'
#' @return A data.frame with intensity estimates for each value of k (# of
#'   nearest neighbors).
local.den.engine <- function(bdist, nnk, k, dz, par = TRUE, cores = 7){
  x <- bdist$x
  y <- bdist$y
  z <- bdist$z

  r <- as.list(nnk)
  ind.x <- 1:length(x)
  ind.k <- 1:length(k)

  if(par == TRUE){
    cl <- makePSOCKcluster(cores)
    clusterExport(cl,"local.den.onevol")
    clusterExport(cl,c("x","y","z","dz","k","r","ind.x","ind.k"), envir = environment())

    lambda.est <- parLapply(cl, ind.k, function(i.k){
      vols <- sapply(ind.x, function(i.x,rn){local.den.onevol(x[i.x],y[i.x],z[i.x],rn[i.x],dz)}, r[[i.k]])
      l.est <- k[i.k]/vols
      return(l.est)
    })

    stopCluster(cl)

  }else{
    lambda.est <- lapply(ind.k, function(i.k){
      vols <- sapply(ind.x, function(i.x,rn){local.den.onevol(x[i.x],y[i.x],z[i.x],rn[i.x],dz)}, r[[i.k]])
      l.est <- k[i.k]/vols
      return(l.est)
    })
  }

  res <- as.data.frame(lambda.est)
  names <- sapply(k,function(x){return(paste("nn",toString(x),sep = ""))})
  colnames(res) <- names

  return(res)
}
