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
Zscores<-Zscores[,-14]
#file seems to contain a whole load of 'NA' entries


boxplot(Zscores[c("Homo sapiens",
"Theria",
"Mammalia",
"Amniota",
"Euteleostomi",
"Chordata",
"Deuterostomia",
"Coelomata",
"Bilateria",
"Eumetazoa",
"Opisthokonta",
"Eukaryota",
"CellularOrganisms"
)],)


par(cex=0.6,las=3)

vioplot(
Zscores$"Homo sapiens",
Zscores$"Theria",
Zscores$"Mammalia",
Zscores$"Amniota",
Zscores$"Euteleostomi",
Zscores$"Chordata",
Zscores$"Deuterostomia",
Zscores$"Coelomata",
Zscores$"Bilateria",
Zscores$"Eumetazoa",
Zscores$"Opisthokonta",
Zscores$"Eukaryota",
Zscores$"cellular organisms",
names=c("Homo sapiens",
"Theria",
"Mammalia",
"Amniota",
"Euteleostomi",
"Chordata",
"Deuterostomia",
"Coelomata",
"Bilateria",
"Eumetazoa",
"Opisthokonta",
"Eukaryota",
"Cellular\nOrganisms"), wex=1.2, col='lightblue'
)

title(main="Violin Plot Of Epoch Comb Z-scores Collapsed to 13 Taxonomy Points")
title(ylab = 'Z-score')
        
source("../bin/A2Rcode.r")
        
library("lsa")
cosZscores<-cosine(as.matrix(t(Zscores)))
        
# prepare hierarchical cluster
hc = hclust(dist(cosZscores))

# load code of A2R function
#source("http://addictedtor.free.fr/packages/A2R/lastVersion/R/code.R")
# colored dendrogram

op = par(bg="white")
A2Rplot(hc, k=24, boxes = FALSE, show.labels=TRUE,
   col.up = "gray50", col.down = c("black","chartreuse4","red1","blue","darkgoldenrod1","black","red","grey","black","chartreuse4","blue","red1","darkgoldenrod1","black","red","grey","black","chartreuse4","blue","red1","darkgoldenrod1","black","red","grey"))
par(op)


data <- read.csv("./cluster_10.tsv.mat", header=TRUE,sep = "\t")
cosZscores<-cosine(as.matrix(t(data)))
heatmap.2(cosZscores,trace="none")
hc=hclust(dist(cosZscores))
plot(hc,cex=3,xlab='',main='Cluster 10',ylab='')


library(ape)
library(cluster) 
plot(as.phylo(hclust(dist(cosZscores))),type="fan")

