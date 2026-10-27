# Authentication redirects for hosted environments

## Disposable local Mailpit rehearsal

The generated development stack captures mail locally; no SMTP account is needed.
With the default dev port block, open Mailpit at `http://127.0.0.1:61424` (the
isolated check helper uses 60424). Create a disposable local app account, sign out,
request Forgot password, and inspect only that local inbox. Never copy recovery
links/tokens into shell history, CI output, screenshots or tracked fixtures.

Open the link in the emulator's browser; change only the verify URL's loopback
host to `10.0.2.2`, retaining its port/path/query and the `oweloop://auth/callback`
redirect. A host-browser `127.0.0.1` URL does not reach the backend from Android.
Verify cold-start and already-open delivery to Update password, explicit update,
sign-out/sign-in with the new password, and generic rejection on link reuse/expiry.
Repeat with a stale original screen/account switch and confirm no previous account
content returns. Do not redirect a disposable token to a hosted project.

Ordinary local signup deliberately disables confirmation, so it cannot establish
verification-email behavior. A separate disposable confirmation-enabled config
(`auth.email.enable_confirmations = true`) is required for the signup/resend/
confirmation journey; keep it isolated from an existing generated project and
never modify hosted Auth as part of routine checks. The email/browser/native link
steps above are a repeatable manual guide, **not an executed callback result**.

## Hosted release gate

OweLoop uses the mobile callback URL `oweloop://auth/callback` for email confirmation and password recovery. It contains no application secret. The Supabase Flutter client uses PKCE, receives the callback through the Android/iOS URL-scheme registrations, exchanges a valid code/session, and routes password-recovery sessions to the in-app password update form.

Before private beta, add this exact URL to the hosted Supabase Auth redirect allow-list for the beta project:

```text
oweloop://auth/callback
```

Confirm that the hosted project’s Site URL and email templates support the intended confirmation and recovery flows. Do not add a service-role key to the app, place access tokens in application logs, or configure a hosted project from this repository without an explicitly authorised target.

Test on physical Android and iOS devices with a real confirmation email and a real reset email. Cover a valid link, an expired or reused reset link, an app-cold-start callback, and an app-already-open callback. The app should display only generic reset-request feedback, so it does not reveal whether an arbitrary email address has an account.
