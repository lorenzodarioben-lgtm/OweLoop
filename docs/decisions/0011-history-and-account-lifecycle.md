# 0011: Cursor history, complete snapshots and retained shared records

- Status: Accepted
- Date: 2026-10-24

Expense and settlement history use a descending `(occurred_at/settled_at,
created_at, id)` cursor with a bounded page size and one lookahead row. The cursor
contains the final displayed row, not the lookahead. Newer concurrent inserts
appear on refresh; stable older records are neither shifted nor duplicated by
offset changes. Search, dates, participant and void-status filtering run before
expense pagination. Financial history screens render lazily; group summaries
show only five recent records. Exports walk every page.

Balances, current groups, members and per-expense safe activity use scalar JSON
snapshot RPCs so PostgREST row limits cannot silently truncate their result.
Canonical balance authorization and zero-sum validation remain unchanged, and
one snapshot observes one database statement. Large snapshots still consume
memory; future very large group work should measure this explicitly.

Account deletion uses the supported Auth Admin API from a trusted function,
never a privileged mobile credential or direct client deletion of Auth rows.
PostgreSQL enforces ownership and zero-balance prerequisites and de-identifies
durable memberships while retaining shared financial history. See
`docs/account-lifecycle.md` for the exact policy and unperformed deployment gates.
