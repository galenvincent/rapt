#### anomlocalK3est ####
#' Perform localK3est with 50th percentile of a RRL subtracted off.
#'
#' Similar to \code{\link{anomK3est}}, but returns the anomaly K3est for each
#' point in the pattern.
#'
#' @param X The \code{\link[spatstat]{pp3}} object to be tested.
#' @param toSub The vector of values to subtract from the square root of the
#'   results of the K function applied to X.
#' @param rmax See \code{\link[spatstat]{K3est}}.
#' @param nrval See \code{\link[spatstat]{K3est}}.
#'
#' @return Date frame with columns of the anomaly K test for each point in the
#'   pattern.

anomlocalK3est <- function(X, toSub, rmax, nrval){
  a <- localK3est(X, rmax = rmax, nrval = nrval, correction = "translation")
  for(i in 2:ncol(a)){
    a[,i] <- sqrt(a[,i])-toSub
  }

  return(a)
}

#### pK3est ####
#' Perform K3est on random relabelings in parallel
#'
#' \code{pK3est} first randomly relabels a specified percentage of points from
#' the original \code{\link[spatstat]{pp3}} object. It then performs a 3D K
#' function test (\code{\link[spatstat]{K3est}}) on these selected points. It
#' repeats this as many times as specified. These tests are run in parallel to
#' increase computation speed.
#'
#' @param perc The fraction of points to select randomly each time out of the
#'   original \code{\link[spatstat]{pp3}} object. Number between 0 and 1.
#' @param pattern The original \code{\link[spatstat]{pp3}} object.
#' @param nEvals The number of random relabelings and  that should be performed.
#' @param rmax See \code{\link[spatstat]{K3est}}. Maximum radius to be
#'   calculated for \code{\link[spatstat]{K3est}}.
#' @param nrval See \code{\link[spatstat]{K3est}}. Number of radii that
#'   \code{\link[spatstat]{K3est}} should be calculated at.
#' @param correction Either "iso", "trans", or "bord" edge correction.
#' @param anom Whether or not to retun the anomaly results. \code{TRUE} or
#' \code{FALSE}. See section below for more info.
#' @param toSub The numeric vector of data to subtract for the "anom" pK3est.
#'   Only used when \code{anom = TRUE}. See below for more info.
#' @param sorted Whether to return a sorted table of RRLs (TRUE) or an unsorted
#'   one, where the RRLs are in their original rows.
#' @section Edge Corrections: See \code{\link[spatstat]{Kest}} or book availible
#'   at \url{http://spatstat.org/book.html} for more info on these edge
#'   corrections.
#'
#' \subsection{Isotropic - "iso"}{Isotropic edge correction. Assumes point
#' pattern is isotropic, or that it can rotate in space without changing
#' statistics.}
#' \subsection{Translation - "trans"}{Translation edge correction. Assumes
#' translation of point pattern does not change statistics.}
#' \subsection{Border - "bord"}{Border edge correction. Makes no assumptions
#' about data. Uses only data provided in the original point pattern. Only
#' evaluates \code{\link[spatstat]{K3est}} when the radius of the search stays
#' within the domain of the point pattern itself.}
#'
#' @section Anomaly K3est:
#' When \code{anom = TRUE}, the function returns the anomaly K3est.This means
#' that it returns the square root of the \code{\link[spatstat]{K3est}} results,
#' with the 50th percentile subtracted out. This centers envelopes around zero,
#' and the square root standardized variance across all r values. See book at
#' \url{http://spatstat.org/book.html} for a good statistical reference.
#'
#' \code{toSub} is an argumet to be paired with \code{anom = TRUE}. If NULL, use
#' the 50th percentile of the calculated set of \code{\link[spatstat]{K3est}}
#' envelopes to subtract off. Otherwise, use the second, [[2]], entry in the
#' list returned from this same function. This is how to compare envelope
#' calculations from different point patterns. You must subtract the same values
#' from both data sets. toSub allows you to input the values that were
#' subtracted from a previous set of envelopes, for comparison.
#'
#' @return
#' \subsection{For \code{anom = FALSE}}{Returns a matrix containing the data
#' from the all of the \code{\link[spatstat]{K3est}} runs on different
#' re-labelings. Can plot data using \code{\link{envPlot}}.}
#' \subsection{For \code{anom = TRUE}}{A list of: [[1]] Matrix of data for all
#' relabelings. Can be plotted using \code{\link{envPlot}}. [[2]] Vector
#' containing the values that were subtracted from the results at each r value.
#' Can be used to subtract from another set of envelopes for comparison. [[3]]
#' rmax used in the calculation. [[4]] nrval used in the calculation.}

pK3est <- function(perc, pattern, nEvals,rmax=NULL,nrval=128,correction="trans",anom=FALSE,toSub=NULL, sorted=TRUE){

  #find cores and initialize the cluster
  cores2use <- detectCores()-1
  cl <- makePSOCKcluster(cores2use)
  clusterExport(cl,"percentSelect")
  clusterExport(cl,c("pattern","rmax","nrval","correction"), envir = environment())
  clusterEvalQ(cl,library(spatstat))

  percents <- as.list(rep(perc, nEvals))

  ### old, heavy memory usage
  #toTest <- parLapply(cl,percents,function(x){
  #  percentSelect(x,pattern)
  #})

  # apply K3est function to each of the pp3 patterns in parallel
  if(correction=="iso"){
    result <- parLapply(cl,percents,function(x){
      K3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "isotropic")
    })
  }else if(correction=="trans"){
    result <- parLapply(cl,percents,function(x){
      K3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "translation")
    })
  }else if(correction=="bord"){
    clusterExport(cl,"bK3est")
    clusterExport(cl,"bdist.points3")
    result <- parLapply(cl,percents,function(x){
      bK3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval)
    })
    if(is.null(result[[1]])){
      print("rmax is too large for border correction.")
      stopCluster(cl)
      return()
    }
  }else{
    print("Please input valid correction argument.")
    return()
  }

  # stop the cluster and revert computer to normal
  stopCluster(cl)

  #fill matrix with results
  tst.length <- length(result[[1]]$r)
  tests <- matrix(0,nrow=tst.length,ncol=(nEvals+1))
  tests[,1] <- result[[1]]$r

  # convert the results into the matrix tests
  for(i in 1:length(result)){
    if(correction=="iso"){
      tests[,(1+i)] <- result[[i]]$iso
    }else if(correction == "trans"){
      tests[,(1+i)] <- result[[i]]$trans
    }else if(correction == "bord"){
      tests[,(1+i)] <- result[[i]]$bord
    }
  }

  # Convert to anomaly deviation or not
  if (anom == FALSE){
    # If not, just return the regular tests matrix
    return(tests)

  }else if (anom == TRUE){
    # If yes, sort the values, take the sqare root (to keep variance constant over r)
    # then subtract toSub from another pattern or from the 50th perentile of this
    # pattern. Return the results.
    tvals <- tests[,2:ncol(tests)]
    tvals <- sqrt(tvals)

    tvals_sorted <- t(apply(tvals,1,sort))

#browser()

    if(is.null(toSub)){
      if(nEvals%%2==0){
        top <- nEvals/2
        bot <- top+1
        toSub <- (tvals_sorted[,top]+tvals_sorted[,bot])/2
      }else {
        toSub <- tvals_sorted[,(round(nEvals/2))]
      }
    }

#browser()
    if(sorted == TRUE){
      tvals <- apply(tvals_sorted,2,function(x){
        x-toSub})
    }else{
      tvals <- apply(tvals,2,function(x){
        x-toSub})
    }

#browser()

    tests <- cbind(tests[,1],tvals)

    return(list(tests,toSub,rmax,nrval))
  }
}

#### anomK3est ####
#' Perfrom anomaly K3est on a \code{\link[spatstat]{pp3}} object.
#'
#' See \code{\link[spatstat]{K3est}}. Performs the anomaly K3est on a set of
#' point cloud data. This means taking the square root, and subtracting the 50th
#' percentile from the results. This centers the curve around zero, and
#' standardizeds the variance at different radii. Used for comparing data to
#' envelopes from \code{\link{pK3est}} where \code{anom = TRUE}. Will subtract
#' the same values used in the pK3est test that is being compared to.
#'
#' @param pattern The \code{\link[spatstat]{pp3}} object to analyze.
#' @param toSub Returned from \code{\link{pK3est}} with \code{anom = TRUE}.
#'   Second item in the returned list. The data to subtract from the results.
#' @param rmax Max r value. See \code{\link[spatstat]{K3est}}. Should be the
#'   same as the envelopes that you are comparing to.
#' @param nrval Number of r values. See \code{\link[spatstat]{K3est}}. Should be
#'   the same as the envelopes that you are comparing to.
#' @param correction See \code{\link{pK3est}}.
#'
#' @return Returns data fram containing r values and associated anomaly K3est
#'   values.

anomK3est <- function(pattern,toSub,rmax,nrval,correction = "trans"){

  if(correction == "iso"){
    a <- K3est(pattern,rmax=rmax,nrval=nrval,correction="isotropic")
    tvals <- sqrt(a$iso) - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","iso")
    return(b)

  }else if(correction == "trans"){
    a <- K3est(pattern,rmax=rmax,nrval=nrval,correction="translation")
    tvals <- sqrt(a$trans) - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","trans")
    return(b)

  }else if(correction == "bord"){
    a <- bK3est(pattern,rmax=rmax,nrval=nrval)
    tvals <- sqrt(a$bord) - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","bord")
    return(b)

  }else if(correction == "all"){
    b <- matrix(0,nrow=nrval,ncol=3)

    a <- K3est(pattern,rmax=rmax,nrval=nrval)
    b[,2] <- sqrt(a$iso) - toSub
    b[,3] <-  sqrt(a$trans) - toSub
    b[,1] <- a$r

    b <- as.data.frame(b)
    colnames(b)<-c("r","iso","trans")

    return(b)
  }else{
    print("Please input valid correction argument.")
    return()
  }
}

#### pG3est ####
#' Perform G3est on random relabelings in parallel
#'
#' \code{pG3est} first randomly relabels a specified percentage of points from
#' the original \code{\link[spatstat]{pp3}} object. It then performs a 3D G
#' function test (\code{\link[spatstat]{G3est}}) on these selected points. It
#' repeats this as many times as specified. These tests are run in parallel to
#' increase computation speed.
#'
#' @param perc The fraction of points to select randomly each time out of the
#'   original \code{\link[spatstat]{pp3}} object. Number between 0 and 1.
#' @param pattern The original \code{\link[spatstat]{pp3}} object.
#' @param nEvals The number of random relabelings and  that should be performed.
#' @param rmax See \code{\link[spatstat]{G3est}}. Maximum radius to be
#'   calculated for \code{\link[spatstat]{G3est}}.
#' @param nrval See \code{\link[spatstat]{G3est}}. Number of radii that
#'   \code{\link[spatstat]{G3est}} should be calculated at.
#' @param correction Either "rs", "km", or "Hanisch" edge correction.
#' @param anom Whether or not to retun the anomaly results. \code{TRUE} or
#'   \code{FALSE}. See section below for more info.
#' @param toSub The numeric vector of data to subtract for the "anom" pG3est.
#'   Only used when \code{anom = TRUE}. See below for more info.
#' @section Edge Corrections: See  book availible at
#'   \url{http://spatstat.org/book.html} for more info on these edge
#'   corrections.
#'
#' \subsection{Reduced Sample - "rs"}{}
#' \subsection{Kaplan-Meier - "km"}{}
#' \subsection{Hanisch - "Hanisch"}{}
#'
#' @section Anomaly G3est:
#' When \code{anom = TRUE}, the function returns the anomaly
#' \code{\link[spatstat]{G3est}}.This means that it returns the
#' \code{\link[spatstat]{G3est}} results with the 50th percentile subtracted
#' out. This centers envelopes around zero.
#'
#' \code{toSub} is an argumet to be paired with \code{anom = TRUE}. If NULL, use
#' the 50th percentile of the calculated set of \code{\link[spatstat]{G3est}}
#' envelopes to subtract off. Otherwise, use the second, [[2]], entry in the
#' list returned from this same function. This is how to compare envelope
#' calculations from different point patterns. You must subtract the same values
#' from both data sets. toSub allows you to input the values that were
#' subtracted from a previous set of envelopes, for comparison.
#'
#' @return
#' \subsection{For \code{anom = FALSE}}{Returns a matrix containing the data
#' from the all of the \code{\link[spatstat]{G3est}} runs on different
#' re-labelings. Can plot data using \code{\link{envPlot}}.}
#' \subsection{For \code{anom = TRUE}}{A list of: [[1]] Matrix of data for all
#' relabelings. Can be plotted using \code{\link{envPlot}}. [[2]] Vector
#' containing the values that were subtracted from the results at each r value.
#' Can be used to subtract from another set of envelopes for comparison. [[3]]
#' rmax used in the calculation. [[4]] nrval used in the calculation.}

pG3est <- function(perc, pattern, nEvals,rmax=NULL,nrval=128,correction="rs",anom=FALSE,toSub=NULL){

  #find cores and initialize the cluster
  cores2use <- detectCores()-1
  cl <- makePSOCKcluster(cores2use)
  clusterExport(cl,"percentSelect")
  clusterExport(cl,c("pattern","rmax","nrval","correction"), envir = environment())
  clusterEvalQ(cl,library(spatstat))

  percents <- as.list(rep(perc, nEvals))

  #toTest <- parLapply(cl,percents,function(x){
  #  percentSelect(x,pattern)
  #})

  # apply G3est function to each of the pp3 patterns in parallel
  if(correction=="rs"){
    result <- parLapply(cl,percents,function(x){
      G3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "rs")
    })
  }else if(correction=="km"){
    result <- parLapply(cl,percents,function(x){
      G3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "km")
    })
  }else if(correction=="Hanisch"){
    result <- parLapply(cl,percents,function(x){
      G3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "Hanisch")
    })
  }else{
    print("Please input valid correction argument.")
    return()
  }

  # stop the cluster and revert computer to normal
  stopCluster(cl)

  #fill matrix with results
  tst.length <- length(result[[1]]$r)
  tests <- matrix(0,nrow=tst.length,ncol=(nEvals+1))
  tests[,1] <- result[[1]]$r

  # convert the results into the matrix tests
  for(i in 1:length(result)){
    if(correction=="rs"){
      tests[,(1+i)] <- result[[i]]$rs
    }else if(correction == "km"){
      tests[,(1+i)] <- result[[i]]$km
    }else if(correction == "Hanisch"){
      tests[,(1+i)] <- result[[i]]$han
    }
  }

  # Convert to anomaly deviation or not
  if (anom == FALSE){
    # If not, just return the regular tests matrix
    return(tests)

  }else if (anom == TRUE){
    # If yes, sort the values, subtract toSub from another pattern or from the 50th perentile of this
    # pattern. Return the results.
    tvals <- tests[,2:ncol(tests)]
    #tvals <- sqrt(tvals)
    tvals <- t(apply(tvals,1,sort))

    if(is.null(toSub)){
      if(nEvals%%2==0){
        top <- nEvals/2
        bot <- top+1
        toSub <- (tvals[,top]+tvals[,bot])/2
      }else {
        toSub <- tvals[,(round(nEvals/2))]
      }

      tvals <- apply(tvals,2,function(x){
        x-toSub
      })
    }else{
      tvals <- apply(tvals,2,function(x){
        x-toSub
      })
    }

    tests <- cbind(tests[,1],tvals)

    return(list(tests,toSub,rmax,nrval))
  }
}

#### anomG3est ####
#' Perfrom anomaly G3est on a \code{\link[spatstat]{pp3}} object.
#'
#' See \code{\link[spatstat]{G3est}}. Performs the anomaly G3est on a set of
#' point cloud data. This means subtracting the 50th percentile from the
#' results. This centers the curve around zero. Used for comparing data to
#' envelopes from \code{\link{pG3est}} where \code{anom = TRUE}. Will subtract
#' the same values used in the pG3est test that is being compared to.
#'
#' @param pattern The \code{\link[spatstat]{pp3}} object to analyze.
#' @param toSub Returned from \code{\link{pK3est}} with \code{anom = TRUE}.
#'   Second item in the returned list. The data to subtract from the results.
#' @param rmax Max r value. See \code{\link[spatstat]{G3est}}. Should be the
#'   same as the envelopes that you are comparing to.
#' @param nrval Number of r values. See \code{\link[spatstat]{G3est}}. Should be
#'   the same as the envelopes that you are comparing to.
#' @param correction See \code{\link{pG3est}}. "rs", "km", "Hanisch", or "all".
#'
#' @return Returns data fram containing r values and associated anomaly G3est
#'   values.

anomG3est <- function(pattern,toSub,rmax,nrval,correction = "rs"){

  if(correction == "rs"){
    a <- G3est(pattern,rmax=rmax,nrval=nrval,correction="rs")
    tvals <- a$rs - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","rs")
    return(b)

  }else if(correction == "km"){
    a <- G3est(pattern,rmax=rmax,nrval=nrval,correction="km")
    tvals <- a$km - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","km")
    return(b)

  }else if(correction == "Hanisch"){
    a <- G3est(pattern,rmax=rmax,nrval=nrval,correction="Hanisch")
    tvals <- a$han - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","han")
    return(b)

  }else if(correction == "all"){
    b <- matrix(0,nrow=nrval,ncol=4)

    a <- G3est(pattern,rmax=rmax,nrval=nrval)
    b[,2] <- a$rs - toSub
    b[,3] <- a$km - toSub
    b[,4] <- a$han - toSub
    b[,1] <- a$r

    b <- as.data.frame(b)
    colnames(b)<-c("r","rs","km","han")

    return(b)
  }else{
    print("Please input valid correction argument.")
    return()
  }
}


#### pF3est ####
#' Perform F3est on random relabelings in parallel
#'
#' \code{pF3est} first randomly relabels a specified percentage of points from
#' the original \code{\link[spatstat]{pp3}} object. It then performs a 3D F
#' function test (\code{\link[spatstat]{F3est}}) on these selected points. It
#' repeats this as many times as specified. These tests are run in parallel to
#' increase computation speed.
#'
#' @param perc The fraction of points to select randomly each time out of the
#'   original \code{\link[spatstat]{pp3}} object. Number between 0 and 1.
#' @param pattern The original \code{\link[spatstat]{pp3}} object.
#' @param nEvals The number of random relabelings and  that should be performed.
#' @param rmax See \code{\link[spatstat]{F3est}}. Maximum radius to be
#'   calculated for \code{\link[spatstat]{F3est}}.
#' @param nrval See \code{\link[spatstat]{F3est}}. Number of radii that
#'   \code{\link[spatstat]{F3est}} should be calculated at.
#' @param correction Either "rs", "km", or "cs" edge correction.
#' @param anom Whether or not to retun the anomaly results. \code{TRUE} or
#'   \code{FALSE}. See section below for more info.
#' @param toSub The numeric vector of data to subtract for the "anom" pF3est.
#'   Only used when \code{anom = TRUE}. See below for more info.
#' @section Edge Corrections: See  book availible at
#'   \url{http://spatstat.org/book.html} for more info on these edge
#'   corrections.
#'
#' \subsection{Reduced Sample - "rs"}{}
#' \subsection{Kaplan-Meier - "km"}{}
#' \subsection{Chiu-Stoyan (aka Hanisch) - "cs"}{}
#'
#' @section Anomaly F3est:
#' When \code{anom = TRUE}, the function returns the anomaly
#' \code{\link[spatstat]{F3est}}.This means that it returns the
#' \code{\link[spatstat]{F3est}} results with the 50th percentile subtracted
#' out. This centers envelopes around zero.
#'
#' \code{toSub} is an argumet to be paired with \code{anom = TRUE}. If NULL, use
#' the 50th percentile of the calculated set of \code{\link[spatstat]{F3est}}
#' envelopes to subtract off. Otherwise, use the second, [[2]], entry in the
#' list returned from this same function. This is how to compare envelope
#' calculations from different point patterns. You must subtract the same values
#' from both data sets. toSub allows you to input the values that were
#' subtracted from a previous set of envelopes, for comparison.
#'
#' @return
#' \subsection{For \code{anom = FALSE}}{Returns a matrix containing the data
#' from the all of the \code{\link[spatstat]{F3est}} runs on different
#' re-labelings. Can plot data using \code{\link{envPlot}}.}
#' \subsection{For \code{anom = TRUE}}{A list of: [[1]] Matrix of data for all
#' relabelings. Can be plotted using \code{\link{envPlot}}. [[2]] Vector
#' containing the values that were subtracted from the results at each r value.
#' Can be used to subtract from another set of envelopes for comparison. [[3]]
#' rmax used in the calculation. [[4]] nrval used in the calculation.}

pF3est <- function(perc, pattern, nEvals,rmax=NULL,nrval=128,correction="rs",anom=FALSE,toSub=NULL){

  #find cores and initialize the cluster
  cores2use <- detectCores()-1
  cl <- makePSOCKcluster(cores2use)
  clusterExport(cl,"percentSelect")
  clusterExport(cl,c("pattern","rmax","nrval","correction"),envir = environment())
  clusterEvalQ(cl,library(spatstat))

  percents <- as.list(rep(perc, nEvals))

  #toTest <- parLapply(cl,percents,function(x){
  #  percentSelect(x,pattern)
  #})

  # apply F3est function to each of the pp3 patterns in parallel
  if(correction=="rs"){
    result <- parLapply(cl,percents,function(x){
      F3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "rs")
    })
  }else if(correction=="km"){
    result <- parLapply(cl,percents,function(x){
      F3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "km")
    })
  }else if(correction=="cs"){
    result <- parLapply(cl,percents,function(x){
      F3est(percentSelect(x,pattern),rmax=rmax,nrval=nrval,correction = "cs")
    })
  }else{
    print("Please input valid correction argument.")
    return()
  }

  # stop the cluster and revert computer to normal
  stopCluster(cl)

  #fill matrix with results
  tst.length <- length(result[[1]]$r)
  tests <- matrix(0,nrow=tst.length,ncol=(nEvals+1))
  tests[,1] <- result[[1]]$r

  # convert the results into the matrix tests
  for(i in 1:length(result)){
    if(correction=="rs"){
      tests[,(1+i)] <- result[[i]]$rs
    }else if(correction == "km"){
      tests[,(1+i)] <- result[[i]]$km
    }else if(correction == "cs"){
      tests[,(1+i)] <- result[[i]]$cs
    }
  }

  # Convert to anomaly deviation or not
  if (anom == FALSE){
    # If not, just return the regular tests matrix
    return(tests)

  }else if (anom == TRUE){
    # If yes, sort the values, subtract toSub from another pattern or from the 50th perentile of this
    # pattern. Return the results.
    tvals <- tests[,2:ncol(tests)]
    #tvals <- sqrt(tvals)
    tvals <- t(apply(tvals,1,sort))

    if(is.null(toSub)){
      if(nEvals%%2==0){
        top <- nEvals/2
        bot <- top+1
        toSub <- (tvals[,top]+tvals[,bot])/2
      }else {
        toSub <- tvals[,(round(nEvals/2))]
      }

      tvals <- apply(tvals,2,function(x){
        x-toSub
      })
    }else{
      tvals <- apply(tvals,2,function(x){
        x-toSub
      })
    }

    tests <- cbind(tests[,1],tvals)

    return(list(tests,toSub,rmax,nrval))
  }
}

#### anomF3est ####
#' Perfrom anomaly F3est on a \code{\link[spatstat]{pp3}} object.
#'
#' See \code{\link[spatstat]{F3est}}. Performs the anomaly F3est on a set of
#' point cloud data. This means subtracting the 50th percentile from the
#' results. This centers the curve around zero. Used for comparing data to
#' envelopes from \code{\link{pF3est}} where \code{anom = TRUE}. Will subtract
#' the same values used in the pF3est test that is being compared to.
#'
#' @param pattern The \code{\link[spatstat]{pp3}} object to analyze.
#' @param toSub Returned from \code{\link{pK3est}} with \code{anom = TRUE}.
#'   Second item in the returned list. The data to subtract from the results.
#' @param rmax Max r value. See \code{\link[spatstat]{F3est}}. Should be the
#'   same as the envelopes that you are comparing to.
#' @param nrval Number of r values. See \code{\link[spatstat]{F3est}}. Should be
#'   the same as the envelopes that you are comparing to.
#' @param correction See \code{\link{pF3est}}. "rs", "km", "cs", or "all".
#'
#' @return Returns data fram containing r values and associated anomaly F3est
#'   values.

anomF3est <- function(pattern,toSub,rmax,nrval,correction = "rs"){

  if(correction == "rs"){
    a <- F3est(pattern,rmax=rmax,nrval=nrval,correction="rs")
    tvals <- a$rs - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","rs")
    return(b)

  }else if(correction == "km"){
    a <- F3est(pattern,rmax=rmax,nrval=nrval,correction="km")
    tvals <- a$km - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","km")
    return(b)

  }else if(correction == "cs"){
    a <- F3est(pattern,rmax=rmax,nrval=nrval,correction="cs")
    tvals <- a$cs - toSub
    b <- as.data.frame(cbind(a$r,tvals))
    colnames(b)<-c("r","cs")
    return(b)

  }else if(correction == "all"){
    b <- matrix(0,nrow=nrval,ncol=4)

    a <- F3est(pattern,rmax=rmax,nrval=nrval)
    b[,2] <- a$rs - toSub
    b[,3] <- a$km - toSub
    b[,4] <- a$cs - toSub
    b[,1] <- a$r

    b <- as.data.frame(b)
    colnames(b)<-c("r","rs","km","cs")

    return(b)
  }else{
    print("Please input valid correction argument.")
    return()
  }
}


############## Helper Functions #################

#### bK3est ####
#' 3D Border correction for K3est
#'
#' Helper function for \code{\link{pK3est}}. This function is a hand written
#' extension of the border correction for 3D point patterns.
#'
#' @param X The point pattern for analysis. \code{\link[spatstat]{pp3}} object.
#' @param rmax See \code{\link[spatstat]{K3est}}. Maximum radius to be
#'   calculated for \code{\link[spatstat]{K3est}}.
#' @param nrval See \code{\link[spatstat]{K3est}}. Number of radii that
#'   \code{\link[spatstat]{K3est}} should be calculated at.
#' @return Border corrected \code{\link[spatstat]{K3est}} data for object X.

bK3est <- function(X,rmax=NULL,nrval=128){

  verifyclass(X,"pp3")

  bi <- bdist.points3(X)
  n <- npoints(X)
  lambda <- n/volume(domain(X))

  if(is.null(rmax)){
    rmax <- max(bi)
  }else if(rmax > max(bi)){
    print("rmax is too large for data set")
    return()
  }

  cp <- closepairs(X,rmax,twice=FALSE,what="indices")
  cpm <- cbind(cp[[1]],cp[[2]])
  cpm<-cpm[order(cpm[,1]),]
  distmat <- as.matrix(dist(coords(X)))
  cpmdist <- rep(0,nrow(cpm))
  for(i in 1:nrow(cpm)){
    temp <- sort(cpm[i,])
    cpmdist[i] <- distmat[temp[2],temp[1]]
  }

  rlist <- seq(from=0,to=rmax,length.out=nrval)
  Kb <- rep(0,nrval)

  np <- 0
  for(i in 1:n){
    if(bi[i] >= rmax){
      np <- np + 1
    }
  }

  for(j in 1:length(rlist)){
    t <- 0
    r <- rlist[j]
    for(i in 1:nrow(cpm)){
      if(cpmdist[i] <= r){
        if((bi[cpm[i,1]] >= rmax) & (bi[cpm[i,2]] >= rmax)){
          t <- t + 2
        }else if((bi[cpm[i,1]] < rmax) & (bi[cpm[i,2]] < rmax)){
        }else{
          t <- t + 1
        }
      }
    }
    Kb[j] <- t/(lambda*np)
  }

  K <- as.data.frame(cbind(rlist,Kb))
  colnames(K)<-c("r","bord")

  return(K)
}

#### bdist.points3 ####
#' Helper function for border correction \code{\link{bK3est}}.
#'
#' Finds the smallest distance to a boundary for each point in a point pattern.
#'
#' @param X The point pattern for analysis. A \code{\link[spatstat]{pp3}} object.
#' @return An object containing the shortest distance to the boundary for each
#'   point in the pattern X.

bdist.points3 <- function (X) {

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
  result <- pmin.int(x - xmin, xmax - x, y - ymin, ymax - y , z - zmin , zmax - z)

  return(result)
}

