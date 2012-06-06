## $Id$ 

## This package to compute probabilities related to the following models: HEAP, 
## single division,bisection, and METE. These probabilities primarily are 
## related to the spatial abundance distribution, but not exclusively.

library(hash)

load_heap = function(...){
  if(!is.loaded("heap_prob")){
    OS = Sys.info()['sysname']
    if (OS == 'Linux')
      dyn.load('heap.so')
    else
      dyn.load('heap.dll')
  }
}

binomial_prob = function(n, A, n0, A0){
  ## replaced the function 'piBin'
  p = A/A0
  out = choose(n0,n) * p^n * (1 - p)^(n0 - n)
  return(out)
}

neg_bin_prob = function(n, A, n0, A0, k=1){
  ## Harte book Eq. 4.16 pg. 95
  nbar = n0 * A / A0
  out = (factorial(n + k - 1) / (factorial(n) * factorial(k - 1))) * 
        (nbar / (k + nbar))^n * (k / (k + nbar))^k
  return(out)
}

calc_g = function(n0, area_ratio){
  ## Harte book Eq. 4.10 pg. 93
  ## returns the number of ways n0 indistinguishable individuals can be 
  ## arranged into Mo cells
  ## The algebraic form of the function is: 
  ## factorial(Mo0 + n0 - 1) / (factorial(n0) * factorial(Mo - 1))
  ## But the following function makes numerical shortcuts so that fewer
  ## terms must be multiplied together
  num = 1
  den = 1
  term_diff = n0 - area_ratio
  n_drop = ifelse(term_diff >= 0, term_diff + 1, 0)
  if (n_drop > 0) {
    for(i in 1:(n0 - n_drop)) {
      num = num * (n0 + area_ratio - i)
    }  
    den = factorial(n0 - n_drop)
  }
  else {
    i = 0 
    while (i < n0) {
      num = num * (n0 + area_ratio - 1 - i)
      i = i + 1
    }
    den = factorial(n0)
  }
  return(num / den)
}

laplace_prob = function(n, A, n0, A0){
  ## Generalized Laplace
  ## Harte book Eq. 4.11 pg. 93
  ## returns the probability that n individuals are located in a randomly
  ## chosen cell that is Mo times smaller than the area it is embedded within.
  ## n0 is the total number of individuals in the larger area.
  area_ratio = A0 / A
  return(sapply(n,function(x) calc_g(n0 - x, area_ratio - 1) / calc_g(n0, area_ratio)))
}

calc_F = function(a, n){
  ## Conlisk et al. (2007)
  ## Eq. 7
  ## this is a computationaly efficient way to compute 
  ## gamma(a + n) / (gamma(a) * gamma(n + 1))
  if (n == 0)
    out = 1
  else
    out = prod(sapply(1:n, function(i) (a + i - 1) /  i ))
  return(out)
}  

single_prob = function(n, A, n0, A0, psi, c=2){
  ## Univaritate pdf of the Single division model
  ## Conlisk et al. (2007)
  ## Theorem 1.3
  if (psi <= 0 | psi >= 1) {
    out = 0
  }
  else {
    a = (1 - psi) / psi
    out = (calc_F(a, n) * calc_F((c - 1) * a, n0 - n)) / calc_F(c * a, n0) 
  }  
  return(out)
}

single_cdf = function(A, n0, A0, psi, use_c=TRUE){
  ## Univaritate cdf of the Single division model
  ## Conlisk et al. (2007)
  if (round(A) != A | round(A0) != A0) 
    stop('A and A0 must be integers')
  if (psi <= 0 | psi >= 1) {  
    out = rep(0, n0+1)
  }
  else {
    if (use_c) {
      load_heap()
      out = .C("single_cdf", A=as.integer(A), n0=as.integer(n0), A0=as.integer(A0),
               psi=as.double(psi), cdf=as.double(rep(0, n0 + 1)))$cdf
    }
    else {
      out = rep(0, n0+1)
      for (n in 0:n0) {
        if (n == 0)
           out[n+1] = single_prob(n, A, n0, A0, psi)
        else
          out[n+1] = out[n] + single_prob(n, A ,n0, A0, psi)
      }
    }  
  }  
  return(out)
}

single_rvs = function(n0, psi, size=1){
  ## Random number generator for the Single division model
  ## Conlisk et al. 2007
  ## uses Inverse transform sampling method to generate random variates
  ## http://en.wikipedia.org/wiki/Inverse_transform_sampling
  ## The basic idea is to uniformly sample a number u between 0 and 1, 
  ## interpreted as a probability, and then return the largest number x 
  ## from the domain of the distribution
  rands = runif(size)
  cdf = single_cdf(1,n0,2,psi)
  xvals = sapply(rands, function(u) which(order(c(cdf,u)) == (n0 + 2)) - 1)
  return(xvals)
}

bisect_prob = function(n, A, n0, A0, psi, h=hash(), use_c=FALSE){
  ## Univaritate pdf of the Bisection model
  ## Conlisk et al. (2007)
  ## Theorem 2.3
  ## psi is an aggregation parameter {0,1}
  ## Note that when psi = 0.5 that the Bisection Model = HEAP Model
  ## Source code for method use_c = TRUE is in the file heap.c
  if (round(A) != A | round(A0) != A0)
    stop('A and A0 must be integers')
  if (psi <= 0 | psi >= 1) {  
    out = 0
  }
  else {
    if (use_c) {
      load_heap()
      out = sapply(n,function(x)
            .C("bisect_prob", n=as.integer(x), A=as.integer(A), n0=as.integer(n0),
               A0=as.integer(A0), psi=as.double(psi), prob=as.double(0))$prob)
    }
    else {
      i = log2(A0 / A)
      key = paste(n, n0, i, sep=',')
      if (!(has.key(key, h))) {
        if (i == 1)
          h[key] = single_prob(n, A, n0, A0, psi)
        else {
          A = A * 2
          h[key] = sum(sapply(n:n0, function(q) 
                       bisect_prob(q, A, n0, A0, psi, h) * 
                       single_prob(n, A, q, A0, psi)))
        }  
      }
      out = as.numeric(h[[key]])
    }
  }  
  return(out)
}

quad_prob = function(n, A, n0, A0, psi, h=hash(), use_c=FALSE){
  if (round(A) != A | round(A0) != A0)
    stop('A and A0 must be integers')
  if (psi <= 0 | psi >= 1) {  
    out = 0
  }
  else {
    if (use_c) {
      #load_heap()
      #out = sapply(n,function(x)
      #      .C("bisect_prob", n=as.integer(x), A=as.integer(A), n0=as.integer(n0),
      #         A0=as.integer(A0), psi=as.double(psi), prob=as.double(0))$prob)
    }
    else {
      i = log2(A0 / A)
      key = paste(n, n0, i, sep=',')
      if (!(has.key(key, h))) {
        if (i == 1)
          h[key] = single_prob(n, A, n0, A0, psi, c=4)
        else {
          A = A * 2
          h[key] = sum(sapply(n:n0, function(q) 
                       bisect_prob(q, A, n0, A0, psi, h) * 
                       single_prob(n, A, q, A0, psi)))
        }  
      }
      out = as.numeric(h[[key]])
    }
  }  
  return(out)
  
}

multi_prob = function(abu_matrix, psi, c=2 ){
  ## computes the multivariate probability of a landcape given the pattern in 
  ## which its abundance was aggregated at progressively larger scales.  
  ## Conslik et al. 2007
  ## Theorem 2.2
  ## agruments:
  ## abu_matrix: a two column matrix that contains the two abundances that were
  ##             the product of each bisection
  ## psi: the aggregation parameter.
  ## c: 
  if (psi <= 0 | psi >= 1) {  
    prob = 0
  }
  else {
    a = (1 - psi) / psi
    if (c == 2) {
      n1 = abu_matrix[,1]
      n2 = abu_matrix[,2]
      prob = 1
      for (i in length(n1)) {
        prob = prob * calc_F(a, n1[i]) * calc_F(a, n2[i]) / calc_F(2 * a, n1[i] + n2[i])
      }  
    }
    if (c == 4) {
      n1 = abu_matrix[ , 1]
      n2 = abu_matrix[ , 2]
      n3 = abu_matrix[ , 3]
      n4 = abu_matrix[ , 4]
      prob = 1
      for (i in length(n1)) {
        prob = prob * calc_F(a, n1[i]) * calc_F(a, n2[i]) * calc_F(a, n3[i]) * 
                      calc_F(a, n4[i]) / calc_F(4 * a, sum(abu_matrix[i, ]))
      }  
    }  
  }  
  return(prob)
}

heap_prob = function(n, A, n0, A0, h=hash(), use_c=FALSE){
  ## HEAP model 
  ## Harte book Eq. 4.16 pg. 93
  ## Source code for method use_c = TRUE is in the file heap.c
  if (use_c) {
    load_heap()
    out = sapply(n,function(x){
          .C("heap_prob", n=as.integer(x), A=as.integer(A), n0=as.integer(n0),
             A0=as.integer(A0), prob=as.double(0))$prob})
  }
  else {
    i = log2(A0 / A)
    key = paste(n, n0, i, sep=',')
    if (!(has.key(key, h))) { 
      if(i == 1)
        h[key] = 1 / (n0 + 1)
      else {
        A = A*2 
        h[key] = sum(sapply(n:n0, function(q) heap_prob(q, A, n0, A0, h) / (q + 1)))
      }
    }  
    out = as.numeric(h[[key]])
  }  
  return(out)
}


calc_D = function(j, L=1){
  ## Distance calculation for a golden rectangle, L x L(2^.5)
  ## From Ostling et al. (2004) pg. 130
  ## j: seperation order
  ## L: width of rectangle of area A0  
  D = L / 2^((j:1) / 2)
  return(D)
}

calc_lambda = function(i, n0, ...){ 
  ## Scaling Biodiveristy Chp. Eq. 6.4, pg.106 
  ## i: number of bisections
  if (i == 0)
    lambda = 1
  if (i != 0){
    A0 = 2^i
    lambda = 1 - heap_prob(0, 1, n0, A0, ...)
  }
  return(lambda)
}

chi_heap = function(i, j, n0, chi_hash=hash(), ...){
  ## calculates the commonality function for a given degree of bisection (i) at 
  ## orders of seperation (j)
  ## Scaling Biodiveristy Chp. Eq. 6.10, pg.113  
  ## i: number of bisections
  ## j: order of seperation
  ## ... : optional arguments to pass on to heap_prob()
  if(n0 == 1){
    out = 0
  }
  else {
    key = paste(i, j, n0, sep=',')
    if (!(has.key(key, chi_hash))) {
      if(j == 1){
        chi_hash[key] = (n0 + 1)^-1 *
                 sum(sapply(1:(n0-1), function(m) calc_lambda(i - 1, m, ...) * 
                                                  calc_lambda(i - 1, n0 - m, ...)))
      }  
      else {
        i = i - 1
        j = j - 1
        chi_hash[key] = (n0 + 1)^-1 * sum(sapply(2:n0, function(m)
                                                chi_heap(i, j, m, chi_hash, ...)))
      }
    }
    out = as.numeric(chi_hash[[key]])
  }  
  return(out)
}

sor_heap = function(A, n0, A0, sor_use_c = FALSE, heap_use_c = FALSE, ...){
  ## Computes sorensen's index for a given spatial grain (A) at 
  ## all possible seperation distances 
  ## Scaling Biodiveristy Chp. Eq. 6.10, pg.113  
  ## source code in the file heap.c
  ## ... : optional arguments to pass on to chi_heap and heap_prob
  i = log2(A0 / A)
  d = calc_D(log2(A0 / A))
  chi = lambda = matrix(NA, nrow=length(n0), ncol=length(d))
  for (s in seq_along(n0)) {
    if (sor_use_c){  
      load_heap()
      chi[s,] = sapply(1:i, function(j)
                .C("chi_heap", i=as.integer(i), j=as.integer(j),
                   n0=as.integer(n0[s]), prob=as.double(0))$prob)
    }                   
    else {
      chi[s,] = sapply(1:i, function(j) chi_heap(i, j, n0[s], use_c = heap_use_c, ...))
    }  
    lambda[s,] = sapply(1:i, function(j) calc_lambda(i, n0[s], use_c = heap_use_c, ...))
  }
  sor = apply(chi, 2, sum) / apply(lambda, 2, sum)
  out = data.frame(Dist = d, Sor = sor)
  return(out)
}

negll_uni_bisect_vector = function(psi){
  ## single species neg log likelihood function
  ## Global variable:
  ##   dat: vector of abundance for each quadrat
  ## Local variable:
  ##   psi: aggregation parameter to be estimated
  tab = table(dat)
  n = as.numeric(names(tab))
  n0 = sum(dat)
  if(n0 == 1){
    warning('It is not appropriate to attempt to estimate psi when n0 = 1,
    because all psi values are equally likely')
  }  
  A = 1
  A0 = length(dat)
  freq = as.numeric(tab)
  negll = -sum(sapply(1:length(n), function(k) freq[k] * 
                    log(bisect_prob(n[k], A, n0, A0, psi))))
  return(negll)
}

negll_uni_bisect_matrix = function(psi){
  ## Multiple species neg log likelihood function
  ## Global variable:
  ##   dat: site x species matrix of abundance
  ## Local variable:
  ##   psi: aggregation parameter to be estimated
  n0_all = colSums(dat)
  n0_tab = table(n0_all)
  n0_uni = as.numeric(names(n0_tab))
  n0_freq = as.numeric(n0_tab)
  negll = 0
  A = 1
  A0 = nrow(dat)
  for(i in seq_along(n0_uni)){
    n0 = n0_uni[i]
    sp = which(n0_all == n0)
    x = as.vector(dat[,sp])
    tab = table(x)
    n = as.numeric(names(tab))
    freq = as.numeric(tab)
    negll = negll - (n0_freq[i] * sum(sapply(1:length(n), function(k) freq[k] *
                                            log(bisect_prob(n[k], A, n0, A0, psi)))))
  }  
  return(negll)
}