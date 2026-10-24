# 0010: Persist before send and reconcile uncertain submissions

- Status: Accepted
- Date: 2026-10-24

Expense and settlement requests are saved before any network write. The native
client uses `flutter_secure_storage` 11.2.0 because ordinary preferences do not
provide appropriate encryption for financial payloads. This is the sprint's
only new direct runtime dependency. See the [package documentation](https://pub.dev/packages/flutter_secure_storage).
Android automatic backup is disabled; iOS Keychain entitlements are configured.
Actual device encryption/restart behavior remains a release verification gate.

Saved records contain account ID, group ID, operation type, UUID, canonical RPC
payload, timestamp, status and an optional confirmed result. Storage keys are
account scoped. They contain no passwords, Auth tokens or privileged keys.
Unsent expense drafts use a separate keyspace and contain no operation identity.

The state machine is `pending -> confirmed | rejected | unknown`. Pending after
a restart is treated as uncertain. A timeout, missing lookup result, response
loss or local completion-write failure cannot establish rejection. Only a
known SQL transaction rejection on the first attempt is definitive. PostgREST
also wraps damaged success/proxy responses, so its exception type alone never
establishes failure. A rejected retry cannot erase a prior unknown outcome;
only a matching confirmed lookup or successful replay resolves that uncertainty.
An unavailable or permanently rejected original action can therefore stay
blocked for support review rather than unlocking a duplicate. Unresolved records are retained without an
automatic retry loop. Recent completed outcomes are bounded to 30 records.

An unchanged retry reuses its persisted payload and identity. A different
payload for the same group/type is blocked while an earlier outcome is unknown.
The originating form's identity also replays a confirmed result locally during
the interval before navigation finishes. Account changes invalidate the caller;
another account cannot recover or submit the saved request.

`get_financial_operation(uuid)` exposes only the caller's operation outcome.
The Pending submissions screen explicitly checks status or retries the saved
request. A missing result stays unknown, since the original transaction may
still commit. Server fingerprints and advisory locks remain the final duplicate
and payload-mismatch boundary. Clearing application storage or losing the device
loses local recovery data; users must inspect authoritative history before
re-entering an uncertain transaction on another installation.
