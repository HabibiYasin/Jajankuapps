# Monthly budget and allowance modes

The only editable amount is the monthly budget. New and existing accounts
default to `flat` unless `mode: flexible` is saved.

- Base daily allowance = monthly budget / calendar days in the local month.
- Weekly allowance is the seven-day equivalent (`daily * 7`), not a separate
  calendar-week balance. It is not shortened at month-end.
- Flat allowances remain constant within the month regardless of spending.
- Flexible mode replays completed days in date order. For each day, excess is
  `max(0, tracked expenses - that day's allowance)`. Subtract
  `excess / remaining calendar days` from the next day's allowance, clamped to
  zero. Unused daily allowance is not redistributed.
- Today's transactions never reduce today's limit. Only expenses in selected
  categories count; income and other categories are excluded. Edits, deletions,
  category changes and budget changes recalculate the result from history.
- Each new month starts from that month's base daily allowance. No debt is
  carried between months. Calculations retain fractional rupiah until display.

Example in a 30-day month: monthly Rp1,500,000 gives daily Rp50,000. Spending
Rp100,000 on day 10 leaves 20 days; day 11's allowance becomes Rp47,500, and
its weekly equivalent becomes Rp332,500.

`BudgetLimits.dailyFor` is used by the app, including the historical limit for
the Yesterday card. Android's `BudgetAllowance.daily` mirrors it for background
notifications across midnight and month changes. The native bridge receives
monthly budget, mode, and daily totals for selected categories.

The stored `daily` and `weekly` fields remain positive base-allowance snapshots
for compatibility with older clients. They are not runtime sources of truth.
`mode` is persisted in both guest preferences and the account budget document.

Before releasing this app version, deploy the updated `firestore.rules` to the
intended Firebase environment. Previous rules reject writes containing `mode`.
The rules still accept old clients without that field, and restrict values to
`flat` or `flexible`.
