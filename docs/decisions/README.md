# Architecture Decision Records

Sprint III: [0015 — bounded review-only recurrence](0015-bounded-review-only-recurrence.md).
Receipts: [0016 — private receipt gateway](0016-private-receipt-gateway.md).

Architecture Decision Records (ADRs) preserve decisions that affect the project's direction and would be costly or confusing to rediscover later.

Create an ADR only when a meaningful architectural decision has been made. Copy [0000-template.md](0000-template.md), assign the next sequential four-digit number, and use a concise kebab-case filename such as `0001-state-management.md`.

Keep the status current, describe the alternatives considered, and link related documentation or pull requests. Do not use ADRs for routine implementation notes or temporary task status.

Current financial and workflow decisions include [integer minor units](0001-integer-minor-units.md), [durable group-member identity](0002-durable-group-member-identity.md), [guarded finalization](0003-atomic-expense-finalization.md), [explicit onboarding](0004-explicit-profile-onboarding.md), [derived balances](0005-derived-group-balances.md), [generic exact expense persistence](0006-generic-expense-persistence.md), [void-and-duplicate correction](0007-void-instead-of-editing-posted-expenses.md), and [read-only repayment suggestions](0008-repayment-suggestions-are-read-only.md).

The functional sprint adds [checked allocation and money range](0009-exact-allocation-and-native-money-range.md),
[durable financial submissions](0010-durable-financial-submissions.md), and
[history/account lifecycle](0011-history-and-account-lifecycle.md).

Sprint II adds [audited archive recovery](0012-audited-archive-recovery.md),
[templates and consistent exports](0013-templates-and-export-snapshots.md), and
[private inbox and device preferences](0014-private-inbox-and-device-preferences.md).
