# Private beta end-to-end test plan

The repository includes a configuration-gated native test at
`mobile/integration_test/private_beta_journey_test.dart`. It registers a local
disposable account and exercises real repositories through the UI. Without
local URL/key Dart defines it is skipped; it refuses hosted endpoints. Emulator
attempts and their actual status are recorded in [Sprint II](SPRINT_II_REPORT.md)
and [native testing](native-recovery-testing.md). Physical-device checks remain
open. The Node HTTP journey establishes backend concurrency evidence separately.

## Controlled two-account journey

Use two newly registered beta accounts, **A** and **B**, plus a third account
for guest-claim acceptance when helpful. Capture app version, device/OS,
backend project, and the result of each step.

1. Register A and B; confirm email verification, sign-in, password reset, and
   deep-link return behavior as configured for beta.
2. A creates a group and sends B an in-app invitation using B's known account
   email. B refreshes Invitations, accepts, and sees the group after refresh
   and app restart.
3. A creates an account-free guest. A records a flexible expense with multiple
   payers and a non-equal split. B verifies readable balance and history.
4. A or B records a repayment that already occurred. Both verify the balance
   changes and settlement history; no money is moved by OweLoop.
5. An owner/admin initiates a claim for the guest. The intended account accepts
   it. Verify the member row's durable identity/history/balance is retained and
   the claimed account sees the existing group.
6. Close and relaunch each app. Confirm session restoration, group data,
   balances, invitations, and claims reload correctly.
7. Repeat a financial submit after an intentionally interrupted/uncertain
   network response. Verify only one expense or settlement exists.
8. Exercise offline/timeout/error states: do not duplicate submissions; retry
   only after reconnecting; verify generic account/invitation feedback.
9. Archive a settled test group. Confirm history remains readable and new
   expenses, settlements, invitations, and membership changes are unavailable.
10. Reopen as its live owner; member/admin attempts must fail. Verify a single
    lifecycle event and unchanged balances. Separately rehearse trusted ownerless
    recovery on a disposable fixture; never grant clients an override.
11. Save a categorized unequal expense as a template without posting. Review
    with an inactive member, correct missing defaults, and explicitly post once.
    Race two edits and verify one optimistic conflict rather than lost updates.
12. Traverse filtered expense/settlement history; export while another user voids
    a record and verify internally consistent allocations/void state. Share CSV
    and personal JSON to a destination app; exercise cancellation and cleanup.
13. Read inbox activity as each account, mark one entry read, then remove a
    member and verify source details disappear. Change default currency and
    clear unsent drafts/private exports; pending unknown operations must remain.

## Execution prerequisite

Run the configured native test against a disposable local stack on Android and
later iOS. Execute the manual hosted journey separately with beta identities.
Include pending-operation recovery after process termination, draft restoration,
multi-page filtered history, CSV export, profile editing, deletion blockers and
settled-account deletion. Verify the deployed deletion Edge gateway as well as
the handler. Never hard-code passwords or tokens. Record build/device/environment
results in the release checklist.
