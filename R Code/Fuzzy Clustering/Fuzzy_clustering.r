source("M4R_Clustering/R Code/Fuzzy Clustering/Mixed_fuzzy_functions.r")

best_n_fmclust <- function(df, n_range, m, clust_func, user = TRUE, p = FALSE) {
  scores <- rep(0, length(n_range))

  if (p == FALSE) {
    # loop over each n clusters
    for (i in seq_along(n_range)) {
      print(paste("Computing objective for", n_range[i], "clusters"))
      scores[i] <- scores[i] + tail(clust_func(df, n_range[i], m, user)$losses, 1)
    }
  } else {
    # loop over each n clusters
    for (i in seq_along(n_range)) {
      print(paste("Computing objective for", n_range[i], "clusters"))
      scores[i] <- scores[i] + tail(clust_func(df, n_range[i], m, user, p = p)$losses, 1)
    }
  }

  return(scores)
}

best_n_fclust <- function(ui, n_range, m) {
  scores <- rep(0, length(n_range))

  for (i in seq_along(n_range)) {
    print(paste("Computing objective for", n_range[i], "clusters"))
    scores[i] <- scores[i] + tail(fuzzy_c_means(ui, n_range[i], m)$losses, 1)
  }

  return(scores)
}

pred_fold_split <- function(df, df_ind, uis, sims, pred_func, k, clusters,
                            n, inds, user = TRUE) {
  preds <- c()

  if (user == TRUE) {
    # compute rating prediction for every test case
    for (p in df_ind) {
      preds_i <- 0

      # target prediction id
      userid <- df$userID[p]
      filmid <- df$filmID[p]

      # find users cluster
      clusts <- which(clusters[, userid] > 1 / n)

      for (c in clusts) {
        # within cluster user index
        userind <- which(inds[[c]] == userid)

        # prediction
        preds_i <- preds_i + clusters[c, userid] *
          pred_func(uis[[c]], sims[[c]], k, userind, filmid)
      }
      preds <- c(preds, preds_i / sum(clusters[clusts, userid]))
    }
  } else {
    # compute rating prediction for every test case
    for (p in df_ind) {
      preds_i <- 0

      # target prediction id
      userid <- df$userID[p]
      filmid <- df$filmID[p]

      # find film cluster
      clusts <- which(clusters[, filmid] > 1 / n)

      for (c in clusts) {
        # within cluster film index
        filmind <- which(inds[[c]] == filmid)

        # prediction
        preds_i <- preds_i + clusters[c, filmid] *
          pred_func(uis[[c]], sims[[c]], k, userid, filmind, user)
      }
      preds <- c(preds, preds_i / sum(clusters[clusts, filmid]))
    }
  }
  return(preds)
}

cval_fclust_split <- function(df, t, n, m, k_range, metric, pred_func,
                              user = TRUE) {
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

    if (user == TRUE) {
      # create user clusters
      clusters <- fuzzy_c_means(ui, n, m)$clusters
    } else {
      # create user clusters
      clusters <- fuzzy_c_means(t(ui), n, m)$clusters
    }

    # find users belonging to each cluster
    inds <- replicate(n, c())
    for (j in 1:n) {
      inds[[j]] <- which(clusters[j, ] > 1 / n)
    }

    # segment user ratings matrix into the n clusters
    uis <- replicate(n, c())

    if (user == TRUE) {
      for (j in 1:n) {
        uis[[j]] <- ui[inds[[j]], ]
      }
    } else {
      for (j in 1:n) {
        uis[[j]] <- ui[, inds[[j]]]
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
      r_pred <- pred_fold_split(df, cval_f_i[[i]], uis, sims, pred_func,
                                k_range[k], clusters, n, inds, user)
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

cval_fmclust_split <- function(df, df_feat, t, n, m, k_range, metric,
                               pred_func, clust_func, user = TRUE) {
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
    clusters <- clust_func(df_feat, n, m, user)$clusters

    # find users belonging to each cluster
    inds <- replicate(n, c())
    for (j in 1:n) {
      inds[[j]] <- which(clusters[j, ] > 1 / n)
    }

    # segment user ratings matrix into the n clusters
    uis <- replicate(n, c())

    if (user == TRUE) {
      for (j in 1:n) {
        uis[[j]] <- ui[inds[[j]], ]
      }
    } else {
      for (j in 1:n) {
        uis[[j]] <- ui[, inds[[j]]]
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
      r_pred <- pred_fold_split(df, cval_f_i[[i]], uis, sims, pred_func,
                                k_range[k], clusters, n, inds, user)
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

fmclust_pred <- function(ui, k, userid, filmid, clusters, c, user = TRUE) {
  if (user == TRUE) {
    # indices of users who have rated the film
    ind <- which(ui[, filmid] > 0)
    # find k users most belonging to this cluster
    neighbours <- ind[order(-clusters[c, ind])[1:k]]

    # predict using user weights
    pred <- sum(clusters[c, neighbours] * ui[neighbours, filmid]) /
      sum(clusters[c, neighbours])

  } else {
    # indices of films which have been rated by the user
    ind <- which(ui[userid, ] > 0)
    # find k users most belonging to this cluster
    neighbours <- ind[order(-clusters[c, ind])[1:k]]

    # predict using user weights
    pred <- sum(clusters[c, neighbours] * ui[userid, neighbours]) /
      sum(clusters[c, neighbours])
  }

  return(pred)
}

pred_fold_nosim <- function(df, df_ind, ui, k, clusters, n, user = TRUE) {
  preds <- c()

  if (user == TRUE) {
    # compute rating prediction for every test case
    for (p in df_ind) {
      preds_i <- 0

      # target prediction id
      userid <- df$userID[p]
      filmid <- df$filmID[p]

      # loop over each cluster
      for (c in 1:n) {
        # prediction
        preds_i <- preds_i + clusters[c, userid] *
          fmclust_pred(ui, k, userid, filmid, clusters, c)
      }
      preds <- c(preds, preds_i / sum(clusters[, userid]))
    }
  } else {
    # compute rating prediction for every test case
    for (p in df_ind) {
      preds_i <- 0

      # target prediction id
      userid <- df$userID[p]
      filmid <- df$filmID[p]

      for (c in 1:n) {
        # prediction
        preds_i <- preds_i + clusters[c, filmid] *
          fmclust_pred(ui, k, userid, filmid, clusters, c, user)
      }
      preds <- c(preds, preds_i / sum(clusters[, filmid]))
    }
  }
  return(preds)
}

cval_fmclust_nosim <- function(df, df_feat, t, n, m, k_range, clust_func,
                               user = TRUE) {
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
    clusters <- clust_func(df_feat, n, m, user)$clusters

    time <- Sys.time() - t1
    print(time)
    scores$offline[i] <- time

    # loop over every k
    for (k in seq_along(k_range)) {
      print(paste("Online phase for k =", k_range[k]))
      t1 <- Sys.time()

      # predict on test fold ratings
      r_pred <- pred_fold_nosim(df, cval_f_i[[i]], ui, k_range[k], clusters, n,
                                user)
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