# World Cup Breakout Players as Private-Equity Assets

A MATLAB analytics project that values footballers who broke out at a World Cup as if they were private-equity investments: bought for a fee, held while paying wages and generating value, then sold at a market value. It runs a full quant pipeline (DCF valuation, scenario analysis, Monte Carlo simulation, a risk score, and portfolio optimisation) over ten players from the 2014, 2018 and 2022 tournaments.

> This is a learning project. The figures are illustrative and rest on a mix of fetched data, estimated data, and explicit modelling assumptions. It is a demonstration of method, not investment advice or a precise valuation.

## The question

When a player lights up a World Cup, clubs pay a premium to sign him. Is that actually a good investment, or are they buying one hot month? This project turns that into a money question.

## Headline finding

Under the model, **cheap breakouts with sustainable underlying numbers beat expensive marquee signings on a risk-adjusted basis.** The two biggest fees in the sample (James Rodriguez ~EUR 80m, Angel Di Maria ~EUR 75.6m) post negative NPV in every scenario, while bargains like Sofyan Amrabat (EUR 10m) and Denis Cheryshev (EUR 6m) clear the hurdle comfortably.

The sharpest signal is **xG overperformance**: a player who scored far above his expected goals (Gakpo +2.44, Cheryshev +2.89) was finishing unsustainably and gets penalised by the risk layer. A volume-and-defence breakout (Amrabat, who slightly *under*-performed his xG) is treated as the most durable asset and becomes the largest holding in the optimal portfolio.

## How it works

| Stage | Script | What it does |
|---|---|---|
| Load | `load_data.m` | Reads and joins the two datasets into one table |
| Valuation | `slice1_npv_irr.m` | NPV + IRR for a single player (worked example) |
| Ranking | `slice2_all_players.m` | NPV + IRR across all players, ranked |
| Scenarios | `slice3_scenarios.m` | Downside / base / upside re-valuation |
| Simulation | `slice4_montecarlo.m` | 10,000 random futures: P(loss), Value-at-Risk, IRR distribution |
| Charts | `slice4b_histgrid.m` | NPV distribution histograms for all players (2x5 grid) |
| Risk score | `slice5_riskscore.m` | Per-player 0-100 risk from xG overperformance, age, fee, minutes |
| Portfolio | `slice6_portfolio.m` | Efficient frontier: the transfer window as a fund |

## Data

The interesting technical bit: the advanced metrics for the 2018 and 2022 players were **computed directly from StatsBomb's open event data**, not scraped from a stats site. `statsbomb_wc_pull.py` downloads the raw events and derives real xG, xA, shots, key passes, pass completion and defensive actions per player (penalty shootouts excluded).

Every input is tagged into one of three honesty categories:

- **Fetched & cited** - performance metrics from StatsBomb open data
- **Estimated & flagged** - transfer fees and market values (Transfermarkt), wages (Capology)
- **Modelled assumption** - revenue, discount rate, hold period, risk weights

The 2014 World Cup is not in the open dataset, so those six players carry basic goals/assists only. Wages and bonuses are estimates; market values are crowd-sourced estimates. Sources and direct links are listed in `data_sources.md`.

## Repository contents

```
data/
  wc_breakout_players_master_v2.csv   financial spine (fees, market values, wages)
  wc_performance_stats.csv            World Cup performance (StatsBomb-derived)
  data_sources.md                     source links + confidence notes
src/
  load_data.m
  slice1_npv_irr.m ... slice6_portfolio.m
  statsbomb_wc_pull.py                reusable StatsBomb event puller
reports/
  WC_Breakout_Technical_Report.docx   formal write-up
  WC_Breakout_Plain_English.docx      plain-language explainer
```

## Running it

1. Open MATLAB and set the Current Folder to the `src` folder (with the CSVs alongside, or adjust paths).
2. Run `load_data.m` to build the joined `players` table.
3. Run any `slice*.m` with the green Run button (each runs top to bottom; no extra toolboxes required - IRR is solved with base MATLAB's `fzero`).

To regenerate the performance data: `python3 statsbomb_wc_pull.py` (needs internet; uses StatsBomb open data on GitHub).

## Limitations

- The EUR 8m/yr revenue figure is the single most load-bearing assumption; results are sensitive to it.
- Portfolio returns are reported over the four-year hold, not annualised.
- The 2014 cohort lacks event-level data, so their risk scores use a neutral overperformance assumption.
- Portfolio weights treat players as fractionally divisible (read them as budget shares, not literal stakes).

## Credits

Performance data: [StatsBomb Open Data](https://github.com/statsbomb/open-data). Financial estimates: Transfermarkt, Capology. Built in MATLAB as a personal project applying private-equity valuation methods to football data.
