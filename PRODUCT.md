# Product

OweLoop is a shared-expense mobile ledger for roommates, couples, students and
travellers. Registered users collaborate with account-free guest participants.
Each group has one currency. Expenses record who paid and owes what; balances
and history explain the result. Settlements record payments made elsewhere.

Implemented features include flexible exact splits, financial recovery,
registered invitations, explicit guest claims, group administration, filtered
expense and settlement history, expense drafts, exports, profile editing
and a deployable trusted deletion component. Sprint II adds audited archive
recovery, optional immutable categories, reviewed reusable templates, settlement
filters, consistent snapshots/private CSV/JSON sharing, a private activity inbox
and device currency/cleanup settings. The
[completion report](docs/FUNCTIONAL_COMPLETION_REPORT.md) separates tested code
from unverified device/hosted behavior and missing features.

Financial correctness, authorization, understandable errors and accessible
controls are product requirements. Payment processing, currency conversion,
full offline synchronization, receipt attachments, scheduled recurring
expenses, localization and push/email delivery are not implemented. Templates
never automatically post expenses. Physical-device and hosted release checks
remain open.

Current screens use standard Material controls. Visual design is a separate
phase; layouts, themes and component composition can change while preserving
contracts in [the design handoff](docs/DESIGN_HANDOFF.md).
