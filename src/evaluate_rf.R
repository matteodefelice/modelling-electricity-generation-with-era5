evaluate_rf <- function(tbl, K = 3, nt = 50, mnodes = 15, mtry = 8, 
                        assess_importance = TRUE) {
  library(randomForest)
  
  mdape <- function(y, target) {
    return(median(abs((y - target)/target) ))
  }
  out = list()
  # SINGLE
  m = randomForest(y ~ ., data = tbl, 
                   ntree = nt, 
                   maxnodes = mnodes, 
                   mtry = mtry, importance = assess_importance)
  
  single_cor   = cor(m$predicted, m$y)
  single_mdape = mdape(y = m$predicted, target = m$y)
  single_mae = mean(abs(m$predicted - m$y))
  
  out[['single']] = list(
    cor = single_cor, 
    mdape = single_mdape,
    mae = single_mae,
    mse = m$mse,
    out = m$predicted,
    single_model = m
  )
  out[['target']] = m$y
  # CROSSVALIDATION
  if (K > 1) {
    
    NROW = nrow(tbl)
    indices = parallel::splitIndices(NROW, K)
    
    cv_out = list()
    pb = txtProgressBar(max = K, style = 3)
    for (k in seq(1, K)) {
      setTxtProgressBar(pb, k)
      tr_id = seq(1, NROW)[-indices[[k]]]
      te_id = indices[[k]]
      
      m = randomForest(y ~ ., data = tbl[tr_id, ], 
                       ntree = nt, 
                       maxnodes = mnodes, 
                       mtry = mtry)
      
      oob_cor   = cor(m$predicted, m$y)
      oob_mdape = mdape(y = m$predicted, target = m$y)
      oob_mae = mean(abs(m$predicted - m$y))
      yhat = predict(m, newdata = tbl[te_id, ])
      cv_cor = cor(yhat, tbl$y[te_id])
      cv_mdape = mdape(y = yhat, target = tbl$y[te_id])
      cv_mae = mean(abs(yhat - tbl$y[te_id]))
      # Save CV results
      cv_out[[k]] = list(
        oob_cor = oob_cor, 
        oob_mdape = oob_mdape,
        oob_mae = oob_mae,
        cv_cor = cv_cor, 
        cv_mdape = cv_mdape,
        cv_mae = cv_mae,
        mse = m$mse,
        yhat = yhat, 
        target_cv = tbl$y[te_id])
    }
    close(pb)
    out[['cv']] = cv_out
  }
  
  return(out)
}