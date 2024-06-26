find_knn <- function(ui, sim, k, userid, filmid, user = TRUE) {
  if (user == TRUE) {
    # indices of users who have rated the film
    ind <- which(ui[, filmid] > 0)
    if (length(ind) == 0) {
      return(userid)
    }
    # nearest neighbours
    neighbours <- ind[order(-sim[userid, ][ind])[1:k]]
  } else {
    # indices of films the user has rated
    ind <- which(ui[userid, ] > 0)
    if (length(ind) == 0) {
      return(filmid)
    }
    # nearest neighbours
    neighbours <- ind[order(-sim[filmid, ][ind])[1:k]]
  }

  # omit NA when not enough neighbours found
  return(na.omit(neighbours))
}

average <- function(ui, sim, k, userid, filmid, user = TRUE) {
  # find nearest neighbours
  neighbours <- find_knn(ui, sim, k, userid, filmid, user)

  if (user == TRUE) {
    ind <- which(sim[userid, neighbours] > 0)
    # compute rating prediction
    pred <- mean(ui[neighbours[ind], filmid])
  } else {
    ind <- which(sim[filmid, neighbours] > 0)
    # compute rating prediction
    pred <- mean(ui[userid, neighbours[ind]])
  }

  return(pred)
}

weighted_sum <- function(ui, sim, k, userid, filmid, user = TRUE) {
  # find nearest neighbours
  neighbours <- find_knn(ui, sim, k, userid, filmid, user)

  if (user == TRUE) {
    # compute rating prediction
    num <- sim[neighbours, userid] %*% ui[neighbours, filmid]
    denom <- sum(abs(sim[neighbours, userid])) + 1e-9
  } else {
    # compute rating prediction
    num <- sim[neighbours, filmid] %*% ui[userid, neighbours]
    denom <- sum(abs(sim[neighbours, filmid])) + 1e-9
  }

  return(num / denom)
}

mean_centered <- function(ui, sim, k, userid, filmid, user = TRUE) {
  # find nearest neighbours
  neighbours <- find_knn(ui, sim, k, userid, filmid, user)

  if (user == TRUE) {
    # compute target user rating mean
    mu_u <- mean(ui[userid, ], na.rm = TRUE)

    # compute neighbour users rating mean
    if (length(neighbours) < 2) {
      mu_v <- mean(ui[neighbours, ], na.rm = TRUE)
    } else {
      mu_v <- rowMeans(ui[neighbours, ], na.rm = TRUE)
    }

    # compute rating prediction
    num <- sim[userid, neighbours] %*% (ui[neighbours, filmid] - mu_v)
    denom <- sum(abs(sim[userid, neighbours])) + 1e-9

    return(mu_u + num / denom)

  } else {
    # compute target film rating mean
    mu_i <- mean(ui[, filmid], na.rm = TRUE)

    # compute neighbour users rating mean
    if (length(neighbours) < 2) {
      mu_j <- mean(ui[, neighbours], na.rm = TRUE)
    } else {
      mu_j <- colMeans(ui[, neighbours], na.rm = TRUE)
    }

    # compute rating prediction
    num <- sim[filmid, neighbours] %*% (ui[userid, neighbours] - mu_j)
    denom <- sum(abs(sim[filmid, neighbours])) + 1e-9

    return(mu_i + num / denom)
  }
}

z_score <- function(ui, sim, k, userid, filmid, user = TRUE) {
  # find nearest neighbours
  neighbours <- find_knn(ui, sim, k, userid, filmid, user)

  if (user == TRUE) {
    # compute target user rating mean and standard deviation
    mu_u <- mean(ui[userid, ], na.rm = TRUE)
    sig_u <- sd(ui[userid, ], na.rm = TRUE)

    # compute neighbour users rating mean and standard deviation
    if (length(neighbours) < 2) {
      mu_v <- mean(ui[neighbours, ], na.rm = TRUE)
      sig_v <- sd(ui[neighbours, ], na.rm = TRUE)
    } else {
      mu_v <- rowMeans(ui[neighbours, ], na.rm = TRUE)
      sig_v <- apply(ui[neighbours, ], 1, sd, na.rm = TRUE)
    }

    # compute rating prediction
    num <- sim[neighbours, userid] %*% ((ui[neighbours, filmid] - mu_v) / sig_v)
    denom <- sum(abs(sim[neighbours, userid])) + 1e-9

    return(mu_u + sig_u * num / denom)
  } else {
    # compute target film rating mean and standard deviation
    mu_i <- mean(ui[, filmid], na.rm = TRUE)
    sig_i <- sd(ui[, filmid], na.rm = TRUE)

    # compute neighbour films rating mean and standard deviation
    if (length(neighbours) < 2) {
      mu_j <- mean(ui[, neighbours], na.rm = TRUE)
      sig_j <- sd(ui[, neighbours], na.rm = TRUE)
    } else {
      mu_j <- colMeans(ui[, neighbours], na.rm = TRUE)
      sig_j <- apply(ui[, neighbours], 2, sd, na.rm = TRUE)
    }

    # compute rating prediction
    num <- sim[neighbours, filmid] %*% ((ui[userid, neighbours] - mu_j) / sig_j)
    denom <- sum(abs(sim[neighbours, filmid])) + 1e-9

    return(mu_i + sig_i * num / denom)
  }
}

discrete <- function(ui, sim, k, userid, filmid, user = TRUE) {
  # find nearest neighbours
  neighbours <- find_knn(ui, sim, k, userid, filmid, user)

  if (user == TRUE) {
    ind <- which(sim[userid, neighbours] > 0)
    # count ratings of neighbours
    rating_count <- table(ui[neighbours[ind], filmid])
  } else {
    ind <- which(sim[userid, neighbours] > 0)
    # count ratings of neighbours
    rating_count <- table(ui[userid, neighbours[ind]])
  }

  # find most common rating
  top_count <- max(rating_count)
  # compute rating prediction
  top_ratings <- as.numeric(names(rating_count[rating_count == top_count]))

  return(mean(top_ratings))
}