# Data quality & exclusion rules

## 1. Profiling rules (raw source, 1,067,371 rows)

A row can break several rules, so these counts overlap.

| Rule | Rows affected | % of source |
|---|---:|---:|
| Missing customer ID | 243,007 | 22.8% |
| Exact duplicates | 34,335 | 3.2% |
| Negative quantities | 22,950 | 2.2% |
| Cancelled invoices (invoice starts with `C`) | 19,494 | 1.8% |
| Zero or negative prices | 6,202 | 0.6% |
| Non-product stock code (postage, fees, adjustments…) | 6,093 | 0.6% |
| Missing description | 4,382 | 0.4% |

Also found: 99% of prices used a comma decimal separator (unreadable as numbers until converted).

## 2. Exclusion rules (source → target)

**Each excluded row is assigned to its first matching rule, in the order below.** This is why counts differ from the profiling table (e.g. 226,637 vs 243,007 for missing customer ID).

| # | Reason | Rows excluded | Revenue excluded (£) |
|---|---|---:|---:|
| 1 | Missing customer ID | 226,637 | 2,574,124.18 |
| 2 | Non-product code | 4,681 | 833,568.28 |
| 3 | Exact duplicates | 34,335 | 431,716.87 |
| 4 | Non-positive quantity | 3,393 | 0.00 |
| 5 | Non-positive price | 2,644 | −158,676.14 |
| 6 | Cancelled invoice | 19,104 | −1,462,050.61 |
| | **Total** | **290,794** | **2,218,682.58** |

Negative excluded revenue means the target is *higher* than it would be if those rows were kept: removing credit notes and negative prices without removing the original orders inflates target revenue.

## 3. Reconciliation

| | Rows | Revenue |
|---|---:|---:|
| Source | 1,067,371 | £19.29M |
| − Excluded | 290,794 | £2.22M |
| = Target | 776,577 | £17.07M |
| Unexplained | 0 | £0.00 |
