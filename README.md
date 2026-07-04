# SCAREY Index Reconstitution Transition Portfolio

This repository contains a CFRM 503 portfolio optimization project for managing a REIT index reconstitution event.

The project builds a four-week transition plan for a portfolio benchmarked to the SCAREY Index. The index currently holds REITs whose names begin with M, N, O, or P, and after reconstitution it will hold REITs whose names begin with P, R, or S.

## Project objective

The goal is to determine portfolio weights across five decision points before reconstitution:

- `b_4`: four weeks before reconstitution
- `b_3`: three weeks before reconstitution
- `b_2`: two weeks before reconstitution
- `b_1`: one week before reconstitution
- `b_0`: reconstitution point

At each decision point, the portfolio must:

- allocate only to eligible M, N, O, P, R, and S REITs
- have non-negative weights
- have weights that sum to 1
- generate at least 2 basis points of expected weekly excess return
- minimize tracking error relative to the relative-importance weighted benchmark

## Benchmark transition design

The benchmark gradually transitions from the current SCAREY Index to the future SCAREY Index.

| Decision Point | Current Index Weight | Future Index Weight |
|---|---:|---:|
| `b_4` | 100% | 0% |
| `b_3` | 80% | 20% |
| `b_2` | 60% | 40% |
| `b_1` | 30% | 70% |
| `b_0` | 0% | 100% |

## Methods

The project uses:

- Market-cap benchmark weighting
- Yahoo Finance adjusted close prices
- Weekly simple returns
- Estimated expected returns and covariance matrix
- Quadratic programming with `CVXR`
- Tracking error minimization
- Expected excess return constraint
- Realized active return and tracking error analysis

## Optimization formulation

For each decision point, the portfolio solves:

```text
minimize     (w - b)' Sigma (w - b)
subject to   sum(w) = 1
             w >= 0
             mu' (w - b) >= 0.0002
```

where:

- `w` = portfolio weights
- `b` = blended benchmark weights for that decision point
- `Sigma` = weekly covariance matrix of REIT returns
- `mu` = weekly expected return vector
- `0.0002` = 2 basis points expected excess return requirement

## Key findings

- At `b_4`, the optimized portfolio is closely aligned with the current M/N/O/P benchmark.
- As the reconstitution date approaches, weights shift toward the future P/R/S benchmark.
- Tracking error relative to the current benchmark rises through time.
- Tracking error relative to the future benchmark falls toward zero by `b_0`.
- Expected excess return remains close to the required 2 basis points per week.
- Realized excess returns over the transition window were slightly negative, but the evolving benchmark approach controlled tracking error relative to the benchmark transition path.

## Repository structure

```text
SCAREY-Index-Reconstitution-Transition-Portfolio/
├── README.md
├── scripts/
│   └── scarey_transition_optimization.R
├── source/
│   └── project_report.Rmd
├── reports/
│   └── project_summary.md
├── outputs/
│   ├── expected_metrics.csv
│   └── realized_transition_results.csv
├── data/
│   └── data_notes.md
└── requirements.txt
```

## How to run

1. Install the R packages listed in `requirements.txt`.
2. Place `NARIET_Index_Constituents.xlsx` in the project root or `data/` folder.
3. Run:

```r
source("scripts/scarey_transition_optimization.R")
```

The script uses Yahoo Finance through `quantmod::getSymbols()` to download adjusted close prices for eligible REIT tickers.

## Tools used

- R
- readxl
- dplyr / tidyr / stringr
- quantmod
- PerformanceAnalytics
- CVXR
- OSQP solver

## Author

Jackson Wang  
M.S. Computational Finance and Risk Management  
University of Washington
