# . clv.controlflow.estimate.check.inputs ------------------------------------------------------------------------
setMethod(f = "clv.controlflow.estimate.check.inputs", signature = signature(clv.fitted="clv.fitted"), definition = function(clv.fitted,  start.params.model, use.cor, start.param.cor, optimx.args, verbose, ...){

  l.args <- list(...)

  # Check only basic structure
  err.msg <- c()
  if(!is.null(start.params.model)) # may be NULL = use model default
    err.msg <- c(err.msg, check_user_data_startparams(start.params = start.params.model,
                                                      vector.names = clv.fitted@clv.model@names.original.params.model,
                                                      param.names = "model start parameter"))


  # Check cor input
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=verbose, var.name ="verbose"))
  err.msg <- c(err.msg, .check_user_data_single_boolean(b=use.cor, var.name ="use.cor"))
  err.msg <- c(err.msg, check_user_data_startparamcorm(start.param.cor=start.param.cor, use.cor=use.cor))
  # Check additional optimx args
  err.msg <- c(err.msg, check_user_data_optimxargs(optimx.args=optimx.args))
  check_err_msg(err.msg)

  # warn that this model has no covariates but names/start.params/lambdas/cor/constr were given

  if(length(l.args) > 0){
    if("start.params.life" %in% names(l.args))
      if(length(l.args$start.params.life)>0)
        stop("The start parameters given for covariates are not needed because this is a no covariate model!", call. = FALSE)
    if("start.params.trans" %in% names(l.args))
      if(length(l.args$start.params.trans)>0)
        stop("The start parameters given for covariates are not needed because this is a no covariate model!", call. = FALSE)
    if("names.cov.life" %in% names(l.args))
      if(length(l.args$names.cov.life)>0)
        stop("The covariate names given are not needed because this is a no covariate model!", call. = FALSE)
    if("names.cov.trans" %in% names(l.args))
      if(length(l.args$names.cov.trans)>0)
        stop("The covariate names given are not needed because this is a no covariate model!", call. = FALSE)
    if("reg.lambdas" %in% names(l.args))
      if(length(l.args$reg.lambdas)>0)
        stop("The regularization lambdas are not needed because this is a no covariate model!", call. = FALSE)
    if("start.params.constr" %in% names(l.args))
      if(length(l.args$start.params.constr) > 0)
        stop("The given parameters to constrain and their start parameters are not needed because this is a no covariate model!", call. = FALSE)
    if("names.cov.constr" %in% names(l.args))
      if(length(l.args$names.cov.constr) > 0)
        stop("The given parameters to constrain and their start parameters are not needed because this is a no covariate model!", call. = FALSE)

    # Do not warn if anything else unneeded is passed - could be something for a model
  }
})

# . clv.controlflow.estimate.put.inputs ------------------------------------------------------------------------
setMethod("clv.controlflow.estimate.put.inputs", signature =  signature(clv.fitted="clv.fitted"), definition = function(clv.fitted, cl, use.cor, ...){

  clv.fitted@call <- cl

  # Should correlation be calculated? -----------------------------------------------------------------
  if(use.cor){
    # Using correlation
    clv.fitted@estimation.used.correlation <- TRUE
  }else{
    # No correlation
    clv.fitted@estimation.used.correlation <- FALSE
  }

  return(clv.fitted)
})


# . clv.controlflow.estimate.generate.start.params ------------------------------------------------------------------------
setMethod("clv.controlflow.estimate.generate.start.params", signature = signature(clv.fitted="clv.fitted"), definition = function(clv.fitted, start.params.model,start.param.cor,verbose,...){

  # Model params
  if(is.null(start.params.model))
    untransformed.start.params.model <- setNames(clv.fitted@clv.model@start.params.model, clv.fitted@clv.model@names.original.params.model)
  else
    untransformed.start.params.model <- start.params.model[clv.fitted@clv.model@names.original.params.model] # ensure order

  transformed.start.params.model <- clv.model.transform.start.params.model(clv.model = clv.fitted@clv.model,
                                                                           original.start.params.model = untransformed.start.params.model)
  names(transformed.start.params.model) <- clv.fitted@clv.model@names.prefixed.params.model


  start.params <- transformed.start.params.model

  # Correlation param m
  if(clv.fitted@estimation.used.correlation){

    # Transform correlation to param m
    #   do model-specific transformation with the generated and transformed model parameters
    if(is.null(start.param.cor)){
      # Use cor=0 if none given
      start.param.cor.param.m <- clv.model.cor.to.m(clv.model=clv.fitted@clv.model, prefixed.params.model=transformed.start.params.model,
                                                    param.cor = 0)
    }else{
      start.param.cor.param.m <- clv.model.cor.to.m(clv.model=clv.fitted@clv.model, prefixed.params.model=transformed.start.params.model,
                                                    param.cor = start.param.cor)
    }

    # Name and add to all start params
    names(start.param.cor.param.m) <- clv.fitted@name.prefixed.cor.param.m
    start.params <- c(start.params, start.param.cor.param.m)
  }

  return(start.params)
})


# . clv.controlflow.estimate.prepare.optimx.args ------------------------------------------------------------------------
# Put together the individual parts needed to call optimx
#   Adding the variables needed to call the LL function is left to the model-specific optimizeLL functions as they are unknonwn at this point
#' @importFrom utils modifyList
setMethod("clv.controlflow.estimate.prepare.optimx.args", signature = signature(clv.fitted="clv.fitted"), def=function(clv.fitted, start.params.all){

  # Start with model defaults
  optimx.args <- clv.fitted@clv.model@optimx.defaults

  # Everything to call optimx and the interlayer manager
  optimx.args <- modifyList(optimx.args, list(fn            = interlayer_manager,
                                              par           = start.params.all,
                                              hessian       = TRUE),
                            keep.null = TRUE)

  # Forbid to use any covariate specific interlayers ---------------------------------------------------
  #   For no covariates objects, only the correlation interlayer can be used. For covariates clv.fitted,
  #     this functions is overwritten to prepare more args
  #
  #   However, not passing these parameters, results in missing parameters for the interlayer manager
  #   This could be handled by default parameters or with missing there,
  #   but passing them with "False" is much cleaner


  optimx.args <- modifyList(optimx.args, list(use.interlayer.constr        = FALSE,
                                              names.original.params.constr = character(0),
                                              names.prefixed.params.constr = character(0),

                                              use.interlayer.reg           = FALSE,
                                              reg.lambda.trans             = numeric(0),
                                              reg.lambda.life              = numeric(0),
                                              names.prefixed.params.after.constr.life  = character(0),
                                              names.prefixed.params.after.constr.trans = character(0)),
                            keep.null = TRUE)


  # Everything to call the correlation layer
  optimx.args <- modifyList(optimx.args, list(use.cor                   = clv.fitted@estimation.used.correlation,
                                              name.prefixed.cor.param.m = clv.fitted@name.prefixed.cor.param.m,
                                              # By default, always check the bounds of param m
                                              check.param.m.bounds      = TRUE),
                            keep.null = TRUE)

  # Correlation interlayer ---------------------------------------------------------------------
  if(clv.fitted@estimation.used.correlation){
    # Use NM as default if correlation is estimated because the interlayer may return Inf
    #   if the params are out-of-bound
    optimx.args <- modifyList(optimx.args, list(method = "Nelder-Mead"))

    # Use a custom gradient function that signals the correlation layer to
    #   not check the boundaries of param m
    # Otherwise, the Hessian likely contains NAs because numDeriv often,
    #   also with small stepsizes, wanders accross the boundaries
    # Not checking the boundaries of param m is no issue for the gradient and hessian only,
    #   the bound checks are enforced for the param during regular optimization evaluations

    # Custom Gradient function
    # Use optixm::grad because also used in optimx::optimx.setup:
    #   "ugr <- function(par, userfn = ufn, ...) { tryg <- grad(userfn, par, ...)}"
    fct.no.check.grad <- function(x, fn.to.call.from.gr, ...){
      # ... contains all the other arguments given to interlayer(s) and LL function
      # fn.to.call.from.gr is what optimx(fn) calls (ie the interlayer manager)
      all.other.args <- list(...)
      all.other.args <- modifyList(all.other.args,
                                   # dont check boundaries during gradient
                                   alist(check.param.m.bounds = FALSE))
      do.call(what=grnd, c(alist(par = x,
                                 userfn = fn.to.call.from.gr),
                           all.other.args))
    }

    # For the gradient, call the wrapper around optmix::grnd
    optimx.args <- modifyList(optimx.args,
                              list(gr= fct.no.check.grad,
                                   # function to call when doing numerical grad. Do whatever is done for optimx
                                   fn.to.call.from.gr = optimx.args$fn))
  }


  return(optimx.args)
})


# . clv.controlflow.estimate.process.post.estimation ------------------------------------------------------------------------
#' @importFrom optimx coef<-
#' @importFrom utils tail
setMethod(f = "clv.controlflow.estimate.process.post.estimation", signature = signature(clv.fitted="clv.fitted"), definition = function(clv.fitted, res.optimx){

  clv.fitted@optimx.estimation.output <- res.optimx

  optimx.last.row <- tail(clv.fitted@optimx.estimation.output, n=1)

  if(anyNA(coef(optimx.last.row)))
    warning("Estimation failed with NA coefs. The returened object contains results but further usage is restricted.",
            immediate. = TRUE, call. = FALSE)

  # extract hessian from "details" attribute which is a list (if more then 1 method given)
  #   name it the same as the coefs for reading out later on
  clv.fitted@optimx.hessian           <- as.matrix(tail(attr(optimx.last.row, "details")[, "nhatend"], n=1)[[1]])

  if(length(clv.fitted@optimx.hessian)==1 & all(is.na(clv.fitted@optimx.hessian))){
    clv.fitted@optimx.hessian <- matrix(data = NA_real_, nrow = ncol(coef(optimx.last.row)),
                                 ncol = ncol(coef(optimx.last.row)))
    warning("Hessian could not be derived. Setting all entries to NA.",
            call. = FALSE, immediate. = TRUE)
  }

  colnames(clv.fitted@optimx.hessian) <- rownames(clv.fitted@optimx.hessian) <- colnames(tail(coef(res.optimx), n=1))

  return(clv.fitted)
})
