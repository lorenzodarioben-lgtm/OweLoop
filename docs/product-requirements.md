# Product requirements

## Problem and users

Shared costs are often remembered informally, entered late, or obscured by hard-to-follow settlement calculations. OweLoop will give students, roommates, couples, and group travellers a lightweight shared ledger with clear, inspectable balances.

The product differentiates itself from Splitwise by prioritising unlimited manual expense entry, guest participation without forcing every person to create an account, transparent balance calculations, and a durable audit history.

## Version 0.1 target

Version 0.1 is the first usable shared-expense workflow. It will support:

- Account creation.
- Group creation.
- Registered and guest group members.
- Equal expense splitting.
- Multiple payers.
- Group balances.
- Settlements.
- Basic expense audit history.

The repository now implements the first prerequisite journey: email-and-password registration and sign-in, email-verification guidance where Supabase requires confirmation, session restoration, and required profile onboarding. A user must explicitly choose a display name before reaching the authenticated home screen.

The repository now implements group creation, group list and detail views, and adding account-free guest members. The initial mobile currency selection supports AUD, CAD, EUR, GBP, JPY, NZD, SGD, and USD, while the database remains compatible with any valid uppercase three-letter ISO code.

The repository now implements equal-split expense entry, posted expense history, and transparent group balances. An active group member selects one payer and one or more active participants. The total is entered and stored as exact integer minor units, split equally, and posted atomically. Any remainder is assigned deterministically by ascending durable group-member ID. The mobile client supports JPY as a zero-decimal currency and AUD, CAD, EUR, GBP, NZD, SGD, and USD with two decimals. Balances derive from posted, non-voided payer and split rows plus recorded, non-voided settlements; the member list includes active zero balances, guests, and historical removed members.

Registered-user invitations, guest claiming, member removal or role changes, group archiving UI, settlement entry, expense editing or voiding, and audit-history screens are not yet implemented.

## Deliberately postponed

- Receipt scanning.
- AI features.
- Subscriptions.
- Bank integrations.
- Payment processing.
- Advanced analytics.
- Multiple currencies.
- Full offline synchronisation.
