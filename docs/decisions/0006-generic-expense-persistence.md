# 0006: Persist flexible expenses as final exact allocations

- Status: Accepted
- Date: 2026-08-01

## Context

Equal, exact, percentage, and share input methods are presentation choices, but balances need one durable and auditable representation. Allowing a client to submit an unverified split method, decimal percentages, or intermediate draft rows would weaken financial invariants.

## Decision

Use `public.create_expense` as one guarded atomic operation accepting only final payer and split amounts in integer minor units. The client derives any chosen input method into those allocations, previews the result, and submits it once. The database independently validates membership, positivity or non-negativity, uniqueness, and exact totals before posting.

## Alternatives considered

- Persisting the UI split method and recalculating later was rejected because calculations could change and would make history ambiguous.
- Client-side enforcement alone was rejected because clients are untrusted.
- Separate database functions per split method were rejected because they duplicate the same financial invariant.

## Consequences

The persisted source of truth is always exact member allocation. UI split methods can evolve without a schema change, while audit events and balances remain stable. A valid split can include a zero-minor-unit participant when a small amount requires it; payer allocations remain positive.

## Follow-up actions

Add additional input methods only when they can be deterministically reduced to exact allocations and covered by integer-arithmetic tests.
