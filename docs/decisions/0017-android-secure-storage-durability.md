# 0017: Await Android secure-storage disk completion

- Status: Accepted
- Date: 2026-10-28

The locked flutter_secure_storage 11.2.0 Android implementation acknowledges
`SharedPreferences.apply()` before asynchronous disk completion. Its wrapped key
and configuration also use preferences. Awaiting the Dart write alone therefore
does not establish the persist-before-send boundary required by the ledger.

A narrow `oweloop/secure_storage` channel accepts only `flush` and no arguments.
The Android activity uses the pinned plugin's public default-configuration APIs
to identify wrapped-key, algorithm and data preferences. Empty `commit()` calls
on a dedicated worker wait for prior applies; only a true result confirms the
barrier, with a fifteen-second client deadline. No keys or financial payloads cross the channel or enter logs. Failures
block the network send. Future secure-storage upgrades/custom namespaces must
revalidate this coupling and rerun native process recovery.

[Android's documented contract](https://developer.android.com/reference/android/content/SharedPreferences.Editor)
states that commit waits for outstanding apply writes and reports persistent
storage success. The fence is off the UI thread. Existing encryption/Keystore
keys are unchanged; no plaintext recovery file is introduced. iOS retains the
existing Keychain API and still requires physical-device verification.

Financial store writes and explicit retries await the fence. Retrying must write
again even when a previous failed fence left the intent in the plugin's memory
cache; no in-memory-only fallback is permitted. Draft saves/deletions await it
too. The debug-only probe fences its credential fixture separately and reports
sanitized stage names on failure. The intermittent native type error's exact
cause is not assumed until a staged runtime result is available.

Tests cover waiting before send, fence failure, failure again on explicit retry,
eventual same-ID retry and a payload-free channel returning false. Actual OS
termination is the native validation gate; a unit test is not disk evidence.
