# Product requirements

## Problem and users

Shared costs are often remembered informally, entered late, or obscured by hard-to-follow settlement calculations. OweLoop will give students, roommates, couples, and group travellers a lightweight shared ledger with clear, inspectable balances.

The product differentiates itself from Splitwise by prioritising unlimited manual expense entry, guest participation without forcing every person to create an account, transparent balance calculations, and a durable audit history.

## Version 0.1 target

Version 0.1 is the first usable shared-expense workflow. It will support:

- Account creation.
- Group creation.
- Registered and guest group members.
- Equal, exact, percentage, and share-based expense splitting.
- Multiple payers.
- Group balances.
- Recorded settlements and settlement history.
- Expense correction by void-and-duplicate.
- Basic expense audit history.
- Group administration and repayment suggestions.

The repository now implements the first prerequisite journey: email-and-password registration and sign-in, email-verification guidance where Supabase requires confirmation, session restoration, and required profile onboarding. A user must explicitly choose a display name before reaching the authenticated home screen.

The repository now implements group creation, group list and detail views, and adding account-free guest members. The initial mobile currency selection supports AUD, CAD, EUR, GBP, JPY, NZD, SGD, and USD, while the database remains compatible with any valid uppercase three-letter ISO code.

The repository implements expense entry with one or multiple payers and equal, exact, percentage, or share-based splits. The client previews only exact integer minor-unit allocations, and the guarded database operation revalidates active membership, duplicate entries, non-negative split values, positive payer values, and exact payer/split totals before atomically posting. Equal, percentage, and share remainders have deterministic durable-member-ID ordering. JPY uses zero decimals; AUD, CAD, EUR, GBP, NZD, SGD, and USD use two decimals.

The repository implements recorded settlements, chronological settlement history, and guarded voiding. An active member records a payment that already occurred between two different active participants; a creator or administrator can void it while preserving history. Balances derive from posted, non-voided expenses and non-voided settlements, and include active zero balances, guests, and historical removed members.

Expense correction preserves the original record. A posted expense can be voided once by its creator or an administrator, then duplicated into a reviewable new-expense form. The expense-detail activity timeline presents safe human-readable creation, allocation, finalization, and void events without exposing raw audit JSON.

Owners and administrators can rename active groups, archive them, remove members while preserving historical records, and use the existing owner-only role and ownership-transfer controls. Archived groups retain readable history but reject future financial and membership writes. Repayment suggestions are deterministic, read-only simplifications of reconciled current balances; they can prefill a settlement record for active members but never transfer money automatically.

Sprint II supports owner-confirmed audited reopening and trusted operator
recovery of an ownerless archived ledger to an existing registered member.
Financial history and debt never change merely because a group reopens.
Expenses have optional immutable categories. Reusable group templates prefill
an explicitly reviewed form; they do not schedule or automatically post money.
Settlement history supports date, payer, receiver, exact amount, void-state and
order filters. Ledger exports are consistent complete snapshots with private
CSV sharing; personal JSON has the same explicit sharing option. A private
in-app inbox shows currently authorized activity and recipient-bound requests,
with account-specific read state. Device settings provide default currency and
confirmed cleanup of unsent drafts/temporary exports while preserving unknown
financial outcomes. Push/email, scheduled recurrence and receipts remain future
scope. See ADRs 0012-0014 for contracts.

The private-beta implementation also supports in-app invitations for registered users and explicit two-party guest account claims. Both are guarded server-side workflows: invitations can only create member roles, while claims preserve the original guest `group_members.id` and its financial history. Neither feature sends transactional email in this release or provides public account discovery.

Hosted deployment, account deletion, receipt scanning, payment processing, offline synchronization, monitoring, and public-production configuration remain deliberately postponed or require an operator decision.

## Deliberately postponed

- Receipt scanning.
- AI features.
- Subscriptions.
- Bank integrations.
- Payment processing.
- Advanced analytics.
- Multiple currencies.
- Full offline synchronisation.
- Account deletion and data export.
- Public account discovery or automated guest matching.
