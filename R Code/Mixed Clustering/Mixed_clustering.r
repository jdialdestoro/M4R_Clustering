source("M4R_Clustering/R Code/Collaborative Filtering/CF.r")
source("M4R_Clustering/R Code/Clustering/Rating_clustering.r")
source("M4R_Clustering/R Code/Mixed Clustering/Mixed_clustering_functions.r")

best_n <- function(df, n_range, clust_func, user = TRUE, p = FALSE) {
  scores <- rep(0, length(n_range))

  if (p == FALSE) {
    # loop over each n clusters
    for (i in seq_along(n_range)) {
      print(paste("Computing objective for", n_range[i], "clusters"))
      scores[i] <- scores[i] + clust_func(df, n_range[i], user)$loss
    }
  } else {
    # loop over each n clusters
    for (i in seq_along(n_range)) {
      print(paste("Computing objective for", n_range[i], "clusters"))
      scores[i] <- scores[i] + clust_func(df, n_range[i], user, p)$loss
    }
  }

  return(scores)
}

cval_mixed_clust <- function(df, df_feat, t, n, k_range, metric, pred_func,
                             clust_func, user = TRUE) {
  nk <- length(k_range)
  # initial scores table
  scores <- data.frame(rmse = rep(0, nk), mae = rep(0, nk), r2 = rep(0, nk),
                       offline = rep(0, t), online = rep(0, nk))

  # t-fold creation
  cval_f_i <- t_fold_index(df, t, user) # nolint
  cval_f <- t_fold(df, cval_f_i) # nolint

  # loop over each fold
  for (i in 1:t) {
    print(paste("Offline phase for fold", i, ":"))
    t1 <- Sys.time()

    # ui and similarity matrix
    ui <- gen_ui_matrix(df, cval_f[[i]]) # nolint

    # create user clusters
    clusters <- clust_func(df_feat, n, user)$clusters

    # segment user ratings matrix into the n clusters
    uis <- replicate(n, c())

    if (user == TRUE) {
      for (j in 1:n) {
        uis[[j]] <- ui[which(clusters == j), ]
      }
    } else {
      for (j in 1:n) {
        uis[[j]] <- ui[, which(clusters == j)]
      }
    }

    # similarity matrix for each segmented ui matrix
    sims <- replicate(n, c())
    for (j in 1:n) {
      sims[[j]] <- metric(uis[[j]], user)
    }

    time <- Sys.time() - t1
    print(time)
    scores$offline[i] <- time

    # loop over every k
    for (k in seq_along(k_range)) {
      print(paste("Online phase for k =", k_range[k]))
      t1 <- Sys.time()

      # predict on test fold ratings
      r_pred <- pred_fold_clust(df, cval_f_i[[i]], uis, sims, pred_func, # nolint
                                k_range[k], clusters, user)
      r_true <- df$rating[cval_f_i[[i]]]

      # error metrics
      scores$rmse[k] <- scores$rmse[k] + rmse(r_pred, r_true) # nolint
      scores$mae[k] <- scores$mae[k] + mae(r_pred, r_true) # nolint
      scores$r2[k] <- scores$r2[k] + r2(r_pred, r_true) # nolint

      time <- Sys.time() - t1
      print(time)
      scores$online[k] <- scores$online[k] + time
    }
  }
  scores[c(1:3, 5)] <- scores[c(1:3, 5)] / t
  return(scores)
}

cval_mixed_clust_pred <- function(df, df_feat, t, n_range, metric, pred_func,
                                  clust_func, sim = TRUE, user = TRUE) {
  nn <- length(n_range)
  # initial scores table
  scores <- data.frame(rmse = rep(0, nn), mae = rep(0, nn), r2 = rep(0, nn),
                       offline = rep(0, nn), online = rep(0, nn))

  # t-fold creation
  cval_f_i <- t_fold_index(df, t, user) # nolint
  cval_f <- t_fold(df, cval_f_i) # nolint

  # loop over each fold
  for (n in 1:length(n_range)) {
    print(paste("Testing with", n_range[n], "clusters:"))

    for (i in 1:t) {
      print(paste("Offline phase for fold", i, ":"))
      t1 <- Sys.time()

      # ui and similarity matrix
      ui <- gen_ui_matrix(df, cval_f[[i]]) # nolint

      # create user clusters
      clusters <- clust_func(df_feat, n_range[n], user)$clusters

      # segment user ratings matrix into the n clusters
      uis <- replicate(n, c())

      if (user == TRUE) {
        for (j in 1:n_range[n]) {
          uis[[j]] <- ui[which(clusters == j), ]
        }
      } else {
        for (j in 1:n_range[n]) {
          uis[[j]] <- ui[, which(clusters == j)]
        }
      }

      if (sim == TRUE) {
        # similarity matrix for each segmented ui matrix
        sims <- replicate(n_range[n], c())
        for (j in 1:n_range[n]) {
          sims[[j]] <- metric(uis[[j]], user)
        }
      } else {
        sims <- NA
      }

      time <- Sys.time() - t1
      print(time)
      scores$offline[n] <- scores$offline[n] + time

      print(paste("Online phase:"))
      t1 <- Sys.time()

      r_pred <- pred_fold_clust_whole(df, cval_f_i[[i]], uis, pred_func,
                                      clusters, sims, user)

      r_true <- df$rating[cval_f_i[[i]]]

      # error metrics
      scores$rmse[n] <- scores$rmse[n] + rmse(r_pred, r_true) # nolint
      scores$mae[n] <- scores$mae[n] + mae(r_pred, r_true) # nolint
      scores$r2[n] <- scores$r2[n] + r2(r_pred, r_true) # nolint

      time <- Sys.time() - t1
      print(time)
      scores$online[n] <- scores$online[n] + time

    }
  }
  scores <- scores / t
  return(scores)
}
