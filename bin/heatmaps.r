cos.sim <- function(ix) 
{
  A = X[ix[1],]
  B = X[ix[2],]
  return( sum(A*B)/sqrt(sum(A^2)*sum(B^2)) )
}   


n <- nrow(X) 
cmb <- expand.grid(i=1:n, j=1:n) 
C <- matrix(apply(cmb,1,cos.sim),n,n)


library(gplots)

setwd("~/TraP/data")

#Read in a file of z scores to perform agglomerative clustering upon.
Zscores <- read.delim("./matrix.tab", sep = "\t",header=FALSE)
rownames(Zscores)<-as.matrix(read.delim("./cols.tab", sep = "\t",header=FALSE))
colnames(Zscores)<-as.matrix(read.delim("./rows.tab", sep = "\t",header=FALSE))
Zscores<-Zscores[,-22]
#file seems to contain a whole load of 'NA' entries

cosZscores<-cosine(as.matrix(t(Zscores)))

data <- read.delim("./Intersection-AllvsAllvsAllSummary.dat", sep = "\t")

source("../bin/A2Rcode.r")

# prepare hierarchical cluster
hc = hclust(dist(Zscores),method="ward")

# load code of A2R function
#source("http://addictedtor.free.fr/packages/A2R/lastVersion/R/code.R")
# colored dendrogram


op = par(bg="white")
A2Rplot(hc, k=15, boxes = FALSE, show.labels=TRUE,
        col.up = "gray50", col.down = c("blue4","brown","burlywood3","blue2","cyan","darkcyan","darkorchid3","black","chartreuse4","red1","darkgoldenrod1","black","blue","red","grey"))
par(op)

