library("cluster")
library("fastDummies")
library("fpc")
library("clustMixType")
library("kmed")
library("kamila")
library("FactoMineR")

range_normalise <- function(x) {
  # normalise variable to a [0,1] range
  return((x - min(x)) / (max(x) - min(x)))
}

gow_pam <- function(df, k) {
  # remove id and zip variable
  df$userID <- NULL
  df$zip <- NULL
  # range normalise age variable
  df$age <- range_normalise(df$age)
  # binarise gender variable
  df$gender <- as.numeric(df$gender == "M")
  # dummy code occupation variable
  df <- dummy_cols(df, select_columns = "occupation")
  df$occupation <- NULL

  # euclidean dissimilarity matrix
  dsim <- daisy(df, metric = "gower")

  return(pam(dsim, k = k)$clustering)
}

hl_pam <- function(df, k) {
  # remove id and zip variable
  n_u <- length(df$userID)
  df$userID <- NULL
  df$zip <- NULL
  # range normalise age variable
  df$age <- range_normalise(df$age)
  # binarise gender variable
  df$gender <- as.numeric(df$gender == "M")
  # dummy code occupation variable
  df <- dummy_cols(df, select_columns = "occupation")
  n_cat <- length(unique(df$occupation))
  df$occupation <- NULL

  # compute categorical scaling factor
  fac <- distancefactor(n_cat, n_u)
  df[3:(2 + n_cat)] <- df[3:(2 + n_cat)] * fac

  # euclidean dissimilarity matrix
  dsim <- daisy(df, metric = "euclidean")

  return(pam(dsim, k = k)$clustering)
}

kprototypes <- function(df, k) {
  # remove id and zip variable
  df$userID <- NULL
  df$zip <- NULL
  # binarise gender variable
  df$gender <- as.numeric(df$gender == "M")
  # dummy code occupation variable
  df$occupation <- as.factor(df$occupation)
  return(kproto(df, k)$cluster)
}

mixed_k <- function(df, k) {
  # remove id and zip variable
  df$userID <- NULL
  df$zip <- NULL
  # binarise gender variable
  df$gender <- as.numeric(df$gender == "M")
  # dummy code occupation variable
  df$occupation <- as.factor(df$occupation)

  d <- distmix(df, method = "ahmad", idnum = 1, idbin = 2, idcat = 3)
  return(fastkmed(d, k)$cluster)
}

mskmeans <- function(df, k) {
  # remove zip variable
  df$zip <- NULL

  # dummy code gender and occupation variable
  df <- dummy_cols(df, select_columns = "gender")
  df$gender <- NULL

  df <- dummy_cols(df, select_columns = "occupation")
  df$occupation <- NULL

  df$userID <- df$age

  return(gmsClust(df[1:2], df[3:25], k)$results[1])
}

famd <- function(df, k) {
  # remove id and zip variable
  df$userID <- NULL
  df$zip <- NULL

  pca <- FAMD(df, k, graph = FALSE)$ind$coord

  return(kmeans(pca, k)$cluster)
}