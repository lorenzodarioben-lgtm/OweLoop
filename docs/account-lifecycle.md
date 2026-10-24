# Account lifecycle and data portability

The Account screen edits the private display name, exports personal JSON, and
requests password-confirmed account deletion. Existing group display names are
historical membership snapshots. Group ledger exports provide complete expense
and settlement CSV text, including voided records. Minor-unit amounts remain
decimal integers; personal JSON uses strings for monetary columns. CSV cells
that could be spreadsheet formulas are escaped. Export is explicit copyable
text; native file sharing is not implemented.

## Deletion policy implemented in code

Deletion requires every membership balance to be zero. Active group owners must
transfer ownership or archive their group first. Archived, settled groups may
retain an ownerless historical ledger after deletion. No shared expense, payer,
split, settlement or event is cascade-deleted. Membership IDs remain; account
links and group creators are nulled, memberships become removed `Deleted member`
records, and the private profile/Auth identity is removed. Shared descriptions
and financial audit snapshots are retained. This is an engineering policy; the
operator must publish an appropriate privacy/retention notice before distribution.

The trusted Auth deletion trigger enforces the checks even when a server-side
administrator invokes deletion. It locks groups in stable order and uses a
private transaction-only guard to permit narrowly shaped de-identification of
archived records. An AFTER trigger removes the guard after FK actions. Normal
clients cannot read, create or imitate guards. Old JWTs lose group access because
their memberships no longer reference the deleted user. JWT expiration alone is
not relied upon. Expense audit insertion tolerates a deleted actor reference.

## Deployable deletion component

`supabase/functions/delete-account/index.ts` invokes the tested handler. The
handler validates the session with Auth, reauthenticates the server-verified
email with the submitted current password, checks blockers, and calls the Auth
Admin deletion API for that exact verified identity. Caller-supplied user IDs
are ignored. Service credentials stay exclusively in the function environment.

After independently selecting and backing up a **beta** project, apply all
ordered migrations and deploy with the project-local CLI:

```powershell
npx supabase functions deploy delete-account --project-ref <verified-beta-project-ref> --no-verify-jwt
```

The handler performs its own online Auth validation; `--no-verify-jwt` disables
only gateway JWT verification so modern signing keys are supported. It does not
grant anonymous deletion. Supabase supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`
and `SUPABASE_SERVICE_ROLE_KEY` to the hosted function. Never copy the service key
into Flutter, a committed env file, or client logs. Validate wrong passwords,
ownership/balance blockers, network interruption and actual deletion on beta
before marking the workflow operational. No hosted function was deployed here.

## Verification and commands

```powershell
npm run test:account-function
npm run test:integration
```

The first command tests authentication, reauthentication, verified identity,
blockers and failure responses with a mocked transport. The second uses real
local Auth/PostgREST; with the local service-role key supplied only in the test
process it exercises the handler against the real local Admin API, verifies
retained history and checks old-token read denial. It does not verify Edge
gateway packaging or physical-device behavior. Both tests refuse or avoid
production resources. See `docs/testing.md` for local environment setup.
