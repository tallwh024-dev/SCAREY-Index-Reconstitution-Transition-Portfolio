# SCAREY Index Reconstitution Transition Portfolio
# Author: Jackson Wang

library(readxl)
library(dplyr)
library(stringr)
library(tidyr)
library(quantmod)
library(PerformanceAnalytics)
library(CVXR)

# ------------------------------------------------------------
# 1. Load universe and build current / future benchmarks
# ------------------------------------------------------------

raw <- read_excel("NARIET_Index_Constituents.xlsx")

allowed_letters <- c("M", "N", "O", "P", "R", "S")
current_letters <- c("M", "N", "O", "P")
future_letters <- c("P", "R", "S")

universe <- raw |>
  transmute(
    Name = as.character(Name),
    Symbol = as.character(Symbol),
    MktCap = suppressWarnings(as.numeric(`Market Capitalization`))
  ) |>
  filter(!is.na(Name), Name != "", !is.na(Symbol), Symbol != "") |>
  mutate(FirstLetter = str_to_upper(str_sub(str_trim(Name), 1, 1))) |>
  filter(FirstLetter %in% allowed_letters) |>
  filter(!is.na(MktCap), is.finite(MktCap), MktCap > 0) |>
  distinct(Symbol, .keep_all = TRUE) |>
  arrange(FirstLetter, Symbol)

benchmarks <- universe |>
  mutate(
    in_cur = FirstLetter %in% current_letters,
    in_fut = FirstLetter %in% future_letters,
    w_cur = if_else(in_cur, MktCap / sum(MktCap[in_cur]), 0),
    w_fut = if_else(in_fut, MktCap / sum(MktCap[in_fut]), 0)
  ) |>
  select(Symbol, Name, FirstLetter, MktCap, w_cur, w_fut)

mix <- tibble::tribble(
  ~weeks_before, ~alpha_cur,
  4, 1.0,
  3, 0.8,
  2, 0.6,
  1, 0.3,
  0, 0.0
) |>
  mutate(alpha_fut = 1 - alpha_cur)

# ------------------------------------------------------------
# 2. Download weekly prices and estimate return inputs
# ------------------------------------------------------------

start_weekly <- as.Date("2023-12-31")
end_weekly <- as.Date("2025-12-07")
Symbols <- sort(unique(universe$Symbol))

get_weekly_adj <- function(Symbol, from, to) {
  x <- suppressWarnings(getSymbols(Symbol, src = "yahoo", from = from, to = to, auto.assign = FALSE))
  adj <- Ad(x)
  wk <- to.weekly(adj, indexAt = "endof", OHLC = FALSE)
  colnames(wk) <- Symbol
  wk
}

weekly_prices_list <- lapply(Symbols, function(tk) {
  tryCatch(get_weekly_adj(tk, start_weekly, end_weekly), error = function(e) NULL)
})
names(weekly_prices_list) <- Symbols
weekly_prices_list <- weekly_prices_list[!vapply(weekly_prices_list, is.null, logical(1))]

weekly_prices <- do.call(merge, c(weekly_prices_list, all = FALSE))
weekly_ret_xts <- Return.calculate(weekly_prices, method = "discrete")[-1, ]
weekly_ret_xts <- weekly_ret_xts[complete.cases(weekly_ret_xts), ]

R <- coredata(weekly_ret_xts)
mu_vec <- colMeans(R)
Sigma_mat <- cov(R)

bench_ok <- benchmarks |>
  filter(Symbol %in% colnames(weekly_ret_xts)) |>
  arrange(match(Symbol, colnames(weekly_ret_xts)))

b_cur <- bench_ok$w_cur
b_fut <- bench_ok$w_fut

b_by_time <- lapply(seq_len(nrow(mix)), function(i) {
  a <- mix$alpha_cur[i]
  a * b_cur + (1 - a) * b_fut
})
names(b_by_time) <- paste0("b_", mix$weeks_before)

# ------------------------------------------------------------
# 3. Solve transition optimization
# ------------------------------------------------------------

solve_transition_qp <- function(mu, Sigma, b, alpha_min = 0.0002) {
  n <- length(mu)
  w <- Variable(n)
  objective <- quad_form(w - b, Sigma)
  constraints <- list(sum(w) == 1, w >= 0, t(mu) %*% (w - b) >= alpha_min)
  problem <- Problem(Minimize(objective), constraints)
  result <- solve(problem, solver = "OSQP")
  w_opt <- as.numeric(result$getValue(w))
  names(w_opt) <- colnames(weekly_ret_xts)
  list(w = w_opt, status = result$status, objective = result$value)
}

sols <- lapply(names(b_by_time), function(nm) {
  solve_transition_qp(mu_vec, Sigma_mat, b_by_time[[nm]], alpha_min = 0.0002)
})
names(sols) <- names(b_by_time)

weights_tbl <- tibble(
  Symbol = colnames(weekly_ret_xts),
  FirstLetter = bench_ok$FirstLetter
) |>
  bind_cols(as_tibble(do.call(cbind, lapply(sols, function(s) s$w))) |> setNames(names(b_by_time))) |>
  arrange(FirstLetter, Symbol)

# ------------------------------------------------------------
# 4. Expected tracking error and expected excess return
# ------------------------------------------------------------

te_expected <- function(w, b, Sigma) sqrt(as.numeric(t(w - b) %*% Sigma %*% (w - b)))
er_expected <- function(w, b, mu) as.numeric(sum((w - b) * mu))

metrics_tbl <- lapply(names(b_by_time), function(nm) {
  w <- sols[[nm]]$w
  tibble(
    decision_point = nm,
    current_tracking_error = te_expected(w, b_cur, Sigma_mat),
    future_tracking_error = te_expected(w, b_fut, Sigma_mat),
    Current_Expected_Return = er_expected(w, b_cur, mu_vec),
    Future_Expected_Return = er_expected(w, b_fut, mu_vec),
    Fut_Cur_Expected_Return = er_expected(w, b_by_time[[nm]], mu_vec)
  )
}) |>
  bind_rows() |>
  mutate(decision_point = factor(decision_point, levels = c("b_4", "b_3", "b_2", "b_1", "b_0"))) |>
  arrange(decision_point)

print(weights_tbl)
print(metrics_tbl, width = Inf)

# ------------------------------------------------------------
# 5. Realized daily active return analysis
# ------------------------------------------------------------

start_realized <- as.Date("2025-12-08")
end_realized <- as.Date("2026-01-02")

get_daily_adj <- function(Symbol, from, to) {
  x <- suppressWarnings(getSymbols(Symbol, src = "yahoo", from = from, to = to, auto.assign = FALSE))
  adj <- Ad(x)
  colnames(adj) <- Symbol
  adj
}

daily_prices_list <- lapply(colnames(weekly_ret_xts), function(tk) {
  tryCatch(get_daily_adj(tk, start_realized, end_realized), error = function(e) NULL)
})
names(daily_prices_list) <- colnames(weekly_ret_xts)
daily_prices_list <- daily_prices_list[!vapply(daily_prices_list, is.null, logical(1))]

daily_prices <- do.call(merge, c(daily_prices_list, all = FALSE))
daily_ret_xts <- Return.calculate(daily_prices, method = "discrete")[-1, ]
daily_ret_xts <- daily_ret_xts[complete.cases(daily_ret_xts), ]

dates <- as.Date(index(daily_ret_xts))
day_offset <- as.integer(dates - start_realized)
weeks_before_bucket <- pmax(0L, 4L - floor(day_offset / 7))
alpha_map <- c(`4` = 1.0, `3` = 0.8, `2` = 0.6, `1` = 0.3, `0` = 0.0)

b_blended_for_bucket <- function(k) {
  a <- as.numeric(alpha_map[as.character(k)])
  a * b_cur + (1 - a) * b_fut
}

w_by_time <- lapply(c("b_4", "b_3", "b_2", "b_1", "b_0"), function(nm) sols[[nm]]$w)
names(w_by_time) <- c("b_4", "b_3", "b_2", "b_1", "b_0")

compute_active_series <- function(daily_ret_xts, weeks_bucket, w_by_time, benchmark_fun) {
  Rm <- coredata(daily_ret_xts)
  active <- numeric(nrow(Rm))
  for (i in seq_len(nrow(Rm))) {
    k <- weeks_bucket[i]
    w <- w_by_time[[paste0("b_", k)]]
    b <- benchmark_fun(k)
    active[i] <- sum((w - b) * Rm[i, ])
  }
  xts::xts(active, order.by = index(daily_ret_xts))
}

active_evolving <- compute_active_series(daily_ret_xts, weeks_before_bucket, w_by_time, b_blended_for_bucket)
active_jump <- compute_active_series(daily_ret_xts, weeks_before_bucket, w_by_time, function(k) b_cur)

results_step7 <- tibble(
  method = c("Actual benchmark", "Jump benchmark"),
  realized_daily_avg_excess_return = c(mean(active_evolving), mean(active_jump)),
  realized_tracking_error_daily = c(sd(active_evolving), sd(active_jump))
)

print(results_step7)
