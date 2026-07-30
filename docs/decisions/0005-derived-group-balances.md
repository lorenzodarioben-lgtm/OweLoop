# 0005: Derive group balances from financial records

- Status: Accepted
- Date: 2026-07-31

## Context

OweLoop needs balances that members can inspect and trust. Expenses, payer contributions, split obligations, settlement records, voids, and durable member identities already form the financial record. A mutable stored balance would duplicate that record and could drift when an expense or settlement changes.

## Decision

Use one read-only database RPC, `public.get_group_balances(uuid)`, as the canonical balance source. It derives integer minor-unit nets from posted, non-voided payer and split rows, plus non-voided settlement adjustments. It includes active zero-balance members and historical removed members with financial history, validates contributing expense totals and the group-wide zero sum, and fails closed on inconsistency.

The RPC derives the caller from `auth.uid()`, requires an onboarded active membership, sets a fixed search path, and is executable only by `authenticated`. The Flutter feature maps its values into the existing exact-money type and does not calculate balances in widgets.

## Consequences

- There is no mutable balance table, cache, trigger-maintained column, or reconciliation job to keep in sync.
- A balance read scales with the group's financial history; indexes on the existing expense, payer, split, and settlement access paths support the intended Version 0.1 usage.
- Future settlement entry and recommendations reuse the same formula rather than creating a second source of truth.
