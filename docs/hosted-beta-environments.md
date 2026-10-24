# Hosted beta environments and migrations

## Environment boundaries

| Environment | Purpose | Flutter configuration | Data rule |
| --- | --- | --- | --- |
| Local | Development and pgTAP checks | `mobile/.env` with local public URL and anon key | Docker-only; reset is allowed. |
| Beta/staging | Controlled tester validation | `mobile/.env` with the beta project's public URL and anon key | Use disposable or consented tester data; never run a destructive reset. |
| Production | Future public release | Secure operator-provided public URL and anon key | Separate project, backups, access review, and change approval. |

`mobile/.env` is ignored. Only `mobile/.env.example` is committed. Flutter
needs only `SUPABASE_URL` and `SUPABASE_ANON_KEY`; neither a service-role key
nor any database password belongs in the app or repository.

## Hosted beta migration procedure

This is an operator runbook. It is intentionally **not** an automated command
in CI and must be performed only after selecting the correct hosted project.

1. Create a separate Supabase beta project. Confirm its project reference and
   that it is not production.
2. Configure hosted Auth before testers use it: add the exact
   `oweloop://auth/callback` redirect URL described in
   [auth redirects](auth-redirects.md), choose email-confirmation and SMTP
   settings, and record the public URL plus anon key in a local beta `.env`.
3. Have a second operator confirm the project target and take/verify a backup.
4. From a clean checkout at the reviewed release commit, authenticate the
   Supabase CLI as an authorised operator, link only that beta project, and
   inspect the remote migration list. Do not link a routine local workflow to
   any hosted project.
5. Apply the ordered migrations with the project-local CLI. Record the commit,
   operator, timestamp, migration list, and result in the release notes.
6. Re-run the migration-list check. Use the beta app with two disposable
   accounts to complete the private-beta smoke plan.

The relevant operator commands, after the project is independently verified,
are typically:

```sh
npx supabase link --project-ref <verified-beta-project-ref>
npx supabase migration list
npx supabase db push
npx supabase migration list
```

Never run `db reset` against a hosted beta or production project. Never pass
`--linked`, a project reference, or hosted credentials to the normal local
`npm run check:db` workflow.

## Rehearse before an upgrade

Before applying a later beta migration to non-empty data:

1. Restore a recent, access-controlled beta backup into an isolated rehearsal
   project, never into local development by accident.
2. Apply the pending migrations there first.
3. Check migration state, RLS-sensitive paths, balances, invitations, claims,
   and the two-account journey.
4. Compare expected record counts and representative balances before/after.
5. Require two-person approval before the real beta change.

## Drift and failed migrations

Treat a mismatched migration list or unexpected schema difference as a stop
condition. Capture the CLI output, project reference, release commit, and
backup timestamp. Do not edit an already-applied migration or manually patch
the production-like schema to make the list look clean.

For a failed migration:

1. Stop further deployment and tester communication that could depend on it.
2. Determine whether the database transaction rolled back completely; do not
   assume it did.
3. Preserve evidence, restore access if necessary, and create a new forward
   migration only after review.
4. Rehearse the forward fix against the isolated backup restore.
5. Apply the reviewed repair and document the incident in the release log.

## Account lifecycle deployment gate

The repository now contains personal/ledger export and a trusted deletion
component. Before beta, follow [account lifecycle](account-lifecycle.md), deploy
`delete-account` only on the independently verified beta project, and test the
real Edge gateway with disposable accounts. Confirm wrong-password and balance/
ownership rejection, actual de-identification, retained shared history and
old-token access denial. Local handler/Admin API tests do not establish hosted
packaging or deployment. Publish the retention/support process before enabling
this workflow for testers.
