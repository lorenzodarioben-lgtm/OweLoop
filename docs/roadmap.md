# Roadmap

## Implemented and locally verified

The shared-expense core includes email/password and profile flows, durable
registered/guest memberships, invitations and explicit guest claims, guarded
roles/ownership, archive and settled removal/leave. Expenses support multiple
payers and equal/exact/percentage/share splits, audit history and void/duplicate
correction. Canonical balances and repayment suggestions are exact; settlements
record external payments and preserve voided history.

The functional sprint adds checked allocation/range arithmetic, direct-mutation
protections, persisted manual retry/reconciliation, session-generation guards,
nested navigation, complete cursor history with expense filters, saved expense
drafts, CSV/personal JSON exports, profile editing and a trusted account-deletion
component. Forward migrations, adversarial pgTAP, real local Auth/PostgREST
concurrency and non-empty upgrade validation are implemented and executed.
See [the completion report](FUNCTIONAL_COMPLETION_REPORT.md) for precise evidence.

## Next: native and beta release gates

1. Android debug compilation passed GitHub CI. Run the configured local native journey;
   exercise process termination, secure-storage recovery, account switching,
   system back, callbacks, large text and TalkBack on a physical device.
2. Build on macOS/Xcode and validate iOS Keychain, signing, callbacks, VoiceOver
   and equivalent account/financial journeys.
3. Configure reviewed beta infrastructure and email delivery, apply migrations
   after backup/rehearsal, deploy the trusted deletion Edge function and test
   its actual gateway, blockers, identity validation and retained records.
4. Publish privacy/retention/support information, select crash reporting or a
   staffed manual process, rehearse recovery and record release/test owners.
5. Review exact-head CI and complete the private-beta checklist before any
   distribution. Local tests and plain functional screens are not release proof.

## Functional follow-up

- Resolve archived groups with outstanding balances: there is no in-app
  unarchive/settlement path and deletion correctly stays blocked.
- Test large-group UI memory/scrolling and whole JSON snapshots; improve export
  snapshot consistency under concurrent edits and add native file sharing.
- Extend settlement discovery and preferences beyond profile. Localization,
  categories, recurring expenses, notifications and receipts remain absent.
- Revisit unknown-email invitation delivery with an explicit verified identity
  model; current requests remain unbound until revoked/resubmitted after signup.

## Later product decisions

Full offline synchronization, receipt scanning, analytics, subscriptions,
AI assistance, bank/payment integrations and currency conversion require their
own correctness/privacy/scope decisions. No placeholder feature is counted as
implemented. Presentation design may proceed independently using
[the neutral functional handoff](DESIGN_HANDOFF.md).
