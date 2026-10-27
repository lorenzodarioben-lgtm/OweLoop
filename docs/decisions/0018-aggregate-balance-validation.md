# ADR 0018: aggregate validation without weaker financial checks

Accepted 2026-10-28. Implemented by forward migration 29.

`get_group_balances` repeatedly scanned each posted expense's allocations and
computed canonical member balances twice. Large local fixtures justified a
smaller query: materialize posted expenses, aggregate payer/split totals once,
then materialize canonical member rows once with a numeric zero-sum window.

Keep the same signature, stable snapshot, caller/profile/current-membership
checks, fixed search path and authenticated-only execute grant. Validate every
posted expense against both totals, validate settlements, retain individual
checked bigint conversions and removed member identities, and fail the entire
RPC if any returned member aggregate makes the group inconsistent. Returning
rows from PL/pgSQL does not expose a partial successful response on exception.

Seven corruption/removed-identity assertions supplement the original suite.
Fresh schema and both populated upgrades pass. Two independent local benchmark
runs require exact ordered equality with a temporary copy of the released
function. Their three alternating warm samples show lower medians in all four
fixtures, with meaningful variance. See [methodology and samples](../performance.md).
No cold-cache, native-memory, production capacity or supported-size claim follows.

Further optimization must preserve every invariant and use representative
comparisons. Whole snapshot/export materialization remains a separate limitation.
