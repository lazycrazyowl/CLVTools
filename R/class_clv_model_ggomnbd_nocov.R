#' @templateVar name_model_full GGompertz/NBD
#' @template template_class_clvmodelnocov
#'
#' @importFrom methods setClass
#' @seealso Other clv model classes \link{clv.model-class}, \link{clv.model.ggomnbd.static.cov-class}
#' @seealso Classes using its instance: \link{clv.fitted-class}
#' @include all_generics.R class_clv_model.R
setClass(Class = "clv.model.ggomnbd.no.cov", contains = "clv.model",
         # no additional slots required
         slots = list(),
         prototype = list(
           name.model                  = character(0),
           names.original.params.model = character(0),
           names.prefixed.params.model = character(0),
           start.params.model          = numeric(0),
           optimx.defaults = list()
         ))

clv.model.ggomnbd.no.cov <- function(){
  return(new("clv.model.ggomnbd.no.cov",
             name.model = "GGompertz/NBD Standard",
             names.original.params.model = c(r="r", alpha="alpha", b="b", s="s", beta="beta"),
             names.prefixed.params.model = c("log.r","log.alpha", "log.b", "log.s", "log.beta"),
             start.params.model          = c(r=1, alpha=1, b=1, s=1, beta=1),
             optimx.defaults = list(method = "L-BFGS-B",
                                    itnmax  = 5000,
                                    control = list(
                                      kkt = TRUE,
                                      all.methods = FALSE,
                                      save.failures = TRUE,
                                      # Do not perform starttests because it checks the scales with max(logpar)-min(logpar)
                                      #   but all standard start parameters are <= 0, hence there are no logpars what
                                      #   produces a warning
                                      starttests = FALSE))))
}

# Methods --------------------------------------------------------------------------------------------------------------------------------
#' @include all_generics.R
setMethod(f = "clv.model.check.input.args", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, start.params.model, use.cor, start.param.cor, optimx.args, verbose, ...){

  err.msg <- c()

  # Have to be > 0 as will be logged
  if(any(start.params.model <= 0)){
    err.msg <- c(err.msg, "Please provide only model start parameters greater than 0 as they will be log()-ed for the optimization!")
  }

  if(length(list(...)) > 0){
    err.msg <- c(err.msg, "Any further parameters passed in ... are ignored because they are not needed by this model.")
  }

  check_err_msg(err.msg)

})

setMethod(f = "clv.model.put.estimation.input", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, verbose, ...){
  # nothing to put specifically for this model
  return(clv.fitted)
})

#' @importFrom stats setNames
setMethod("clv.model.transform.start.params.model", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, original.start.params.model){
  # Log all user given or default start params
  return(setNames(log(original.start.params.model[clv.model@names.original.params.model]),
                  clv.model@names.prefixed.params.model))
})

setMethod("clv.model.backtransform.estimated.params.model", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, prefixed.params.model){
  # exp all prefixed params
  return(exp(prefixed.params.model[clv.model@names.prefixed.params.model]))
})

# . clv.model.process.post.estimation -----------------------------------------------------------------------------------------
setMethod("clv.model.process.post.estimation", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, res.optimx){
  # No additional step needed (ie store model specific stuff, extra process)
  return(clv.fitted)
})

setMethod(f = "clv.model.put.newdata", signature = signature(clv.model = "clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, verbose){
  # clv.data in clv.fitted is already replaced with newdata here
  # Need to only redo cbs if given new data
  clv.fitted@cbs <- ggomnbd_cbs(clv.data = clv.fitted@clv.data)
  return(clv.fitted)
})

setMethod(f = "clv.model.prepare.optimx.args", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, prepared.optimx.args,...){
  # Also model optimization settings should go here

  # Only add LL function args, everything else is prepared already, incl. start parameters

  optimx.args <- modifyList(prepared.optimx.args,
                            list(LL.function.sum = ggomnbd_nocov_LL_sum,
                                 LL.function.ind = ggomnbd_nocov_LL_ind, # if doing correlation
                                 obj    = clv.fitted,
                                 vX     = clv.fitted@cbs$x,
                                 vT_x   = clv.fitted@cbs$t.x,
                                 vT_cal = clv.fitted@cbs$T.cal,

                                 # parameter ordering for the callLL interlayer
                                 LL.params.names.ordered = c(log.r = "log.r",log.alpha =  "log.alpha", log.b = "log.b", log.s = "log.s", log.beta = "log.beta")),
                            keep.null = TRUE)
  return(optimx.args)
})

#' @include all_generics.R
#' @importFrom stats integrate
setMethod("clv.model.expectation", signature(clv.model="clv.model.ggomnbd.no.cov"), function(clv.model, clv.fitted, dt.expectation.seq, verbose){
  r <- alpha <- beta <- b <- s <- t_i <- tau <- NULL

  params_i <- clv.fitted@cbs[, c("Id", "T.cal", "date.first.actual.trans")]

  fct.expectation <- function(params_i.t){
    return(drop(ggomnbd_nocov_expectation(r       = clv.fitted@prediction.params.model[["r"]],
                                          alpha_0 = clv.fitted@prediction.params.model[["alpha"]],
                                          beta_0  = clv.fitted@prediction.params.model[["beta"]],
                                          b       = clv.fitted@prediction.params.model[["b"]],
                                          s       = clv.fitted@prediction.params.model[["s"]],
                                          vT_i = params_i.t$t_i)))
  }

  return(DoExpectation(dt.expectation.seq = dt.expectation.seq, params_i = params_i,
                       fct.expectation = fct.expectation, clv.time = clv.fitted@clv.data@clv.time))
})

#' @include all_generics.R
setMethod("clv.model.predict.clv", signature(clv.model="clv.model.ggomnbd.no.cov"), function(clv.model, clv.fitted, dt.prediction, continuous.discount.factor, verbose){
  r <- alpha <- b <- s <- beta <- x <- t.x <- T.cal <- PAlive <- i.PAlive <- DERT <- i.DERT <- CET <- i.CET <- period.length <- NULL

  predict.number.of.periods <- dt.prediction[1, period.length]

  # To ensure sorting, do everything in a single table
  dt.result <- copy(clv.fitted@cbs[, c("Id", "x", "t.x", "T.cal")])

  # Add CET
  dt.result[, CET := ggomnbd_nocov_CET(r       = clv.fitted@prediction.params.model[["r"]],
                                       alpha_0 = clv.fitted@prediction.params.model[["alpha"]],
                                       b       = clv.fitted@prediction.params.model[["b"]],
                                       s       = clv.fitted@prediction.params.model[["s"]],
                                       beta_0  = clv.fitted@prediction.params.model[["beta"]],
                                       dPeriods = predict.number.of.periods,
                                       vX      = x,
                                       vT_x    = t.x,
                                       vT_cal  = T.cal)]

  # Add PAlive
  dt.result[, PAlive := ggomnbd_nocov_PAlive(r       = clv.fitted@prediction.params.model[["r"]],
                                             alpha_0 = clv.fitted@prediction.params.model[["alpha"]],
                                             b       = clv.fitted@prediction.params.model[["b"]],
                                             s       = clv.fitted@prediction.params.model[["s"]],
                                             beta_0  = clv.fitted@prediction.params.model[["beta"]],
                                             vX      = x,
                                             vT_x    = t.x,
                                             vT_cal  = T.cal)]
  # Add DERT
  dt.result[, DERT := 0]

  # Add results to prediction table, by matching Id
  dt.prediction[dt.result, CET    := i.CET,    on = "Id"]
  dt.prediction[dt.result, PAlive := i.PAlive, on = "Id"]
  dt.prediction[dt.result, DERT   := i.DERT,   on = "Id"]

  return(dt.prediction)
})

# .clv.model.vcov.jacobi.diag --------------------------------------------------------------------------------------------------------

setMethod(f = "clv.model.vcov.jacobi.diag", signature = signature(clv.model="clv.model.ggomnbd.no.cov"), definition = function(clv.model, clv.fitted, prefixed.params){
  # Create matrix with the full required size
  m.diag <- diag(x = 0, ncol = length(prefixed.params), nrow=length(prefixed.params))
  rownames(m.diag) <- colnames(m.diag) <- names(prefixed.params)

  # Add the transformations for the model to the matrix
  #   All model params need to be exp()
  m.diag[clv.model@names.prefixed.params.model,
         clv.model@names.prefixed.params.model] <- diag(x = exp(prefixed.params[clv.model@names.prefixed.params.model]),
                                                        nrow = length(clv.model@names.prefixed.params.model),
                                                        ncol = length(clv.model@names.prefixed.params.model))
  return(m.diag)
})
