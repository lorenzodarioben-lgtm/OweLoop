# Authentication redirects for hosted environments

OweLoop uses the mobile callback URL `oweloop://auth/callback` for email confirmation and password recovery. It contains no application secret. The Supabase Flutter client uses PKCE, receives the callback through the Android/iOS URL-scheme registrations, exchanges a valid code/session, and routes password-recovery sessions to the in-app password update form.

Before private beta, add this exact URL to the hosted Supabase Auth redirect allow-list for the beta project:

```text
oweloop://auth/callback
```

Confirm that the hosted project’s Site URL and email templates support the intended confirmation and recovery flows. Do not add a service-role key to the app, place access tokens in application logs, or configure a hosted project from this repository without an explicitly authorised target.

Test on physical Android and iOS devices with a real confirmation email and a real reset email. Cover a valid link, an expired or reused reset link, an app-cold-start callback, and an app-already-open callback. The app should display only generic reset-request feedback, so it does not reveal whether an arbitrary email address has an account.
