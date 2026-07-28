# 0004: Record profile onboarding explicitly

## Status

Accepted

## Context

The profile trigger creates a safe fallback display name for every new Supabase Auth user. Inferring application readiness from that name would couple a user-facing value to control flow and make a legitimate chosen name ambiguous. The mobile client needs a durable, server-enforced boundary before allowing authenticated users into future protected product features.

## Decision

`public.profiles` records an `onboarding_completed_at` timestamp. It remains null for new profiles. The only ordinary-client write path is `public.complete_profile(text)`, which runs with narrowly scoped definer rights, requires `auth.uid()`, trims and validates the name, updates only the caller's record, and sets the timestamp atomically.

The mobile routing state treats a null completion timestamp as profile setup required. This rule is independent of the display name and can remain stable if profile editing is added later.

## Consequences

- A default profile name never grants access to the authenticated home screen.
- The onboarding decision is queryable and auditable without inspecting user-facing text.
- Direct client updates to profiles are not needed for onboarding and are not granted.
- A later profile-editing feature must use a similarly narrow, explicitly reviewed database write path.
