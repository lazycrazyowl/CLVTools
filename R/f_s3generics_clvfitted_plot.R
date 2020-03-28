#' @name plot.clv.fitted
#' @title Plot expected and actual repeat transactions
#' @param x The fitted clv model to plot
#' @param newdata A cldata object for which the plotting should be made with the fitted model. If none or NULL is given, the plot is made for the data on which the model was fit.
#' @param transactions Whether the actual observed repeat transactions should be plotted.
#' @param cumulative Whether the cumulative expected (and actual) transactions should be plotted.
#' @param plot Whether a plot should be created or only the assembled data is returned.
#' @param label Character string to label the model in the legend
#' @template template_param_predictionend
#' @template template_param_verbose
#' @template template_param_dots
#'
#' @description
#' Plot the actual repeat transactions and overlay it with the repeat transaction as predicted by the fitted model.
#'
#'
#' @details
#'
#' \code{prediction.end} is either a point in time (of class \code{Date}, \code{POSIXct}, or \code{character}) or the number of periods
#' that indicates until when to plot the expected transactions.
#' If \code{prediction.end} is of class character, the date/time format set when creating the data object is used for parsing.
#' If \code{prediction.end} is the number of periods, the end of the fitting period serves as the reference point from which periods are counted. Only full periods may be specified.
#' If \code{prediction.end} is omitted or NULL, it defaults to the end of the holdout period.
#'
#' Note that only whole periods can be plotted and that the prediction end might not exactly match \code{prediction.end}.
#' See the Note section for more details.
#'
#'
#' The \code{newdata} argument has to be a clv data object of the exact same class as the data object
#' on which the model was fit. In case the model was fit with covariates, \code{newdata} needs to contain identically
#' named covariate data.
#' The use case for \code{newdata} is mainly two-fold: First, to estimate model parameters only on a
#' sample of the data and then use the fitted model object to plot for the full data set provided through \code{newdata}.
#' Second, for models with dynamic covariates, to provide a clv data object with longer covariates than contained in the data
#' on which the model was estimated what allows to plot further. When providing \code{newdata}, some models
#' might require additional steps that can significantly increase runtime.
#'
#'
#' @note
#'
#' Because the expectation value is an incremental value derived from the cumulative expectation function,
#' all timepoints for which the expectation is calcuated need to be spaced exactly 1 time unit apart.
#' Each \code{period.first} marks the beginning of a time unit (ie 1st of January in case of yearly
#' time units) and the expectation values are calculated up until and including \code{period.first}.
#' If \code{prediction.end} does not coincide with the start of a time unit, the last timepoint
#' for which the expectation is calculated therefore is not \code{prediction.end} but the start of the
#' first time unit after \code{prediction.end}.
#'
#' @return
#' An object of class \code{ggplot} from package \code{ggplot2} is returned by default.
#' If the parameter \code{plot} is \code{FALSE}, the data that would have been melted and used to
#' create the plot is returned. It is a \code{data.table} which contains the following columns:
#' \item{period.first}{To which timepoint the data in this row refers.}
#' \item{Number of Repeat Transactions}{The number of actual repeat transactions in
#' the period that starts at \code{period.first}. Only if \code{transactions} is \code{TRUE}.}
#' \item{"Name of Model" or "label"}{The value of the unconditional expectation until \code{period.first} as per the given model.}
#'
#' @examples
#' \dontrun{
#' data("cdnow")
#'
#' # Fit ParetoNBD model on the CDnow data
#' pnbd.cdnow <- pnbd(clvdata(cdnow, time.unit="w",
#'                            estimation.split=37,
#'                            date.format="ymd"))
#'
#' # Plot actual repeat transaction, overlayed with the
#' #  expected repeat transactions as by the fitted model
#' plot(pnbd.cdnow)
#'
#' # Plot cumulative expected transactions of only the model
#' plot(pnbd.cdnow, cumulative=T, transactions=F)
#'
#' # Plot forecast until 2001-10-21
#' plot(pnbd.cdnow, prediction.end = "2001-10-21")
#'
#' # Plot until 2001-10-21, as date
#' plot(pnbd.cdnow,
#'      prediction.end = lubridate::dym("21-2001-10"))
#'
#' # Plot 15 time units after end of estimation period
#' plot(pnbd.cdnow, prediction.end = 15)
#'
#' # Save the data generated for plotting
#' #   (period, actual transactions, expected transactions)
#' plot.out <- plot(pnbd.cdnow, prediction.end = 15)
#'
#' # A ggplot object is returned that can be further tweaked
#' library("ggplot2")
#' gg.pnbd.cdnow <- plot(pnbd.cdnow)
#' gg.pnbd.cdnow + ggtitle("PNBD on CDnow")
#'
#' # Compose plot from separate model plots
#' # no cov model
#' p.m1 <- plot(pnbd.cdnow, transactions = T)
#' # static cov model
#' p.m2 <- plot(pnbd.cdnow.cov, transactions = F)
#' p.m1 + geom_line(mapping=p.m2$mapping, data=p.m2$data,
#'                  color="blue")
#' }
#' @importFrom graphics plot
#' @include class_clv_fitted.R
#' @method plot clv.fitted
#' @export
plot.clv.fitted <- function (x, prediction.end=NULL, newdata=NULL, cumulative=FALSE, transactions=TRUE, label=NULL, plot=TRUE, verbose=TRUE,...) {

  period.first <- period.num <- NULL

  # Newdata ------------------------------------------------------------------------------------------------
  # Because many of the following steps refer to the data stored in the fitted model,
  #   it first is replaced with newdata before any other steps are done
  if(!is.null(newdata)){
    # check newdata
    clv.controlflow.check.newdata(clv.fitted = x, user.newdata = newdata, prediction.end=prediction.end)

    # Replace data in model with newdata
    #   Deep copy to not change user input
    x@clv.data <- copy(newdata)

    # Do model dependent steps of adding newdata
    x <- clv.model.put.newdata(clv.model = x@clv.model, clv.fitted=x, verbose=verbose)
  }


  # Check inputs ------------------------------------------------------------------------------------------------------
  err.msg <- c()
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=cumulative, var.name="cumulative"))
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=plot, var.name="plot"))
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=verbose, var.name="verbose"))
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=transactions, var.name="transactions"))
  err.msg <- c(err.msg, check_user_data_predictionend(obj=x, prediction.end=prediction.end))
  if(!is.null(label)) # null is allowed = std. model name
    err.msg <- c(err.msg, .check_userinput_single_character(char=label, var.name="label"))
  check_err_msg(err.msg)

  if(length(list(...))>0){
    warning("Any parameters passed in ... are ignored because they are not needed.",
            call. = FALSE, immediate. = TRUE)
  }

  # do fitted object specific checks (ie dyncov checks cov data length)
  clv.controlflow.plot.check.inputs(obj=x, prediction.end=prediction.end, cumulative=cumulative,
                                    plot=plot, label.line=label, verbose=verbose)


  # Define time period to plot -----------------------------------------------------------------------------------------
  # Use table with exactly defined periods as reference and to save all generated data
  # End date:
  #   Use same prediction.end date for clv.data (actual transactions) and clv.fitted (unconditional expectation)
  #     If there are not enough transactions for all dates, they are set to NA (= not plotted)

  dt.dates.expectation <- clv.time.expectation.periods(clv.time = x@clv.data@clv.time, user.tp.end = prediction.end)

  tp.data.start <- dt.dates.expectation[, min(period.first)]
  tp.data.end   <- dt.dates.expectation[, max(period.first)]

  if(verbose)
    message("Plotting from ", tp.data.start, " until ", tp.data.end, ".")


  if(x@clv.data@has.holdout){
    if(tp.data.end < x@clv.data@clv.time@timepoint.holdout.end){
      warning("Not plotting full holdout period.", call. = FALSE, immediate. = TRUE)
    }
  }else{
    if(tp.data.end < x@clv.data@clv.time@timepoint.estimation.end){
      warning("Not plotting full estimation period.", call. = FALSE, immediate. = TRUE)
    }
  }


  # Get expectation values -----------------------------------------------------------------------------------------
  dt.expectation <- clv.controlflow.plot.get.data(obj=x, dt.expectation.seq=dt.dates.expectation,
                                                  cumulative=cumulative, verbose=verbose)
  if(length(label)==0)
    label.model.expectation <- x@clv.model@name.model
  else
    label.model.expectation <- label

  setnames(dt.expectation,old = "expectation", new = label.model.expectation)

  # Get repeat transactions ----------------------------------------------------------------------------------------
  if(transactions){
    label.transactions <- "Actual Number of Repeat Transactions"
    dt.repeat.trans <- clv.controlflow.plot.get.data(obj=x@clv.data, dt.expectation.seq=dt.dates.expectation,
                                                     cumulative=cumulative, verbose=verbose)
    setnames(dt.repeat.trans, old = "num.repeat.trans", new = label.transactions)
  }

  # Plot data, if needed --------------------------------------------------------------------------------------------
  # Merge data for plotting
  #   To be sure to have all dates, merge data on original dates

  dt.dates.expectation[, period.num := NULL]

  if(transactions){
    dt.dates.expectation[dt.expectation, (label.model.expectation) := get(label.model.expectation), on="period.first"]
    dt.dates.expectation[dt.repeat.trans, (label.transactions) := get(label.transactions), on="period.first"]
    dt.plot <- dt.dates.expectation
  }else{
    dt.dates.expectation[dt.expectation, (label.model.expectation) := get(label.model.expectation), on="period.first"]
    dt.plot <- dt.dates.expectation
  }

  # data.table does not print when returned because it is returned directly after last [:=]
  # " if a := is used inside a function with no DT[] before the end of the function, then the next
  #   time DT or print(DT) is typed at the prompt, nothing will be printed. A repeated DT or print(DT)
  #   will print. To avoid this: include a DT[] after the last := in your function."
  dt.plot[]

  # Only plot if needed
  if(!plot)
    return(dt.plot)

  if(transactions)
    line.colors <- setNames(object = c("black", "red"),
                            nm = c(label.transactions, label.model.expectation))
  else
    line.colors <- setNames(object = "red", nm = label.model.expectation)

  # Plot table with formatting, label etc
  return(clv.controlflow.plot.make.plot(dt.data = dt.plot, clv.data = x@clv.data, line.colors = line.colors))
}

#' @importFrom ggplot2 ggplot aes geom_line geom_vline labs theme scale_fill_manual guide_legend element_text element_rect element_blank element_line rel
clv.controlflow.plot.make.plot <- function(dt.data, clv.data, line.colors){
  # cran silence
  period.first <- value <- variable <- NULL

  # Melt everything except what comes from the standard expectation table
  meas.vars   <- setdiff(colnames(dt.data), c("period.num", "period.first"))
  data.melted <- data.table::melt(data=dt.data, id.vars = c("period.first"),
                                  variable.factor = FALSE, na.rm = TRUE,
                                  measure.vars = meas.vars)

  p <- ggplot(data = data.melted, aes(x=period.first, y=value, colour=variable)) + geom_line()

  # Add holdout line if there is a holdout period
  if(clv.data@has.holdout){
    p <- p + geom_vline(xintercept = as.numeric(clv.data@clv.time@timepoint.holdout.start),
                        linetype="dashed", show.legend = FALSE)
  }

  # Variable color and name
  p <- p + scale_fill_manual(values = line.colors,
                             aesthetics = c("color", "fill"),
                             guide = guide_legend(title="Legend"))

  # Axis and title
  p <- p + labs(x = "Date", y= "Number of Repeat Transactions", title= paste0(clv.time.tu.to.ly(clv.time=clv.data@clv.time), " tracking plot"),
                subtitle = paste0("Estimation end: ",  clv.data@clv.time@timepoint.estimation.end))

  p <- p + theme(
    plot.title = element_text(face = "bold", size = rel(1.5)),
    text = element_text(),
    panel.background = element_blank(),
    panel.border = element_blank(),
    plot.background  = element_rect(colour = NA),
    axis.title   = element_text(face = "bold",size = rel(1)),
    axis.title.y = element_text(angle=90,vjust =2),
    axis.title.x = element_text(vjust = -0.2),
    axis.text = element_text(),
    axis.line = element_line(colour="black"),
    axis.ticks = element_line(),
    panel.grid.major = element_line(colour="#d2d2d2"),
    panel.grid.minor = element_blank(),
    legend.key = element_blank(),
    legend.position = "bottom",
    legend.direction = "horizontal",
    legend.title = element_text(face="italic"),
    strip.background=element_rect(colour="#d2d2d2",fill="#d2d2d2"),
    strip.text = element_text(face="bold", size = rel(0.8)))

  return(p)
}

# . clv.controlflow.plot.get.data ---------------------------------------------------------------
setMethod(f="clv.controlflow.plot.get.data", signature = signature(obj="clv.fitted"), definition = function(obj, dt.expectation.seq, cumulative, verbose){

  expectation <- i.expectation <- NULL

  # Set prediction params from coef()
  obj <- clv.controlflow.predict.set.prediction.params(obj=obj)

  #   Pass copy of expectation table file becase will be modified and contain column named expecation
  dt.model.expectation <- clv.model.expectation(clv.model=obj@clv.model, clv.fitted=obj, dt.expectation.seq=copy(dt.expectation.seq),
                                                verbose = verbose)

  # include all from y to exend if predicting beyond actual transaction
  dt.model.expectation <- dt.model.expectation[, c("period.first", "expectation")] # Only the expectation data

  if(cumulative)
    dt.model.expectation[, expectation := cumsum(expectation)]

  # add expectation to plot data
  #   name columns by model
  dt.expectation.seq[dt.model.expectation, expectation := i.expectation,on = "period.first"]
  return(dt.expectation.seq)
})


#' @include class_clv_fitted.R
#' @exportMethod plot
#' @rdname plot.clv.fitted
setMethod("plot", signature(x="clv.fitted"), definition = plot.clv.fitted)