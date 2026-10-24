# Sprint II engineering record

Started 2026-10-25 (Australia/Sydney), continuing `codex/functional-completion`
from `280b86dd9f67a1fecd25de97c185d9febd856ceb`, draft PR #8. Initial working
tree and remote branch were clean and identical. No historical migration or
first-sprint commit is rewritten.

## Current milestones

- Archived-group recovery: owner-only audited reopen UI/RPC; separate
  service-role-only ownerless recovery to an existing registered member.
  Group locks, immutable financial history and direct-write denial remain.
  Lifecycle events and deletion guidance are implemented. See ADR 0012.
- Categories: optional stable keys, immutable posting, category-aware
  fingerprints, create/detail/duplicate/draft/history/export propagation.
  Legacy seven-argument expense RPCs and existing pending requests remain valid.
  New helper duplicates the established allocation validation to insert category
  before posting; clients cannot call the unchecked helper.
- Upgrade harness now starts at all twenty first-sprint migrations and compares
  every pre-existing column/row plus canonical balances. New nullable fields
  are checked separately rather than treating schema extension as lost data.

## Evidence so far

The second milestone adds server-side settlement date/payer/receiver/amount/
void-state filtering and stable oldest/newest cursors; transactionally consistent
ledger export snapshots including allocation JSON; explicit private CSV/JSON
sharing; and reusable group templates with optimistic edits and no financial
posting. New workflow tests bring Flutter to 175 passing tests with clean
analysis. Fresh initialization and twenty-plus-five migration upgrade passed,
as did all pgTAP files, schema lint, six handler tests and the existing HTTP
journey. ADR 0013 records the new persistence and export contracts.

Before changes: 167 Flutter tests and the full disposable backend baseline passed
(303 pgTAP assertions, six handler tests, 32 HTTP assertions, twelve-plus-eight
migration upgrade). Recovery/category iteration: existing Flutter suite plus
reopen widget journey passed (168); category-specific tests were added afterward
and will be included in the next full run. The disposable database initialization,
new tests, schema lint, twenty-plus-two upgrade and existing HTTP journey passed.
Final counts and final-head CI will be recorded before handoff.

Local Android diagnosis found two JDK21 installations, no connected ADB device
and no configured AVD. A process-local JDK21 build with IPv4 preference still
failed at Gradle loopback initialization, before application compilation. No
firewall/security settings were changed; this failure will not be retried without
a changed condition. Native runtime and secure-storage process-death evidence
remain unverified. Work continues on independently testable features.
