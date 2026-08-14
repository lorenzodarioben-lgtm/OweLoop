# Private beta end-to-end test plan

The repository includes a deliberately skipped Flutter integration-test entry
point at `mobile/integration_test/private_beta_journey_test.dart`. It remains
skipped until a hosted beta project, two disposable accounts, and an emulator
or physical device are supplied. It must not be marked as executed from local
widget-test results.

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

## Execution prerequisite

After hosted configuration exists, replace the skipped scaffold with real,
credential-free setup that obtains disposable test identities from the secure
test environment. Do not hard-code passwords, anon keys, refresh tokens, or
project references in source control. Run it on Android and later iOS, with
the results linked from the release checklist.
