# Security model

## Trust boundaries

The Flutter client is untrusted. It may use the Supabase anon or publishable key, but it must never contain a service-role key, database password, access token, or other privileged credential. The service-role key is server-side operational tooling only and bypasses Row-Level Security (RLS).

Authenticated clients access application tables through PostgreSQL grants and RLS policies. Guest participants are database records only; a guest record has no `auth.users` account and grants no unauthenticated access.

## Authentication assumptions

Supabase Auth provides `auth.users` and makes the current authenticated UUID available through `auth.uid()`. A trusted trigger creates a minimal `profiles` record with the safe fallback name `Member`; it does not trust arbitrary user metadata. Client-visible profiles are private to their owner, while group-member display-name snapshots supply group-facing names.

## Row-Level Security strategy

RLS is enabled on every client-accessible application table.

| Table | Permitted authenticated access |
| --- | --- |
| `profiles` | Read and update only the caller's profile display name. |
| `groups` | Active members read; active users create their own groups; owners and admins update settings. |
| `group_members` | Active members read their group; owners/admins add or deactivate ordinary members. |
| `expenses` | Active members read; active members create drafts; creators and administrators manage drafts. |
| `expense_payers` / `expense_splits` | Read through the parent expense; modify only while managing its draft. |
| `settlements` | Active members read and create; creators and administrators may void their records. |
| `expense_events` | Active members read through the parent expense only. |

Database grants are deliberately narrower than table-level RLS: callers cannot update immutable IDs, creators, roles, group links, or audit events even if an application bug attempts it.

## Owners, administrators, and guests

An owner or administrator is an active `group_members` row associated with the authenticated caller. Owners can promote only active, registered members through the guarded role function; guests may remain ordinary members but cannot become administrators. Ownership transfer likewise requires a different active, registered member of the same group and promotes that successor before demoting the prior owner. Direct client writes cannot assign `owner` or `admin`, and the last active owner cannot be removed or demoted.

Guests have no authentication identity. They can appear as payers, split participants, and settlement participants only through writes performed by authorised authenticated group members. They cannot query the API or grant themselves access.

## Trusted database logic

The `app_private` schema contains RLS helper and trigger functions. `SECURITY DEFINER` is used only for helpers that must bypass client grants or RLS, such as membership checks, trusted audit insertion, and guarded transactions; timestamp and immutability-only triggers remain ordinary invoker functions. All functions set `search_path` to `pg_catalog`, use fully qualified application objects where they access application data, and do not use dynamic SQL. The schema is not available to ordinary client API calls. Function execution is granted only where RLS policy evaluation requires it.

The public `finalize_expense`, `void_expense`, membership-role, and ownership-transfer functions perform explicit caller and state checks before acting. They are the only ordinary-client path for posting, voiding, role elevation, or ownership changes.

## Audit history

Expense, payer, and split changes create `expense_events` through trusted triggers. Normal clients receive only `SELECT` on this table; they have no insert, update, or delete grants or policies. The event rows preserve enough financial context to understand changes without storing credentials or unnecessary authentication data.

## Threats addressed

- Cross-group reads are denied by active-membership checks.
- Cross-group payers, splits, and settlement participants are rejected by composite foreign keys and active-member trigger validation.
- Self-promotion and self-joining unrelated groups are denied by grants, RLS, and guarded role functions.
- Partial expense writes remain drafts and cannot become posted until totals match.
- Posted expenses cannot have their payer or split rows changed.
- Guest records do not provide anonymous API access.
- Audit events cannot be fabricated or edited by normal clients.

## Risks intentionally postponed

This foundation does not provide invitation acceptance, account-deletion workflows, fraud detection, payment verification, reconciliation, multiple-currency rules, offline conflict resolution, rate limiting, or production notification controls. These require product decisions, operational processes, and additional testing before release.
