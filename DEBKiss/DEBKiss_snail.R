### Bayesian inference for a DEBKiss model
### Supplementary code for the manuscript Boersch-Supan and Johnson 2018: Two case studies detailing Bayesian parameter inference for dynamic energy budget models


### These provide the code from the package, the implemented model,
### and likelihood, respectively
library("deBInfer")
source("DEBKiss_model.R")
source("DEBKiss_llik.R")

## First read in the simplified dataset
dat<-read.csv("snail_1food_clean.csv", header=TRUE)


## these are the initial parameters based on the fits from the
## original paper. Note that because we're not beginning at egg laying
## that we set the initial embryo buffer to 0

y<-c(WB=0.000001, Lw=12.8, WR=0)
parms<-c(deltaM=0.401, f=1, fb=0.8, JAM=0.11, yAX=0.8,
         kappa=0.89, logJMv=log(0.008), yVA=0.8, yAV=0.8,
         dV=0.1, Wp=70, yBA=0.95, WB0=0.15)


## Plot the data together with the model output based on the
## parameters from the paper
times<-seq(0, 160, by=0.1)
out <- ode(y, times, DEBKiss1, parms, method="rk4")

par(mfrow=c(1,2),mai=c(.8,.8,.2,.1))# bty="n")
plot(out[,1], out[,3], type="l", ylab="observed length", xlab="time (days)", lwd=2, col=2, lty=1, pch=23, ylim=c(12, 31), xlim=c(0,148))
points(dat$time, dat$L, lwd=2)
plot(out[,1], out[,4]*parms["yBA"]/parms["WB0"], type="l", ylab="total eggs", xlab="time (days)", ylim=c(0, 1100), lwd=2, col=4, lty=1, xlim=c(0,148))
points(dat$time, dat$Egg, pch=25, lwd=2)


##### Below is code necessary to perform inference for this model

## setting up DEB parameters. We choose a subset to estimate based on
## which parameters were estimated in the original paper. For this
## example we do not estimate all of the parameters they did as to do
## so would require fitting all 3 food levels simultaneous.

## DEB parameters to estimate
kappa <-debinfer_par(name = "kappa", var.type = "de", fixed = FALSE,
                     value = parms["kappa"], prior = "unif",
                     hypers = list(min=0, max=1),
                     prop.var = 0.001, samp.type="rw")


## because JMv is small and positive I sample it in log space
logJMv <-debinfer_par(name = "logJMv", var.type = "de", fixed = FALSE,
                   value=parms["logJMv"], prior = "norm",
                   hypers = list(mean = 0, sd = 10 ),
                   prop.var = 0.01, samp.type = "rw")


## Observation parameters to estimate
sdlog.L <-debinfer_par(name = "sdlog.L", var.type = "obs", fixed = FALSE,
                       value = 1, prior = "lnorm",
                       hypers = list(meanlog = 0, sdlog = 1 ),
                       prop.var = c(4,5), samp.type = "rw-unif")
    
sdlog.E <-debinfer_par(name = "sdlog.E", var.type = "obs", fixed = FALSE,
                       value = 1, prior = "lnorm",
                       hypers = list(meanlog = 0, sdlog = 1),
                       prop.var = c(4,5), samp.type = "rw-unif")


## These were estimated in the original paper, but we fix them here
Wp <-debinfer_par(name = "Wp", var.type = "de", fixed = TRUE,
                  value=parms["Wp"], prior = "lnorm",
                  hypers = list(meanlog = 1, sdlog = 0.1 ),
                  prop.var = c(4,5), samp.type = "rw-unif")

JAM <-debinfer_par(name = "JAM", var.type = "de", fixed = TRUE,
                   value=parms["JAM"], prior = "lnorm",
                   hypers = list(meanlog = 0, sdlog = 0.1 ),
                   prop.var = c(4,5), samp.type = "rw-unif")


## These parameters were assumed and fixed in the original paper
deltaM <-debinfer_par(name = "deltaM", var.type = "de", fixed = TRUE, value=parms["deltaM"])
f <-debinfer_par(name = "f", var.type = "de", fixed = TRUE, value=parms["f"])
fb <-debinfer_par(name = "fb", var.type = "de", fixed = TRUE, value=parms["fb"])
yAX <-debinfer_par(name = "yAX", var.type = "de", fixed = TRUE, value=parms["yAX"])

yVA <-debinfer_par(name = "yVA", var.type = "de", fixed = TRUE, value=parms["yVA"])
yAV <-debinfer_par(name = "yAV", var.type = "de", fixed = TRUE, value=parms["yAV"])
dV <-debinfer_par(name = "dV", var.type = "de", fixed = TRUE, value=parms["dV"])
WB0 <- debinfer_par(name = "WB0", var.type = "obs", fixed = TRUE, value=parms["WB0"])

## two values of yBA were considered in the paper, we focus on one
yBA <-debinfer_par(name = "yBA", var.type = "obs", fixed = TRUE, value=parms["yBA"])



## Initial conditions
WB <- debinfer_par(name = "WB", var.type = "init", fixed = TRUE, value = y["WB"])
L <- debinfer_par(name = "Lw", var.type = "init", fixed = TRUE, value = y["Lw"])
WR <- debinfer_par(name = "WR", var.type = "init", fixed = TRUE, value = y["WR"])


## Once all parameters have been individually specified, we combine
## them using a setup function
mcmc.pars<-setup_debinfer(kappa, sdlog.L, sdlog.E, deltaM, f, fb, JAM, yAX, logJMv,
                          yVA, yAV, dV, Wp, yBA, WB0, WB, L, WR)

## do inference with deBInfer
## MCMC iterations
iter <- 20000


## inference call
## NB: Running 20000 iterations for this inference call takes about 5 minutes on a modern desktop computer 
mcmc_samples <- de_mcmc(N = iter, data = dat, de.model = DEBKiss1,
                        obs.model = DEBKiss_obs_model, all.params = mcmc.pars,
                        Tmax = max(dat$time), data.times = dat$time, cnt = 500,
                        plot = FALSE, verbose.mcmc = TRUE,
                        solver = "ode", method="rk4")

## MCMC convergence assessment
## uncomment the following section of R code to run an additional two chains and calculate the potential scale reduction factor to assess convergence
## deBInfer currently does not provide automated facilities for running multiple chains, we need to  repeat the inference call to run additional chains

# mcmc_samples_chain_2 <- de_mcmc(N = iter, data = dat, de.model = DEBKiss1,
#                         obs.model = DEBKiss_obs_model, all.params = mcmc.pars,
#                         Tmax = max(dat$time), data.times = dat$time, cnt = 500,
#                         plot = FALSE, verbose.mcmc = TRUE,
#                         solver = "ode", method="rk4")

# mcmc_samples_chain_3 <- de_mcmc(N = iter, data = dat, de.model = DEBKiss1,
#                                 obs.model = DEBKiss_obs_model, all.params = mcmc.pars,
#                                 Tmax = max(dat$time), data.times = dat$time, cnt = 500,
#                                 plot = FALSE, verbose.mcmc = TRUE,
#                                 solver = "ode", method="rk4")

## We then collate the samples from all three chains into an mcmc.list object, the data structure used by the CODA package for multi-chain MCMC outputs
# three_chains <- as.mcmc.list(list(mcmc_samples$samples, mcmc_samples_chain_2$samples, mcmc_samples_chain_3$samples))

## and lastly we calculate the potential scale reduction factor (also known as Gelman and Rubin's convergence diagnostic or R-hat). Values < 1.1 indicate approximate convergence.

# gelman.diag(three_chains)


## plotting samples using built in functions, based on the CODA package in R
plot(mcmc_samples, burnin=1000)

pairs(mcmc_samples, burnin=1000)

post_prior_densplot(mcmc_samples, burnin=1000)


## creating posterior trajectories

y<-c(WB=0.000001, Lw=12.8, WR=0)
parms<-c(deltaM=0.401, f=1, fb=0.8, JAM=0.11, yAX=0.8,
         kappa=0.89, logJMv=log(0.008), yVA=0.8, yAV=0.8,
         dV=0.1, Wp=70, yBA=0.95, WB0=0.15)


## Plot the data together with the model output based on the
## parameters from the paper
times<-seq(0, 160, by=0.5)

samps.thin<-window(mcmc_samples$samples[,c('kappa','logJMv')], 1001, 20000, thin = 10)

ptemp<-parms
## creating objects to hold the length and reproduction trajectories
Lws<-WRs<-matrix(NA, nrow=length(times), ncol=nrow(samps.thin))

## this for loop will call the solver with the thinned parameter samples
## NB: simulating the trajectories will take 3-5 minutes on a modern desktop computer
Sys.time()
for(i in 1:nrow(samps.thin)){
    ## replace kappa and logJMv with the posterior samples
    ptemp[6:7]<-samps.thin[i,]

    ## solve the ODEs
    out <- ode(y, times, DEBKiss1, ptemp, method="rk4")

    ## save just the Length and reproduction
    Lws[,i]<-out[,3]
    WRs[,i]<-out[,4]
}
Sys.time()


## calculates the posterior mean trajectories
Lwmean<-apply(Lws, 1, mean)
WRmean<-apply(WRs, 1, mean)

## calculates the posterior credible intervals of the MEAN trajectory
## (not the full prediction intervals that would include the
## observation noise)
Lwqs<-apply(Lws, 1, quantile, probs=c(0.025, 0.975))
WRqs<-apply(WRs, 1, quantile, probs=c(0.025, 0.975))


## plots the posterior means and CIs of the trajectories with the data
par(mfrow=c(1,2),mai=c(.8,.8,.2,.1))# bty="n")
plot(out[,1], Lwmean, type="l", ylab="Observed shell length (mm)", xlab="Time (days)", lwd=2, col=2, lty=1, pch=23, ylim=c(12, 31), xlim=c(0,148))
lines(out[,1], Lwqs[1,], lty=3, lwd=2, col=2)
lines(out[,1], Lwqs[2,], lty=3, lwd=2, col=2)
points(dat$time, dat$L, lwd=2)

plot(out[,1], WRmean*parms["yBA"]/parms["WB0"], type="l", ylab="Total eggs", xlab="Time (days)", ylim=c(0, 1100), lwd=2, col=4, lty=1, xlim=c(0,148))
lines(out[,1], WRqs[1,]*parms["yBA"]/parms["WB0"], lty=3, lwd=2, col=4)
lines(out[,1], WRqs[2,]*parms["yBA"]/parms["WB0"], lty=3, lwd=2, col=4)

points(dat$time, dat$Egg, pch=25, lwd=2)



## Extra plots
## The plots showing shaded HDPIs use functionality from the rethinking package, which is not yet on CRAN but can be installed using devtools:

## install.packages(c("devtools","mvtnorm","loo","coda"), repos="https://cloud.r-project.org/",dependencies=TRUE)
## library(devtools)
## install_github("rmcelreath/rethinking")

source("plotting_extras.R")

samps<-window(mcmc_samples$samples, 1001, 20000)
ss<-summary(samps)

par(mfrow = c(2,2))
ps<-c("kappa", "logJMv", "sdlog.L", "sdlog.E")
for (pp in ps[1:4]){
    pretty_posterior_plot(samps, ss, ref.params = NULL,
                          param = pp, legend = FALSE, deBInfer_result = mcmc_samples)
}


legend("topright", legend = c("posterior mean value", "95% HPDI", "prior density"), lty = c(1, NA,2), pch = c(NA,15,NA), col = c("black", rethinking::col.alpha("black",0.15), 'red'), bty = 'n')




