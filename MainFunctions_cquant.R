
check <- function(x,tau=.5){
  x*(tau - (x<0))
}

#Simulate from HMM
#############

nLL <- function(eta_par, u, post.hmm, dd, df, which_cop) {
  # llk <- c()
  # n = length(post.hmm)
  t_df = df
  if(which_cop == "norm"){
    norm.cop = normalCopula(eta_par, dim = dd, dispstr = "un")
    llk = post.hmm * dCopula(u, norm.cop, log = T)} else{
      t.cop = tCopula(eta_par, dim = dd, dispstr = "un", df = t_df, df.fixed = T)
      llk = post.hmm * dCopula(u, t.cop, log = T)
    }
  # for (t in 1:n) {
  #   llk[t] = post.hmm[t]*loglikCopula(param = eta_par, u[t,], norm.cop,
  #                                     error = c("-Inf"))
  # }
  llk[is.na(llk)] = 0
  llk[is.infinite(llk)] = 0
  #getTheta(norm.cop)
  sum_llk = sum(llk)
  return(-sum_llk)
}

nLL_bis <- function(eta_par, u, post.hmm, dd, df, which_cop) {
  # llk <- c()
  # n = length(post.hmm)
  t_df = df
  if(which_cop == "norm"){
    norm.cop = normalCopula(eta_par, dim = dd, dispstr = "un")
    llk = post.hmm * dCopula(u, norm.cop, log = T)} else{
      t.cop = tCopula(eta_par, dim = dd, dispstr = "un", df = t_df, df.fixed = T)
      llk = post.hmm * dCopula(u, t.cop, log = T)
    }
  # for (t in 1:n) {
  #   llk[t] = post.hmm[t]*loglikCopula(param = eta_par, u[t,], norm.cop,
  #                                     error = c("-Inf"))
  # }
  nas_llk = sum(as.numeric(is.na(llk)))
  infs_llk = sum(as.numeric(is.infinite(llk)))
  #llk[is.na(llk)] = 0
  #llk[is.infinite(llk)] = 0
  #getTheta(norm.cop)
  sum_llk = sum(llk)
  values = list(nas = nas_llk, infs = infs_llk)
  return(values)
}

#############
# log-forward
l.forward = function(delta,gamma,m,f.dens){
  ns = nrow(f.dens)
  l.alpha = matrix(NA,ns,m)
  foo = delta*f.dens[1,]
  sumfoo = sum(foo)
  lscale = log(sumfoo)
  foo = foo/sumfoo
  l.alpha[1,] = log(foo)+lscale
  for(t in 2:ns)
  {
    foo = foo%*%gamma*f.dens[t,]
    sumfoo = sum(foo)
    lscale = lscale+log(sumfoo)
    foo = foo/sumfoo
    l.alpha[t,] = log(foo)+lscale
  }
  return(l.alpha)
}
#############
# log-backward
l.backward = function(delta,gamma,m,f.dens){
  ns = nrow(f.dens)
  l.beta = matrix(NA,ns,m)
  l.beta[ns,] = rep(0,m)
  foo = rep(1/m,m)
  lscale = log(m)
  for(t in (ns-1):1)
  {
    foo = gamma%*%(f.dens[t+1,]*foo)
    l.beta[t,] = log(foo)+lscale
    sumfoo = sum(foo)
    foo = foo/sumfoo
    lscale = lscale+log(sumfoo)
  }
  return(l.beta)
}
############################################ select simulation error distribution #######
#Generate data from multivariate normal
  expreg.hsmm.multi = function(ns, m, dd, delta, gamma,beta, Sigma, tau, d){
  # ns = sample size
  # dd = multivariate variable dimension
  # m = scalar number of states, 
  # Sigma = covariance matrix for errors
  # delta = vector of initial values for prior probabilities, (pi vector)
  # gamma = matrix of initial values for state transition probabilies. (Pi matrix)
  # mu = list of initial values for means, 
  # d = list of state duration probabilities.
  ld = sapply(d,length)
  mvect = 1:m
  state = numeric(ns)
  x = error = matrix(0, ns, dd)
  nreg = nrow(beta[[1]])
  state[1] = sample(mvect, 1, prob=delta)
  
  dur = sample(1:ld[state[1]],1,prob=d[[state[1]]])
  mu = replicate(m, array(NA, dim = c(ns,nreg,dd)), simplify = F)
  regressor = matrix(rep(rnorm(ns*(nreg-1))), ncol = (nreg-1))
  regressor = cbind(rep(1,ns), regressor) 
  
  for (j in 1:m) {
    mu[[j]] = regressor%*%beta[[j]]
  }
  
  for(t in 1:dur){
    state[t] = state[1]
    error[t,] = MASS::mvrnorm(1, mu = rep(0, dd), Sigma = Sigma[[state[t]]])
    x[t,] = mu[[state[t]]][t,] + error[t,]
  }
  
  total = dur
  
  while(total<ns){
    
    state[total+1] = sample(mvect,1,prob=gamma[state[total],])
    dur = sample(1:ld[state[total+1]],1,prob=d[[state[total+1]]])
    for(t in 1:dur){
      if(total+t>ns) break
      state[total+t] = state[total+1]
      error[total+t,] = MASS::mvrnorm(1, mu = rep(0, dd), Sigma = Sigma[[state[total+t]]])
      x[total+t,] = mu[[state[total+t]]][total+t,] + error[total+t,]
    }
    total = total + dur
  }
  
  return(list(series=x,state=state,regressor=regressor,error=error))
}


#Generate data from multivariate t Student and skew-t
expreg.hsmm.multi.skewt = function(ns, m, dd, delta, gamma,beta, Sigma, tau,df,gamma_skewt, d){
  # ns = sample size
  # dd = multivariate variable dimension
  # m = scalar number of states, 
  # Sigma = covariance matrix for errors
  # delta = vector of initial values for prior probabilities, (pi vector)
  # gamma = matrix of initial values for state transition probabilies. (Pi matrix)
  # mu = list of initial values for means, 
  # df = list of t degrees of freedom for each state,
  # gamma_skewt = list of t skewness parameter for each state,
  # d = list of state duration probabilities.
  gamma_skewt = unlist(gamma_skewt)
  
  ld = sapply(d,length)
  mvect = 1:m
  state = numeric(ns)
  x = error = matrix(0, ns, dd)
  nreg = nrow(beta[[1]])
  state[1] = sample(mvect, 1, prob=delta)
  
  dur = sample(1:ld[state[1]],1,prob=d[[state[1]]])
  mu = replicate(m, array(NA, dim = c(ns,nreg,dd)), simplify = F)
  regressor = matrix(rep(rnorm(ns*(nreg-1))), ncol = (nreg-1))
  regressor = cbind(rep(1,ns), regressor) 
  
  for (j in 1:m) {
    mu[[j]] = regressor%*%beta[[j]]
  }
  
  for(t in 1:dur){
    state[t] = state[1]
    error[t,] = rmst(1, xi = rep(0, dd), Omega = Sigma[[state[t]]], nu = df[[state[t]]], alpha = gamma_skewt)
    x[t,] = mu[[state[t]]][t,] + error[t,]
  }
  
  total = dur
  
  while(total<ns){
    
    state[total+1] = sample(mvect,1,prob=gamma[state[total],])
    dur = sample(1:ld[state[total+1]],1,prob=d[[state[total+1]]])
    for(t in 1:dur){
      if(total+t>ns) break
      state[total+t] = state[total+1]
      error[total+t,] = rmst(1, xi = rep(0, dd), Omega = Sigma[[state[total+t]]], nu = df[[state[total+t]]], alpha = gamma_skewt)
      x[total+t,] = mu[[state[total+t]]][total+t,] + error[total+t,]
    }
    total = total + dur
  }
  
  return(list(series=x,state=state,regressor=regressor,error=error))
}


# Generate data from a gaussian or t copula with ALD marginals
hsmm.multi.real = function(reg, ns, m, dd, delta, gamma, beta, df, Sigma, sigma, tau, d, wcop, cpar){
  # ns = sample size
  # dd = multivariate variable dimension
  # m = scalar number of states, 
  # Sigma = covariance matrix for errors
  # delta = vector of initial values for prior probabilities, (pi vector)
  # gamma = matrix of initial values for state transition probabilies. (Pi matrix)
  # mu = list of initial values for means, 
  # d = list of state duration probabilities.
  ld = sapply(d,length)
  mvect = 1:m
  state = numeric(ns)
  x = error = matrix(0, ns, dd) #sono le y
  #lb = length(beta[[1]])
  #nreg = ncol(beta[[1]]) #qui c'è anche alpha
  nreg = nrow(beta[[1]])
  state[1] = sample(mvect, 1, prob=delta)
  
  dur = sample(1:ld[state[1]],1,prob=d[[state[1]]])
  mu = replicate(m, array(NA, dim = c(ns,nreg,dd)), simplify = F)
  
  for (j in 1:m) {
    mu[[j]] = reg%*%beta[[j]]
  }
  
  for(t in 1:dur){
    state[t] = state[1]
    if(wcop == "norm"){
      mn = mvrnorm(1, mu = rep(0, dd), Sigma = Sigma[[state[t]]])
      pn = pnorm(mn)
      error[t,] = sapply(1:dd, function(i) qALD(pn[i], mu = 0, sigma = sigma[[state[t]]][i], p = tau))
    }else{
      t.cop = tCopula(param = cpar[[state[t]]], dim = dd, dispstr = "un", df = df[[state[t]]])
      ut = rCopula(1, t.cop)
      error[t,] = sapply(1:dd, function(i) qALD(ut[i], mu = 0, sigma = sigma[[state[t]]][i], p = tau))
    }
    
    x[t,] = mu[[state[t]]][t,] + error[t,]
  }
  
  total = dur
  
  while(total<ns){
    
    state[total+1] = sample(mvect,1,prob=gamma[state[total],])
    dur = sample(1:ld[state[total+1]],1,prob=d[[state[total+1]]])
    for(t in 1:dur){
      if(total+t>ns) break
      state[total+t] = state[total+1]
      if(wcop == "norm"){
        mn = mvrnorm(1, mu = rep(0, dd), Sigma = Sigma[[state[total+t]]])
        pn = pnorm(mn)
        error[total+t,] = sapply(1:dd, function(i) qALD(pn[i], mu = 0, sigma = sigma[[state[total+t]]][i], p = tau))
      }else{
        t.cop = tCopula(param = cpar[[state[total+t]]], dim = dd, dispstr = "un", df = df[[state[total+t]]])
        ut = rCopula(1, t.cop)
        error[total+t,] = sapply(1:dd, function(i) qALD(ut[i], mu = 0, sigma = sigma[[state[total+t]]][i], p = tau))
      }
  
      x[total+t,] = mu[[state[total+t]]][total+t,] + error[total+t,]
    }
    total = total + dur
  }
  
  return(list(series=x,state=state,regressor=reg,error=error))
}


# Load necessary library
library(mvtnorm)

# # Function to calculate the density of a Gaussian copula
N_dcopula <- function(u, corr_matrix) {
  # Check if inputs are valid
  if (!is.matrix(u)) stop("'u' should be a matrix")
  if (!is.matrix(corr_matrix)) stop("'corr_matrix' should be a matrix")
  if (ncol(u) != ncol(corr_matrix)) stop("Number of columns in 'u' must match the dimension of 'corr_matrix'")
  if (any(u <= 0 | u >= 1)) stop("Values in 'u' must be in the interval (0, 1)")

  # Number of dimensions
  d <- ncol(u)

  # Convert uniform margins to normal margins using the inverse CDF (quantile function)
  z <- qnorm(u)

  # Calculate the density of the multivariate normal distribution
  density <- dmvnorm(z, mean = rep(0, d), sigma = corr_matrix) / prod(dnorm(z))

  return(density)
}


###########################################
##### EM for quantile HMM regression ####
###########################################
em.hmm.cqereg = function(y, X_, tau, m, dd, delta, gamma, beta, cpar, sigma, maxiter, df_cop, which_cop, tol, trace=F){
  # y = response variable
  # X = regressors
  # tau = quantile level
  # m = number of states
  # dd = dimension of the response variable
  # delta = initial values for prior probabilities
  # gamma = initial values for state transition probabilities
  # beta = initial values for regression coefficients
  # cpar = initial values for copula parameters
  # sigma = initial values for error standard deviations
  # maxiter = maximum number of iterations
  # df_cop = initial values for copula degrees of freedom
  # which_cop = copula type
  # tol = tolerance level
  # trace = print output
  
  X = X_
  n = dim(y)[1]
  C = dim(X)[2] #num intercetta + regressori
  
  if(is.list(delta)) delta = unlist(delta)
  #if(is.list(beta)) beta = matrix(unlist(beta),m,byrow = F)
  #if(is.list(sigma)) sigma = unlist(sigma)
  
  #print(delta);print(beta);print(gamma);print(sigma)
  startpars = list(delta = delta, beta = beta, gamma = gamma, sigma = sigma, cpar = cpar, df = df_cop)
  llk.pred = 0
  
  gamma.next = gamma
  beta.next = beta
  delta.next = delta
  sigma.next = sigma
  cpar.next = cpar
  df.next = df_cop
  
  for (iter in 1:maxiter){
    start_time = Sys.time()
    # print(paste("em iter=",iter))
    lallprobs_multi = pdf_c = marg_prod = matrix(NA, nrow = n,ncol = m)
    lallprobs = u = replicate(m, matrix(NA, nrow = n,ncol = dd), simplify = F)
    for (j in 1:m){
      for (t in 1:n){
        for (index.d in 1:dd) {
          lallprobs[[j]][t,index.d] = dALD(y[t,index.d], mu = X[t,]%*%beta[[j]][,index.d],sigma=sigma[[j]][index.d],p=tau)
          #marginal densities for each d
          u[[j]][t,index.d] = pALD(y[t,index.d], mu = X[t,]%*%beta[[j]][,index.d],sigma=sigma[[j]][index.d],p=tau)
        }
      }
    }  
    # Compute the copula density
    ##Copula ##
    norm.cop <- t.cop <- list()
    # Compute the copula density
    for (j in 1:m){
      u[[j]] = u[[j]] * (n - 1)/n + .Machine$double.eps/n  #rescale the u's
      # coef_ <- cpar[[j]]
      coef_ <- cpar[[j]][1:(dd*(dd-1)/2)]
      if(which_cop == "indip"){ pdf_c[,j] <- 1
      } else if(which_cop == "norm"){
        norm.cop[[j]] <- normalCopula(coef_, dim = dd, dispstr = "un")
        pdf_c[,j] <- dCopula(u[[j]], norm.cop[[j]])
      } else {
          df_ <- df_cop[[j]]
          t.cop[[j]] <- tCopula(coef_, dim = dd, dispstr = "un", df = df_)
          pdf_c[,j] <- dCopula(u[[j]], t.cop[[j]])
        }
      # Compute the multivariate density, multiplying the univariate densities and the copula density
      marg_prod[,j] <- apply(lallprobs[[j]], 1, prod)
    }
    lallprobs_multi <- marg_prod * pdf_c
    
    
    #Compute forward and backward probabilities of the Baum algorithm
    #forward probs
    la = matrix(NA , m ,n)
    pa = matrix(NA , n ,m)
    foo_s = foo_t = matrix(NA , n ,m)
    foo = delta * lallprobs_multi[1,]
    if(sum(is.na(foo))>0){foo[is.na(foo)] <- .Machine$double.xmin}
    if(sum(foo==0)>0 ){foo[foo==0] <- .Machine$double.xmin}
    sumfoo = sum(foo)
    lscale = (log(sumfoo))
    foo = foo / sumfoo
    pa[1,] = foo
    la[,1] = lscale + log(foo)
    foo_s[1,] <- foo
    for (t in 2:n){
      ##***
      #if(sum(as.integer(is.nan(foo)))>1){print(paste("foo NaN at t=",t)); print(paste("lallprobs_multi[t,]:",lallprobs_multi[t,])); foo[is.nan(foo)] <- 0}
      ##***
      foo_s[t,] <- foo
      foo = foo %*% gamma * lallprobs_multi[t,]
      if(sum(is.na(foo))>0){foo[is.na(foo)] <- .Machine$double.xmin}
      if(sum(foo==0)>0){foo[foo==0] <- .Machine$double.xmin}
      sumfoo = sum(foo)
      lscale = lscale + (log(sumfoo))
      
      
      ##***
      if(sum(as.integer(is.nan(log(sumfoo))))>1){print(paste("log sumfoo NaN at t=",t))}
      #***
      foo = foo / sumfoo
      pa[t,] = foo
      la[,t] = log(foo) + lscale
    }

    
    #backward probs
    lb = matrix(NA , m ,n)
    lscale_s <- c()
    foo = rep(1/m, m)
    foo_t[n,] <- foo
    lb[,n] = rep(0,m)
    lscale = log(m)
    lscale_s[1] <- lscale
    for (t in (n-1):1){ 
      foo_t[t,] <- foo
      foo = gamma %*% (lallprobs_multi[t+1,] * foo)
      if(sum(is.na(foo))>0){foo[is.na(foo)] <- .Machine$double.xmin}
      if(sum(foo==0)>0){foo[foo==0] <- .Machine$double.xmin}
      lb[,t] = log((foo)) + lscale
      sumfoo = sum(foo)
      foo = foo / sumfoo
      lscale = lscale + (log(sumfoo))
      if(is.infinite(lscale) || is.nan(lscale)){lscale <- lscale_s[t+1]}
      lscale_s[t] <- lscale
    }
    
    c   =  max(la[,n])                                      
    #c   =  max(abs(la[,n]))
    llk = c+log(sum(exp(la[,n]-c)))
    if(is.nan(llk)){
    # print(paste("llk=",llk))
    llk = c(.Machine$double.eps)}
    # print(paste("llk=",llk,";c=",c))
    post.hmm = matrix(NA , ncol = n, nrow = m)
    for (j in 1:m){                                           
      post.hmm[j,] = exp(la[j,]+lb[j,]-llk)
    }

    #Delta estimate
    delta.next = exp(la[,1]+lb[,1]-llk)
    delta.next = delta.next/sum(delta.next)
    
    #Gamma estimate
    gamma.next = matrix(NA,nrow = m, ncol = m)
    for (j in 1:m){
      for (k in 1:m){                                                      
        #****
        tmp = exp(la[j,1:(n-1)]+   
                    log(lallprobs_multi[2:n,k])+lb[k,2:n]-llk)
        tmp[tmp==Inf] <- 1
        tmp[tmp==-Inf] <- 0
        # gamma.next[j,k] = gamma[j,k]*sum(exp(la[j,1:(n-1)]+   
        #                                        log(lallprobs_multi[2:n,k])+lb[k,2:n]-llk)) 
        gamma.next[j,k] = gamma[j,k]*sum(tmp)  
      }   
    }                                                       
    gamma.next = gamma.next/apply(gamma.next,1,sum)
    
    
    #Beta and Sigma estimate
    aux = replicate(m, matrix(data = NA, n, dd), simplify = F)
    beta.next = replicate(m,matrix(data = NA, C, dd), simplify = F)
    sigma.next = replicate(m, matrix(NA,nrow = dd, ncol = 1), simplify = F)
    cpar.next = replicate(m, matrix(NA, nrow = 1,ncol = dd*(dd-1)/2), simplify = F)
    model = list()
    for (j in 1:m){
      if(sum(is.infinite(post.hmm)) >0){
        post.hmm[post.hmm==Inf]<-1
        post.hmm[post.hmm== -Inf]<-0
      }
      ### ****************
      for (index.d in 1:dd) {
        model[[index.d]] = rq(y[,index.d] ~ X - 1,weights = post.hmm[j,], tau=tau)
        beta.next[[j]][,index.d] = model[[index.d]]$coefficients
        aux[[j]][,index.d] = post.hmm[j,]*abs(tau-as.numeric(model[[index.d]]$residuals<=0))*model[[index.d]]$residuals^2
        sigma.next[[j]][index.d] = sum(post.hmm[j,]*check(as.numeric(model[[index.d]]$residuals), tau=tau))/sum(post.hmm[j,])
      }
      
    }   
    

    for (j in 1:m){   
      if(which_cop == "indip"){ df.next[[j]] <- 1; cpar.next[[j]] <- rep(0, (dd*(dd-1)/2))
      } else if(which_cop == "norm"){
        pseudon = sapply(1:dd, function(i) qnorm(p = u[[j]][,i], mean = 0, sd = 1))
        cpar.next[[j]] = P2p(cov2cor(t(pseudon)%*%diag(post.hmm[j,])%*%pseudon))
        df.next[[j]] <- 1
      } else {
        pseudot = sapply(1:dd, function(i) qt(p = u[[j]][,i], df = df_cop[[j]]))
        scale_t = p2P(cpar[[j]][1:(dd*(dd-1)/2)], dd)
        wt = sapply(1:n, function(i) (df_cop[[j]] + dd) / (df_cop[[j]] + pseudot[i,]%*%solve(scale_t)%*%pseudot[i,]))
        cpar.next[[j]] = P2p(cov2cor(t(pseudot)%*%diag(wt * post.hmm[j,])%*%pseudot))
        
        fit <- optim(df_cop[[j]], fn = nLL, u=u[[j]],post.hmm=post.hmm[j,], dd=dd, eta_par=cpar[[j]],
                     which_cop = which_cop, method = "L-BFGS-B", lower = 2.0001, upper = 1e3,
                     control = list(factr = 1e7, maxit = 5e3)) # 1e7 * 1e-15 = 1e-8 by default. Smaller -> stricter convergence
        df.next[[j]] <- fit$par
      }
    }
  
    
    crit_beta <- c()
    crit_sigma <- c()
    crit_cpar <- c()
    crit_df <- c()
    #Set Convergence Criterion
  
    for (j in 1:m) {
      crit_beta[j] <- sum(abs(beta[[j]]-beta.next[[j]]))
      crit_sigma[j] <- sum(abs(sigma[[j]]-sigma.next[[j]]))
      crit_cpar[j] <- sum(abs(cpar[[j]]-cpar.next[[j]]))
      crit_df[j] <- sum(abs(df_cop[[j]]-df.next[[j]]))
    }
    crit = sum(sum(abs(delta-delta.next)) + sum(abs(crit_beta)) + sum(abs(crit_cpar)) + sum(abs(gamma-gamma.next)) + sum(abs(crit_sigma))) # + sum(abs(llk-llk.pred))
    # dif_ = abs(llk)-abs(llk.pred)
    dif_ = llk - llk.pred
    if(trace) {cat("iteration ",iter,": loglik = ", llk, "\n") 
      cat("time of a single iteration: ",time_iter, "\n")}
    #  if(dif_ > 0 & iter != 1) cat("iteration ",iter," error: positive delta loglik = ", dif_ , "\n")}
    if(crit<tol){
      
      #Output
      return(list(m=m, dif=dif_, betas=beta, delta=delta, gamma=gamma, cpar = cpar, df=df_cop,
                  loglik=llk, iteration=iter, sigma=sigma, post = post.hmm, aux = aux, u = u, crit = crit1))
    }
    delta = delta.next
    beta = beta.next
    gamma = gamma.next
    sigma = sigma.next
    cpar = cpar.next
    df_cop = df.next
    llk.pred = llk
    #info.criteria
    if(which_cop == "indip"){
      n.par = dd * C * m + dd * m + m * (m - 1) + (m - 1) # in the indipendence copula we don't have parameters matrix
    } else if(which_cop == "norm"){
      n.par = dd * C * m + dd * m + m * (m - 1) + (m - 1) + m*(dd*(dd-1)/2)
    } else {
      n.par = dd * C * m + dd * m + m * (m - 1) + (m - 1) + m*(dd*(dd-1)/2) + m
    }
    aic.crit = -2*llk + 2*n.par
    bic.crit = -2*llk + log(n)*n.par
    icl.crit = bic.crit - 2 * sum(post.hmm * ifelse(post.hmm > 0, log(post.hmm), 0))
    crit1 = c(aic.crit, bic.crit, icl.crit)
    names(crit1) = c("AIC", "BIC", "ICL")
    end_time = Sys.time()
    time_iter = end_time - start_time
  }                                                        
  cat(paste("\nNo convergence after",maxiter,"iterations\n\n"))  
  
  #Output
  return(list(m=m, dif=dif_, betas=beta, delta=delta, gamma=gamma, cpar = cpar, df=df_cop,
              loglik=llk, iteration=iter, sigma=sigma, post = post.hmm, aux = aux, u = u, crit = crit1))
}





