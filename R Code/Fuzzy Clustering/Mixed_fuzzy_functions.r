source("M4R_Clustering/R Code/Collaborative Filtering/Similarities.r")
source("M4R_Clustering/R Code/Mixed Clustering/Mixed_clustering_functions.r")
source("M4R_Clustering/R Code/Fuzzy Clustering/Fuzzy KAMILA/KAMILA.r")

euc_dsim <- function(df, v, c) {
  n <- nrow(df)

  dsim_mat <- matrix(NA, nrow = c, ncol = n)

  for (i in 1:c) {
    for (j in 1:n) {
      ind <- which(!is.na(v[i, ]) & !is.na(df[j, ]))
      if (length(ind) == 0) {
        dsim_mat[i, j] <- NA
      } else {
        dsim_mat[i, j] <- norm(v[i, ][ind] - df[j, ][ind], type = "2")
      }
    }
  }
  dsim_mat[is.na(dsim_mat)] <- max(dsim_mat, na.rm = TRUE)
  return(dsim_mat)
}

fuzzy_c_means <- function(df, c, m, e = 1e-2) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  p <- ncol(df)

  # set NA to 0 in df for v^(l) computation
  df0 <- df
  df0[is.na(df0)] <- 0

  inds <- replicate(p, c())
  for (i in 1:p) {
    inds[[i]] <- which(!is.na(df[, i]))
  }

  # initialise cluster memberships w^(0)
  w_old <- matrix(runif(n * c), nrow = c)
  w_old <- t(t(w_old) / colSums(w_old, na.rm = TRUE))

  # initialise centroids c^(1)
  w_sum <- NULL
  for (i in 1:p) {
    if (length(inds[[i]]) == 1) {
      w_sum <- cbind(w_sum, w_old[, inds[[i]]]**m)
    } else {
      w_sum <- cbind(w_sum, rowSums(w_old[, inds[[i]]]**m))
    }
  }
  c_new <- (w_old**m %*% df0) / w_sum

  # update u^(1)
  d <- euc_dsim(df, c_new, c)**(2 / (m - 1))
  w_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

  # initialise losses
  losses <- c(0, sum(diag(w_new**m %*% t(d**(m - 1)))))

  count <- 1
  # iterate until convergence
  while (abs(losses[count] - losses[count + 1]) > e) {
    w_old <- w_new

    # update v^(l+1)
    w_sum <- NULL
    for (i in 1:p) {
      if (length(inds[[i]]) == 1) {
        w_sum <- cbind(w_sum, w_new[, inds[[i]]]**m)
      } else {
        w_sum <- cbind(w_sum, rowSums(w_new[, inds[[i]]]**m))
      }
    }
    c_new <- (w_new**m %*% df0) / w_sum

    # update u^(l+1)
    d <- euc_dsim(df, c_new, c)**(2 / (m - 1))
    w_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

    losses <- c(losses, sum(diag(w_new**m %*% t(d**(m - 1)))))

    count <- count + 1
    if (count > 100) {
      break
    }
  }

  return(list(clusters = w_new, centroids = c_new, losses = losses[-1]))
}

fuzzy_gow <- function(df, c, m, user = TRUE, e = 1e-2, inits = 10) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data
  x <- gow_df(df, user) # nolint

  # compute gower disimilarity matrix
  d <- as.matrix(daisy(x, metric = "gower"))**(1 / (m - 1)) # nolint

  for (init in 1:inits) {
    # initalise v^(0)
    ind <- sample.int(n, c)

    # update u^(1)
    u_old <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_old[is.na(u_old)] <- 1

    # compute loss
    loss <- u_old**m %*% d
    # find minimisers of loss and set to v^(1)
    ind <- which(loss[1, ] == min(loss[1, ]))[1]
    v_new <- x[ind, ]
    for (i in 2:c) {
      # ensure centroids are unique
      inds <- which(loss[i, ] == min(loss[i, -ind]))
      ind <- c(ind, inds[which(!(inds %in% ind))[1]])
      v_new <- rbind(v_new, x[ind[i], ])
    }

    # update u^(2)
    u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_new[is.na(u_new)] <- 1

    # initialise losses
    losses <- c(0, sum(diag(u_new**m %*% d[, ind])))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # compute loss
      loss <- u_new**m %*% d
      # find minimisers of loss and set to v^(l)
      ind <- which(loss[1, ] == min(loss[1, ]))[1]
      v_new <- x[ind, ]
      for (i in 2:c) {
        # ensure centroids are unique
        inds <- which(loss[i, ] == min(loss[i, -ind]))
        ind <- c(ind, inds[which(!(inds %in% ind))[1]])
        v_new <- rbind(v_new, x[ind[i], ])
      }

      # update u^(l+1)
      u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
      u_new[is.na(u_new)] <- 1

      # update loss
      losses <- c(losses, sum(diag(u_new**m %*% d[, ind])))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_v <- v_new
      best_losses <- losses
    }
  }

  return(list(clusters = best_u, centroids = best_v, losses = best_losses[-1]))
}

fuzzy_hl <- function(df, c, m, user = TRUE, e = 1e-2, inits = 10) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data
  x <- hl_df(df, user) # nolint

  # compute gower disimilarity matrix
  d <- as(dist(x, "euclidean"), "matrix")**(2 / (m - 1))

  for (init in 1:inits) {
    # initalise v^(0)
    ind <- sample.int(n, c)

    # update u^(1)
    u_old <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_old[is.na(u_old)] <- 1

    # compute loss
    loss <- u_old**m %*% d
    # find minimisers of loss and set to v^(1)
    ind <- which(loss[1, ] == min(loss[1, ]))[1]
    v_new <- x[ind, ]
    for (i in 2:c) {
      # ensure centroids are unique
      inds <- which(loss[i, ] == min(loss[i, -ind]))
      ind <- c(ind, inds[which(!(inds %in% ind))[1]])
      v_new <- rbind(v_new, x[ind[i], ])
    }

    # update u^(2)
    u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_new[is.na(u_new)] <- 1

    # initialise losses
    losses <- c(0, sum(diag(u_new**m %*% d[, ind])))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # compute loss
      loss <- u_new**m %*% d
      # find minimisers of loss and set to v^(l)
      ind <- which(loss[1, ] == min(loss[1, ]))[1]
      v_new <- x[ind, ]
      for (i in 2:c) {
        # ensure centroids are unique
        inds <- which(loss[i, ] == min(loss[i, -ind]))
        ind <- c(ind, inds[which(!(inds %in% ind))[1]])
        v_new <- rbind(v_new, x[ind[i], ])
      }

      # update u^(l+1)
      u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
      u_new[is.na(u_new)] <- 1

      # update loss
      losses <- c(losses, sum(diag(u_new**m %*% d[, ind])))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_v <- v_new
      best_losses <- losses
    }
  }

  return(list(clusters = best_u, centroids = best_v, losses = best_losses[-1]))
}

kproto_dsim <- function(df, v, c, pr, lambda) {
  n <- nrow(df)
  p <- ncol(df)

  dsim_mat <- matrix(NA, nrow = c, ncol = n)

  for (i in 1:c) {
    dsim_mat[i, ] <- rowSums(t(t(as.matrix(df[, 1:pr])) -
                                 as.numeric(v[i, 1:pr]))**2) +
      lambda * rowSums(t(!(t(as.matrix(df[, (pr + 1):p]) ==
                               as.vector(v[i, (pr + 1):p])))))
  }

  return(dsim_mat)
}

fuzzy_kproto <- function(df, c, m, user = TRUE, e = 1e-2, inits = 1) { # nolint
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data
  x <- kproto_df(df, user) # nolint

  # initialise number of continuous and categorical variables
  p <- ncol(x)
  if (user == TRUE) {
    pr <- 1
  } else {
    pr <- 2
  }

  # initialise variable weights
  lambda <- lambdaest(x) # nolint

  for (init in 1:inits) {
    # initalise v^(0)
    ind <- sample.int(n, c)

    # update u^(1)
    d <- kproto_dsim(x, x[ind, ], c, pr, lambda)**(1 / (m - 1)) # nolint
    u_old <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

    # initialise centroids v^(1) continuous variables
    v_con <- (u_old**m %*% as.matrix(x[, 1:pr])) /
      rowSums(u_old**m, na.rm = TRUE)

    # initialise centroids v^(1) categorical variables
    v_cat <- NULL
    # loop over each categorical variable
    for (i in (pr + 1):p) {
      # compute loss when each level is used
      loss <- NULL
      for (level in unique(x[, i])) {
        loss <- cbind(loss, u_old**m %*% as.numeric(!(x[, i] == level)))
      }
      # find best level
      best_level <- NULL
      for (j in 1:c) {
        best_level <- rbind(best_level,
                            as.character(unique(x[, i])
                                        [which(loss[j, ] == min(loss[j, ]))]))
      }
      v_cat <- cbind(v_cat, best_level)
    }
    v_new <- data.frame(v_con, v_cat)

    # update u^(2)
    d <- kproto_dsim(x, v_new, c, pr, lambda)**(1 / (m - 1))
    u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

    # initialise losses
    losses <- c(0, sum(diag(u_new**m %*% t(d**(m - 1)))))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # update centroids v^(l+1) continuous variables
      v_con <- (u_old**m %*% as.matrix(x[, 1:pr])) /
        rowSums(u_old**m, na.rm = TRUE)

      # update centroids v^(l+1) categorical variables
      v_cat <- NULL
      # loop over each categorical variable
      for (i in (pr + 1):p) {
        # compute loss when each level is used
        loss <- NULL
        for (level in unique(x[, i])) {
          loss <- cbind(loss, u_old**m %*% as.numeric(!(x[, i] == level)))
        }
        # find best level
        best_level <- NULL
        for (j in 1:c) {
          best_level <- rbind(best_level,
                              as.character(unique(x[, i])
                                          [which(loss[j, ] == min(loss[j, ]))]))
        }
        v_cat <- cbind(v_cat, best_level)
      }
      v_new <- data.frame(v_con, v_cat)

      # update u^(2)
      d <- kproto_dsim(x, v_new, c, pr, lambda)**(1 / (m - 1))
      u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

      # update loss
      losses <- c(losses, sum(diag(u_new**m %*% t(d**(m - 1)))))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_v <- v_new
      best_losses <- losses
    }
  }

  return(list(clusters = best_u, centroids = best_v, losses = best_losses[-1]))
}

fuzzy_mixed_k <- function(df, c, m, user = TRUE, e = 1e-2, inits = 10) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data
  x <- mixed_k_df(df, user) # nolint

  if (user == TRUE) {
    # compute gower disimilarity matrix
    d <- as.matrix(distmix(x, method = "ahmad", idnum = 1, # nolint
                           idbin = 2, idcat = 3))**(1 / (m - 1))
  } else {
    # compute gower disimilarity matrix
    d <- as.matrix(distmix(x, method = "ahmad", idnum = 1:2, # nolint
                           idcat = 3:5))**(1 / (m - 1))
  }

  for (init in 1:inits) {
    # initalise v^(0)
    ind <- sample.int(n, c)

    # update u^(1)
    u_old <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_old[is.na(u_old)] <- 1

    # compute loss
    loss <- u_old**m %*% d
    # find minimisers of loss and set to v^(1)
    ind <- which(loss[1, ] == min(loss[1, ]))[1]
    v_new <- x[ind, ]
    for (i in 2:c) {
      # ensure centroids are unique
      inds <- which(loss[i, ] == min(loss[i, -ind]))
      ind <- c(ind, inds[which(!(inds %in% ind))[1]])
      v_new <- rbind(v_new, x[ind[i], ])
    }

    # update u^(2)
    u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
    u_new[is.na(u_new)] <- 1

    # initialise losses
    losses <- c(0, sum(diag(u_new**m %*% d[, ind])))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # compute loss
      loss <- u_new**m %*% d
      # find minimisers of loss and set to v^(l)
      ind <- which(loss[1, ] == min(loss[1, ]))[1]
      v_new <- x[ind, ]
      for (i in 2:c) {
        # ensure centroids are unique
        inds <- which(loss[i, ] == min(loss[i, -ind]))
        ind <- c(ind, inds[which(!(inds %in% ind))[1]])
        v_new <- rbind(v_new, x[ind[i], ])
      }

      # update u^(l+1)
      u_new <- 1 / t(t(d[ind, ]) * colSums(1 / d[ind, ], na.rm = TRUE))
      u_new[is.na(u_new)] <- 1

      # update loss
      losses <- c(losses, sum(diag(u_new**m %*% d[, ind])))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_v <- v_new
      best_losses <- losses
    }
  }

  return(list(clusters = best_u, centroids = best_v, losses = best_losses[-1]))
}

mskmeans_dsim <- function(df, v, c, pr, gamma, split = FALSE, ratio = FALSE) {
  n <- nrow(df)
  p <- ncol(df)

  if (ratio == TRUE) {
    # continuous dissimilarities
    dsim_mat_con <- rowSums(t(t(df[, 1:pr]) - v[1:pr])**2)

    # categorical dissimilarities
    dsim_mat_cat <- gamma * as.matrix(df[, (pr + 1):p]) %*%
      as.matrix(v[(pr + 1):p]) /
      (sqrt(rowSums(as.matrix(df[, (pr + 1):p])**2)) *
         sqrt(rowSums(t(as.matrix(v[(pr + 1):p])**2))))

    return(list(con = dsim_mat_con, cat = as.vector(dsim_mat_cat)))

  } else {
    # continuous dissimilarities
    dsim_mat_con <- matrix(NA, nrow = c, ncol = n)
    for (i in 1:c) {
      dsim_mat_con[i, ] <- rowSums(t(t(as.matrix(df[, 1:pr])) -
                                       as.numeric(v[i, 1:pr]))**2)
    }

    # categorical dissimilarities
    dsim_mat_cat <- gamma * as.matrix(df[, (pr + 1):p]) %*%
      t(as.matrix(v[, (pr + 1):p])) /
      outer(sqrt(rowSums(as.matrix(df[, (pr + 1):p])**2)),
            sqrt(rowSums(as.matrix(v[, (pr + 1):p])**2)))

    if (split == TRUE) {
      return(list(con = dsim_mat_con, cat = t(dsim_mat_cat)))
    } else {
      return(dsim_mat_con + t(dsim_mat_cat))
    }
  }
}

fuzzy_mskmeans <- function(df, c, m, user = TRUE, e = 1e-2,
                           gammas = seq(0.125, 1, 0.125), inits = 10) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)

  # transform data
  x <- mskmeans_df(df, user) # nolint

  # initialise number of continuous and categorical variables
  p <- ncol(x)
  if (user == TRUE) {
    pr <- 1
  } else {
    pr <- 2
  }

  # initialise full data centroids
  cbar <- c(colMeans(as.matrix(x[, 1:pr])),
            colSums(as.matrix(x[, (pr + 1):p])) /
              sqrt(sum(colSums(as.matrix(x[, (pr + 1):p])**2))))

  # initialise best q
  best_q <- Inf

  for (gamma in gammas) {
    best_losses <- c(0, 0)

    for (init in 1:inits) {
      # initialise cluster memberships u^(0)
      u_old <- matrix(runif(n * c), nrow = c)
      u_old <- t(t(u_old) / colSums(u_old, na.rm = TRUE))

      # initialise centroids v^(1) continuous variables
      v_con <- (u_old**m %*% as.matrix(x[, 1:pr])) /
        rowSums(u_old**m, na.rm = TRUE)

      v_cat <- t(t(u_old**m) / sqrt(rowSums(x[, (pr + 1):p]**2))) %*%
        as.matrix(x[, (pr + 1):p])
      v_cat <- v_cat / sqrt(rowSums(v_cat**2))
      v_new <- data.frame(v_con, v_cat)

      # update u^(2)
      d <- mskmeans_dsim(x, v_new, c, pr, gamma)**(1 / (m - 1))
      u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

      # compute within cluster distortion
      losses <- c(0, sum(diag(u_new**m %*% t(d**(m - 1)))))

      count <- 1
      # iterate until convergence
      while (abs(losses[count] - losses[count + 1]) > e) {
        u_old <- u_new

        # update centroids v^(l+1) continuous variables
        v_con <- (u_old**m %*% as.matrix(x[, 1:pr])) /
          rowSums(u_old**m, na.rm = TRUE)

        v_cat <- t(t(u_old**m) / sqrt(rowSums(x[, (pr + 1):p]**2))) %*%
          as.matrix(x[, (pr + 1):p])
        v_cat <- v_cat / sqrt(rowSums(v_cat**2))
        v_new <- data.frame(v_con, v_cat)

        # update u^(l+1)
        d <- mskmeans_dsim(x, v_new, c, pr, gamma)**(1 / (m - 1))
        u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

        # update losses
        losses <- c(losses, sum(diag(u_new**m %*% t(d**(m - 1)))))

        count <- count + 1
        if (count > 100) {
          break
        }
      }

      if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
        best_u <- u_new
        best_v <- v_new
        best_losses <- losses
      }
    }

    # compute within cluster distortion
    d <- mskmeans_dsim(x, v_new, c, pr, gamma, split = TRUE)
    gam_1 <- sum(diag(u_new**m %*% t(d$con)))
    gam_2 <- sum(diag(u_new**m %*% t(d$cat)))

    # compute between cluster distortion
    del_d <- mskmeans_dsim(x, cbar, 1, pr, gamma, ratio = TRUE)

    q <- gam_1 / (sum(del_d$con) - gam_2) *
      gam_1 / (sum(del_d$cat) - gam_2)

    if (q < best_q) {
      best_q <- q
      out <- list(clusters = best_u, centroids = best_v,
                  losses = best_losses[-1], gamma = gamma)
    }
  }

  return(out)
}

fuzzy_famd <- function(df, c, m, user = TRUE, e = 1e-2, p = max(c - 1, 2),
                       inits = 10) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data into lower dimensional space
  x <- FAMD(famd_df(df, user), p, graph = FALSE)$ind$coord # nolint

  for (init in 1:inits) {
    # initialise cluster memberships u^(0)
    u_old <- matrix(runif(n * c), nrow = c)
    u_old <- t(t(u_old) / colSums(u_old, na.rm = TRUE))

    # initialise centroids v^(1)
    v_new <- (u_old**m %*% x) / rowSums(u_old**m, na.rm = TRUE)

    # update u^(1)
    d <- euc_dsim(x, v_new, c)**(2 / (m - 1)) # nolint
    u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

    # initialise losses
    losses <- c(0, sum(diag(u_new**m %*% t(d**(m - 1)))))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # update v^(l+1)
      v_new <- (u_new**m %*% x) / rowSums(u_new**m, na.rm = TRUE)

      # update u^(l+1)
      d <- euc_dsim(x, v_new, c)**(2 / (m - 1)) # nolint
      u_new <- 1 / t(t(d) * colSums(1 / d, na.rm = TRUE))

      # update loss
      losses <- c(losses, sum(diag(u_new**m %*% t(d**(m - 1)))))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_v <- v_new
      best_losses <- losses
    }
  }

  return(list(clusters = best_u, centroids = best_v, losses = best_losses[-1]))
}

fuzzy_mrkmeans <- function(df, c, m, user = TRUE, e = 1e-1, p = max(c - 1, 2),
                           inits = 1) {
  set.seed(01848521)

  # initialise number of data points
  n <- nrow(df)
  best_losses <- c(0, 0)

  # transform data
  x <- as.matrix(mrkmeans_df(df, user)) # nolint

  for (init in 1:inits) {
    # initialise cluster memberships u^(0)
    u_old <- matrix(runif(n * c), nrow = c)
    u_old <- t(t(u_old) / colSums(u_old, na.rm = TRUE))**m

    # initalise projection matrix p^(0)
    p_new <- t(u_old) %*% solve(u_old %*% t(u_old)) %*% u_old

    # initalise loadings matrix b^(0)
    b_new <- eigen(t(x) %*% p_new %*% x, symmetric = TRUE)$vectors[, 1:p]

    # update u^(1)
    u_new <- fuzzy_c_means(x %*% b_new, c, m, e)$clusters**m # nolint

    # compute loss
    losses <- c(0, norm(x - p_new %*% x %*% b_new %*% t(b_new), type = "F"))

    count <- 1
    # iterate until convergence
    while (abs(losses[count] - losses[count + 1]) > e) {
      u_old <- u_new

      # update projection matrix p^(l+1)
      p_new <- t(u_new) %*% solve(u_new %*% t(u_new)) %*% u_new

      # update loadings matrix b^(l+1)
      b_new <- eigen(t(x) %*% p_new %*% x, symmetric = TRUE)$vectors[, 1:p]

      # update u^(l+1)
      u_new <- fuzzy_c_means(x %*% b_new, c, m, e)$clusters**m # nolint

      # update loss
      losses <- c(losses,
                  norm(x - p_new %*% x %*% b_new %*% t(b_new), type = "F"))

      count <- count + 1
      if (count > 100) {
        break
      }
    }

    if ((init == 1) || (tail(losses, 1) < tail(best_losses, 1))) {
      best_u <- u_new
      best_losses <- losses
    }
  }

  # compute final centroids
  v <- (u_new / rowSums(u_new)) %*% x %*% b_new

  return(list(clusters = best_u**(1 / m), centroids = v,
              losses = best_losses[-1]))
}

fuzzy_kamila <- function(df, c, m, user = TRUE, e = 1e-2, inits = 10) {
  set.seed(01848521)

  df <- kamila_df(df, user) # nolint

  if (user == TRUE) {
    out <- new_kamila(df[c(1)], df[c(2:3)], c, inits, e = e, m = m) # nolint
  } else {
    out <- new_kamila(df[c(1:2)], df[c(3:21)], c, inits, e = e, m = m) # nolint
  }

  return(list(clusters = t(out$finalWeights), losses = out$finalLosses,
              mu = out$finalCenters, theta = out$finalProbs))
}