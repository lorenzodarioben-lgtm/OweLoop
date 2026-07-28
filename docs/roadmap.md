# Roadmap

## Foundation — complete in this task

- Flutter Android and iOS project in `mobile/`.
- Environment-based Supabase startup configuration.
- Riverpod root scope and GoRouter application shell.
- Initial test coverage and continuous integration.
- Documentation and migration directory.
- Secure Supabase/PostgreSQL core schema, Row-Level Security, database tests, and decision records.

## Version 0.1 — shared expenses

1. Authentication and account lifecycle - complete for email/password access and required profile onboarding.
2. Groups with registered and guest members - group creation, group viewing, and adding account-free guests are complete; invitations, guest claiming, removal, and role-management UI remain pending.
3. Equal-split expenses - one-payer entry, exact deterministic equal splits, posted history, and expense detail are complete; multiple-payer UI, flexible splits, editing, voiding, balances, and settlements remain pending.
4. Transparent per-group balances and settlements.
5. Basic audit history for expense changes.

## Later versions

Receipt scanning, AI assistance, subscriptions, bank integrations, payment processing, advanced analytics, multiple currencies, and full offline synchronisation will be evaluated only after the Version 0.1 shared-expense workflow is stable.
