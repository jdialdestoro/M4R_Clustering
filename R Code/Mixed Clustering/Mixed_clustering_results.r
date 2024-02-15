# load packages
library("scales")
library("Rtsne")

# read in the data
ml100k <- read.csv("M4R_Clustering/Data/ml100k.csv")

ml100k_dem <- read.csv("M4R_Clustering/Data/ml100k_dem.csv")

ml100k_feat <- read.csv("M4R_Clustering/Data/ml100k_feat_a.csv")

# call functions
source("M4R_Clustering/R Code/Collaborative Filtering/Similarities.r")
source("M4R_Clustering/R Code/Collaborative Filtering/Predictors.r")
source("M4R_Clustering/R Code/Mixed Clustering/Mixed_clustering_functions.r")
source("M4R_Clustering/R Code/Mixed Clustering/Mixed_clustering.r")

# initialise evaluation fixed variables
krange <- krange <- seq(from = 10, to = 100, by = 10)
n_range <- 2:15

# find optimal number of principal components to retain for FAMD
ml100k_dem_pca <- famd(ml100k_dem, 2, 22, TRUE, FALSE, TRUE)
cumvar <- ml100k_dem_pca[, 3]
plot(cumvar, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(2)[1], xlab = "Principal components",
     ylab = "Cumulative explained variance")

gow_obj_u <- best_n(ml100k_dem, 2:25, gow_pam)
hl_obj_u <- best_n(ml100k_dem, 2:25, hl_pam)
kproto_obj_u <- best_n(ml100k_dem, 2:15, kprototypes)
mk_obj_u <- best_n(ml100k_dem, 2:15, mixed_k)
msk_obj_u <- best_n(ml100k_dem, 2:15, mskmeans)
famd_obj_u <- best_n_famd(ml100k_dem, 2:25, 5)
mr_obj_u <- best_n(ml100k_dem, 2:15, mrkmeans)
kam_obj_u <- best_n(ml100k_dem, 2:15, kamila_clust)

full1 <- c(kproto_obj_u, rep(0, 10))
full2 <- c(mk_obj_u, rep(0, 10))
full3 <- c(msk_obj_u, rep(0, 10))
full4 <- c(mr_obj_u, rep(0, 10))
full5 <- c(kam_obj_u, rep(0, 10))

mclust_obj_u <- cbind(gow_obj_u, hl_obj_u, full1, full2, full3,
                      famd_obj_u, full4, full5)
colnames(mclust_obj_u) <- c("gowpam", "hlpam", "kprototypes", "mixed kmeans",
                            "ms kmeans", "famd", "mr kmeans", "kamila")
write.csv(mclust_obj_u, file = "M4R_Clustering/Results/mclust_obj_u.csv",
          row.names = FALSE)

plot(2:25, gow_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[1], xlab = "n clusters",
     ylab = "Clustering objective function")
plot(2:25, hl_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[2], xlab = "n clusters",
     ylab = "Clustering objective function")
plot(2:15, kproto_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[3], xlab = "n clusters",
     ylab = "Total within cluster sum of squares")
plot(2:15, mk_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[4], xlab = "n clusters",
     ylab = "Total within cluster sum of squares")
plot(2:15, msk_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[5], xlab = "n clusters",
     ylab = "Total within cluster sum of squares")
plot(2:25, famd_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[6], xlab = "n clusters",
     ylab = "Total within cluster sum of squares")
plot(2:15, mr_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[7], xlab = "n clusters",
     ylab = "Clustering objective function")
plot(2:15, kam_obj_u, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(8)[8], xlab = "n clusters",
     ylab = "Clustering objective function")

# find optimal number of principal components to retain for FAMD
ml100k_feat_pca <- famd(ml100k_feat, 2, 24, FALSE, FALSE, TRUE)
cumvar <- ml100k_feat_pca[, 3]
plot(cumvar, lty = 1, type = "l", lwd = 2,
     col = hue_pal()(2)[1], xlab = "Principal components",
     ylab = "Cumulative explained variance")

gow_obj_i <- best_n(ml100k_feat, n_range, gow_pam, FALSE)
hl_obj_i <- best_n(ml100k_feat, n_range, hl_pam, FALSE)
kproto_obj_i <- best_n(ml100k_feat, n_range, kprototypes, FALSE)
mk_obj_i <- best_n(ml100k_feat, n_range, mixed_k, FALSE)
msk_obj_i <- best_n(ml100k_feat, n_range, mskmeans, FALSE)
famd_obj_i <- best_n_famd(ml100k_feat, n_range, 5, FALSE)
mr_obj_i <- best_n(ml100k_feat, n_range, mrkmeans, FALSE)
kam_obj_i <- best_n(ml100k_feat, n_range, kamila_clust, FALSE)

mclust_obj_i <- cbind(gow_obj_i, hl_obj_i, kproto_obj_i, mk_obj_i, msk_obj_i,
                      famd_obj_i, mr_obj_i, kam_obj_i)
colnames(mclust_obj_i) <- c("gowpam", "hlpam", "kprototypes", "mixed kmeans",
                            "ms kmeans", "famd", "mr kmeans", "kamila")
write.csv(mclust_obj_i, file = "M4R_Clustering/Results/mclust_obj_i.csv",
          row.names = FALSE)