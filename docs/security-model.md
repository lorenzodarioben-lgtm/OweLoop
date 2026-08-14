# Security model

## Trust boundaries

The Flutter client is untrusted. It may use the Supabase anon or publishable key, but it must never contain a service-role key, database password, access token, or other privileged credential. The service-role key is server-side operational tooling only and bypasses Row-Level Security (RLS).

Authenticated clients access application tables through PostgreSQL grants and RLS policies. Guest participants are database records only; a guest record has no `auth.users` account and grants no unauthenticated access.

## Authentication assumptions

Supabase Auth provides `auth.users` and makes the current authenticated UUID available through `auth.uid()`. A trusted trigger creates a minimal `profiles` record with the safe fallback name `Member`; it does not trust arbitrary user metadata. `onboarding_completed_at` is initially null, so the fallback does not imply that setup was completed. Client-visible profiles are private to their owner, while group-member display-name snapshots supply group-facing names.

## Row-Level Security strategy

RLS is enabled on every client-accessible application table.

| Table | Permitted authenticated access |
| --- | --- |
| `profiles` | Read only the caller's profile. Completion occurs only through the guarded `public.complete_profile(text)` function. |
| `groups` | Active members read; authenticated users with completed onboarding create their own normalized groups; guarded owner/admin rename and archive operations update settings. |
| `group_members` | Active members read their group; guarded guest creation and removal preserve durable history. |
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

The public `complete_profile`, `add_guest_member`, `create_equal_expense`, `create_expense`, `finalize_expense`, `void_expense`, settlement, balance, activity, membership-role, ownership-transfer, and group-administration functions perform explicit caller and state checks before acting. `complete_profile` is `SECURITY DEFINER` because direct profile updates are not granted to clients; it uses the fixed `pg_catalog` search path, fully qualified application objects, no dynamic SQL, and is executable only by `authenticated`. It trims and validates the name, updates only the caller's profile, and records completion atomically.

`app_private.prepare_group_creation()` runs before every group insert. It requires an authenticated, onboarded caller, overwrites `created_by` with `auth.uid()`, validates the normalized input, and lets the existing trusted owner trigger establish the single owner membership. Direct `group_members` inserts are not granted to authenticated clients. `add_guest_member` has the same fixed search path and fully qualified access pattern; it takes no role or auth-user input, requires an active owner or administrator, rejects archived groups, and can create only an account-free ordinary membership. These are the only ordinary-client paths for profile completion, guest creation, posting, voiding, role elevation, or ownership changes.

`create_equal_expense` accepts only the target group, normalized expense fields, one member ID for the payer, and participant member IDs. `create_expense` accepts the final normalized payer and split allocations for flexible entry. Neither accepts a creator, role, group currency, or posted status. Both require an authenticated, onboarded active registered member; lock and reject archived groups; verify all participant identities are active in the target group; write exact integer totals; and post through the existing guarded finalization path. `create_expense` rejects duplicate, foreign, removed, negative, zero-payer, and unequal-total payloads. Both are executable only by `authenticated`, use the fixed `pg_catalog` search path with fully qualified application objects, and have no dynamic SQL. RLS continues to prevent unrelated users from reading the expense, its payers, splits, or events.

`record_settlement`, `void_settlement`, and `get_group_settlements` require active membership and never accept a caller identity. Recording validates two different active participants, a positive exact amount, a non-archived group, and a supplied historical date. A settlement creator or active administrator can void, but cannot alter or reactivate, a settlement. `get_expense_activity` accepts only an expense ID and rechecks readable parent-expense access before returning a deliberately safe projection of immutable events. It does not expose audit JSON, raw auth data, or identifiers outside the accessible expense.

`rename_group`, `archive_group`, and `remove_group_member` each derive authority from `auth.uid()` and lock the relevant group and membership rows. They reject unavailable or archived groups and preserve history by using archive and removal timestamps. Administrators cannot remove an owner or another administrator; the owner cannot be removed before ownership is transferred. These public functions are executable only by `authenticated`.

`get_group_balances` is a `SECURITY DEFINER`, `STABLE` read-only RPC with a fixed `pg_catalog` search path. It accepts only `p_group_id`; the caller is derived from `auth.uid()` and must have completed onboarding and hold an active membership. Missing, foreign, or inactive group access all return the same unavailable result, avoiding an existence oracle. The function has no `public` execute grant, grants execution only to `authenticated`, derives output from existing payer, split, and settlement rows, and validates exact expense totals and group-wide zero sum before returning results. Its internal helper is in `app_private` and has no public execute grant.

## Audit history

Expense, payer, and split changes create `expense_events` through trusted triggers. Normal clients receive only `SELECT` on this table; they have no insert, update, or delete grants or policies. The event rows preserve enough financial context to understand changes without storing credentials or unnecessary authentication data.

## Threats addressed

- Cross-group reads are denied by active-membership checks.
- Cross-group payers, splits, and settlement participants are rejected by composite foreign keys and active-member trigger validation.
- Self-promotion and self-joining unrelated groups are denied by grants, RLS, and guarded role functions.
- Partial expense writes remain drafts and cannot become posted until totals match.
- Balance RPC calls cannot read another group's member or financial rows, and inconsistent records fail closed instead of producing a misleading total.
- Posted expenses cannot have their payer or split rows changed.
- Correction and settlement voiding preserve the original record instead of deleting or overwriting financial history.
- Guest records do not provide anonymous API access.
- Audit events cannot be fabricated or edited by normal clients.

## Risks intentionally postponed

This foundation does not provide invitation acceptance, guest claiming, account-deletion workflows, fraud detection, payment verification, automatic money movement, multiple-currency rules, offline conflict resolution, rate limiting, or production notification controls. These require product decisions, operational processes, and additional testing before release.
