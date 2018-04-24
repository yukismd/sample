
######################################
# Sample to explain model complexity #
######################################

## N of data points
N <- 25

## Create x and y 
set.seed(23)
x <- runif(n=N, min=-12, max=12)
y <- (x+6)*(x-2)*(x-8) + 100*rnorm(N)   # Cubic function

plot(x, y, xlim=c(-9,12), ylim=c(-690,750))


### Simple linior regression ###
res1 <- lm(y~x)
summary(res1)    # R2=0.2115

plot(x, y, xlim=c(-9,12), ylim=c(-690,750))
abline(res1, col="red")


### polynomial degree 3 ###
res2 <- lm(y~poly(x,3,raw=TRUE))
summary(res2)    # R2=0.8841

plot(x, y, xlim=c(-9,12), ylim=c(-690,750))
par(new=TRUE)
y_out1 <- function(x){
  out <- (
    res2$coefficients[1] +
    res2$coefficients[2] * x +
    res2$coefficients[3] * x^2 +
    res2$coefficients[4] * x^3 )
  return(out)
}
curve(y_out1, -12, 12, col="red", xlim=c(-9,12), ylim=c(-690,750), ylab="")


### polynomial degree 15 ###
deg_poly <- 15
res3 <- lm(y~poly(x,deg_poly,raw=TRUE))
summary(res3)    # 0.9566

plot(x, y, xlim=c(-9,12), ylim=c(-690,750))
par(new=TRUE)
y_out2 <- function(x){
  out <- 0
  for(i in 1:(deg_poly+1)) {
    out <- out + (res3$coefficients[i] * (x^(i-1)))
    #print(out)
  }
  return(out)
}
curve(y_out2, -12, 12, col="red", xlim=c(-9,12), ylim=c(-690,750), ylab="")

