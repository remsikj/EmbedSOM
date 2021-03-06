# This file is part of EmbedSOM.
#
# Copyright (C) 2018-2020 Mirek Kratochvil <exa.exa@gmail.com>
#
# EmbedSOM is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# EmbedSOM is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with EmbedSOM. If not, see <https://www.gnu.org/licenses/>.


#' Helper for computing colors for embedding plots
#'
#' @param data Vector of scalar values to normalize between 0 and 1
#' @param low,high Originally quantiles for clamping the color.
#'                 Only kept for backwards compatibility, now ignored.
#' @param sds Inverse scale factor for measured standard deviation
#'            (greater value makes data look more extreme)
#' @param pow The scaled data are transformed to data^(2^pow). If set to 0,
#'            nothing happens. Positive values highlight differences in the
#'            data closer to 1, negative values highlight differences closer to 0.
#' @examples
#' EmbedSOM::NormalizeColor(c(1,100,500))
#' @export
NormalizeColor <- function(data, low=NULL, high=NULL, pow=0, sds=1) {
  if(!is.null(low) || !is.null(high))
    warning("Obsolete NormalizeColor parameters low, high will be removed in future release.")

  data <- data-mean(data, na.rm=T)
  sdev <- stats::sd(data, na.rm=T)
  if(sdev==0) sdev <- 1
  stats::pnorm(data, sd=sdev/sds)^(2^pow)
}

#' Marker expression palette generator based off ColorBrewer's RdYlBu,
#' only better for plotting of half-transparent cells
#'
#' @param n How many colors to generate
#' @param alpha Opacity of the colors
#' @examples
#' EmbedSOM::ExpressionPalette(10)
#' @export
ExpressionPalette <- function(n, alpha=1) {
  pal <- rev(c(
    "#A50026",
    "#D73027",
    "#F46D43",
    "#FDAE61",
    "#FEE090",
    "#FFFFA8", # this was darkened a bit
    "#B8D9C8", # this was converted to gray from almost-white
    "#91C3E2", # and the rest got darkened a bit
    "#649DD1",
    "#3565B4",
    "#212695"))

  grDevices::adjustcolor(alpha=alpha,
    col=grDevices::colorRampPalette(pal, space='Lab', interpolate='linear')(n))
}

#' An acceptable cluster color palette
#'
#' @param n How many colors to generate
#' @param vcycle,scycle Small vectors with cycles of saturation/value for hsv
#' @param alpha Opacity of the colors
#' @examples
#' EmbedSOM::ClusterPalette(10)
#' @export
ClusterPalette <- function(n, vcycle=c(1,0.7), scycle=c(0.7,1), alpha=1)
{
  if(n<=0) c()
  else grDevices::hsv(alpha=alpha, h=c(0:(n-1))/n, v=vcycle, s=scycle)
}

#' Generate colors for multi-color marker expression labeling in a single plot
#'
#' @param exprs Matrix-like object with marker expressions (extract it manually from your data)
#' @param base,scale Base(s) and scale(s) for softmax (convertible to numeric vectors of size `1+ncol(exprs)`)
#' @param pow Obsolete, now renamed to `scale`.
#' @param cutoff Gray level (expressed in sigmas of the sample distribution)
#' @param col Colors to use, defaults to colors taken from 'ClusterPalette'
#' @param nocolor The color to use for sub-gray-level expression, default gray.
#' @param alpha Default alpha value.
#' @examples
#' d <- cbind(rnorm(1e5), rexp(1e5))
#' EmbedSOM::PlotEmbed(d, col=EmbedSOM::ExprColors(d, pow=2))
#' @export
ExprColors <- function(exprs,
                       base=exp(1),
                       scale=1,
                       cutoff=0,
                       pow=NULL,
                       col=ClusterPalette(dim(exprs)[2], alpha=alpha),
                       nocolor=grDevices::rgb(0.75, 0.75, 0.75, alpha/2),
                       alpha=0.5) {
  # backwards compatibility
  if(!is.null(pow)) scale<-pow

  colM <- grDevices::col2rgb(alpha=T, c(col, nocolor)) %*%
    apply(rbind(t(scale(exprs)),cutoff),
          2, function(v) (base^(v*scale))/sum(base^(v*scale)))

  grDevices::rgb(
      red  =colM[1,],
      green=colM[2,],
      blue =colM[3,],
      alpha=colM[4,],
      maxColorValue=255)
}

#' Identity on whatever
#'
#' @param x Just the x.
#' @return The x.
PlotId <- function(x)x

#' Default plot
#'
#' @param pch,cex,... correctly defaulted and passed to 'plot'
#' @export
PlotDefault <- function(pch='.', cex=1, ...) graphics::plot(..., pch=pch, cex=cex)

#' Helper function for plotting the embedding
#'
#' Convenience plotting function. Takes the `embed` matrix which is the output of
#' [EmbedSOM()], together with a multitude of arguments that set how the plotting
#' is done.
#'
#' @param embed The embedding from [EmbedSOM()], or generally any 2-column matrix of coordinates
#' @param data Data matrix, taken from `fsom` parameter by default
#' @param fsom FlowSOM object
#' @param value The column of `data` to use for coloring the plotted points
#' @param red,green,blue The same, for individual RGB components
#' @param fv,fr,fg,fb Functions to transform the values before they are normalized
#' @param powv,powr,powg,powb Passed to corresponding [NormalizeColor()] calls as `pow`
#' @param sdsv,sdsr,sdsg,sdsb Passed to [NormalizeColor()] as `sds`
#' @param nbin,maxDens,fdens Parameters of density calculation, see [PlotData()]
#' @param limit Low/high offset for [NormalizeColor()] (obsolete&ignored, will be removed)
#' @param clust Cluster labels (used as a factor)
#' @param alpha Default alpha value of points
#' @param col Overrides the computed point colors with exact supplied colors.
#' @param cluster.colors Function to generate cluster colors, default [ClusterPalette()]
#' @param expression.colors Function to generate expression color scale, default [ExpressionPalette()]
#' @param plotf Plot function, defaults to [graphics::plot()] slightly decorated with `pch='.', cex=1`
#' @param na.color Color to assign to `NA` values
#' @param ... Extra params passed to the plot function
#' @examples
#' EmbedSOM::PlotEmbed(cbind(rnorm(1e5),rnorm(1e5)))
#' @export
PlotEmbed <- function(embed,
  value=0, red=0, green=0, blue=0,
  fr=PlotId, fg=PlotId, fb=PlotId, fv=PlotId,
  powr=0, powg=0, powb=0, powv=0,
  sdsr=1, sdsg=1, sdsb=1, sdsv=1,
  clust=NULL,
  nbin=256, maxDens=NULL, fdens=sqrt,
  limit=NULL, alpha=NULL, fsom, data, col,
  cluster.colors=ClusterPalette,
  expression.colors=ExpressionPalette,
  na.color=grDevices::rgb(0.75,0.75,0.75,if(is.null(alpha))0.5 else alpha/2),
  plotf=PlotDefault, ...) {
  if(missing(col)) {

    if(!is.null(limit))
      warning("PlotEmbed parameter 'limit' does nothing and will be removed in future releases.")

    if(dim(embed)[2]!=2) stop ("PlotEmbed only works for 2-dimensional embedding")

    if (!is.null(clust)) {
      if(length(clust)==1) {
        if(missing(data)) {
          data <- fsom$data
        }
        cdata <- data[,clust]
      }
      else cdata <- clust
      clust <- as.factor(clust)

      if(length(levels(clust))==0) col <- na.color
      else col <- cluster.colors(length(levels(clust)), alpha=alpha)[as.numeric(clust)]
    } else if(value==0 & red==0 & green==0 & blue==0) {
      if(is.null(alpha)) alpha <- 1
      mins <- apply(embed,2,min)
      maxs <- apply(embed,2,max)
      if(mins[1]==maxs[1]) {mins[1]<-mins[1]-1; maxs[1]<-maxs[1]+1}
      if(mins[2]==maxs[2]) {mins[2]<-mins[2]-1; maxs[2]<-maxs[2]+1}
      xbin <- cut(embed[,1], mins[1]+(maxs[1]-mins[1])*c(0:nbin)/nbin, labels=FALSE)
      ybin <- cut(embed[,2], mins[2]+(maxs[2]-mins[2])*c(0:nbin)/nbin, labels=FALSE)

      dens <- tabulate(xbin+(nbin+1)*ybin)[xbin+(nbin+1)*ybin]
      if(!is.null(maxDens)) dens[dens>maxDens] <- maxDens
      dens <- fdens(dens)
      pal <- cut(dens, length(dens), labels=FALSE)
      n <- length(dens)
      col <- expression.colors(256, alpha=alpha)[1+as.integer(255*pal/n)]
    } else if(value==0) {
      if(missing(data)) {
        data <- fsom$data
      }
      if(is.null(alpha)) alpha <- 0.5
      col <- grDevices::rgb(
        if(red>0)   NormalizeColor(fr(data[,red]),   pow=powr, sds=sdsr) else 0,
        if(green>0) NormalizeColor(fg(data[,green]), pow=powg, sds=sdsg) else 0,
        if(blue>0)  NormalizeColor(fb(data[,blue]),  pow=powb, sds=sdsb) else 0,
      alpha)
    } else {
      if(missing(data)) {
        data <- fsom$data
      }
      if(is.null(alpha)) alpha <- 0.5
      col <- expression.colors(256,alpha=alpha)[1+255*NormalizeColor(fv(data[,value]), pow=powv, sds=sdsv)]
    }
  }

  col[is.na(col)]<-na.color
  plotf(x=embed, col=col, xaxt='n', yaxt='n', ...)
}

#' Export a data frame for plotting with marker intensities and density.
#'
#' @param embed,fsom,data,cols The embedding data, columns to select
#' @param names Column names for output
#' @param normalize List of columns to normalize using [NormalizeColor()], default all
#' @param pow,sds Parameters for the normalization
#' @param vf Custom value-transforming function
#' @param density Name of the density column
#' @param densBins Number of bins for density calculation
#' @param densLimit Upper limit of density (prevents outliers)
#' @param fdens Density-transforming function; default sqrt
#' @export
PlotData <- function(embed,
  fsom, data=fsom$data, cols, names,
  normalize=cols, pow=0, sds=1, vf=PlotId,
  density='Density', densBins=256, densLimit=NULL, fdens=sqrt
  ) {
  if(dim(embed)[2]!=2) stop ("PlotData only works for 2-dimensional embedding")

  if(missing(cols)) {
    cols <- colnames(data)
  }

  df <- data.frame(EmbedSOM1=embed[,1], EmbedSOM2=embed[,2])

  if(is.null(cols)) {
    #no cols to add :]
  } else {
    ddf <- data.frame(data[,cols])
    if(missing(names)) {
      if(missing(fsom)) names <- cols
      else names <- fsom$prettyColnames[cols]
    }

    colnames(ddf) <- cols
    cols <- colnames(ddf) # you may feel offended but I'm ok. :-/

    ncol <- length(normalize)
    pow <- rep_len(pow, ncol)
    sds <- rep_len(sds, ncol)
    vf <- rep_len(c(vf), ncol)

    for(i in c(1:length(normalize)))
      ddf[,normalize[i]] <- NormalizeColor(
        vf[[i]](ddf[,normalize[i]]),
        pow=pow[i], sds=sds[i])

    colnames(ddf) <- names
    df <- data.frame(df, ddf)
  }

  if(!is.null(density)) {
    densBins <- rep_len(densBins, 2)
    xbin <- cut(embed[,1], breaks=densBins[1], labels=FALSE)
    ybin <- cut(embed[,2], breaks=densBins[2], labels=FALSE)

    dens <- tabulate(xbin+(densBins[1]+1)*ybin)[xbin+(densBins[1]+1)*ybin]
    if(!is.null(densLimit)) dens[dens>densLimit] <- densLimit
    n <- length(dens)
    densf <- data.frame(density=cut(fdens(dens), n, labels=FALSE))
    colnames(densf)[1]<-density
    df <- data.frame(df, densf)
  }

  df
}

#' Wrap PlotData result in ggplot object.
#'
#' This creates a ggplot2 object for plotting.
#'
#'
#' @param embed Embedding data
#' @param ... Extra arguments passed to [PlotData()]
#' @examples
#' library(EmbedSOM)
#' library(ggplot2)
#'
#' # simulate a simple dataset
#' e <- cbind(rnorm(10000),rnorm(10000))
#'
#' PlotGG(e, data=data.frame(Expr=runif(10000))) +
#'   geom_point(aes_string(color="Expr"))
#' @export
PlotGG <- function(embed, ...) {
  ggplot2::ggplot(PlotData(embed, ...)) +
    ggplot2::aes_string('EmbedSOM1', 'EmbedSOM2')
}

#' The ggplot2 scale gradient from ExpressionPalette.
#'
#' @param ... Arguments passed to [ggplot2::scale_color_gradientn()]
#' @examples
#' library(EmbedSOM)
#' library(ggplot2)
#'
#' # simulate a simple dataset
#' e <- cbind(rnorm(10000),rnorm(10000))
#'
#' data <- data.frame(Val=log(1+e[,1]^2+e[,2]^2))
#' PlotGG(e, data=data) +
#'   geom_point(aes_string(color="Val"), alpha=.5) +
#'   ExpressionGradient(guide=FALSE)
#' @export
ExpressionGradient <- function(...) {
	ggplot2::scale_color_gradientn(colors=ExpressionPalette(256), ...)
}
