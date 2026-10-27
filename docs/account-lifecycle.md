# Account lifecycle and data portability

Receipts are shared financial documents: account deletion removes creator/actor
Auth links but retains ready files and receipt audit. Removed/deleted memberships
lose future Storage reads. Voiding retains receipts; archived groups permit reads
and deny uploads/deletions. In active groups uploader/admin can explicitly delete
an attachment while its metadata/audit remains. Personal export includes currently
readable metadata/events, without image bytes or access URLs. These technical
retention rules require the operator's reviewed privacy notice before distribution.

The Account screen edits the private display name, exports personal JSON, and
requests password-confirmed account deletion. Existing group display names are
historical membership snapshots. Group ledger exports provide complete expense
and settlement CSV text, including voided records. Minor-unit amounts remain
decimal integers; personal JSON uses strings for monetary columns. CSV cells
that could be spreadsheet formulas are escaped. CSV and personal JSON have
explicit native file sharing as well as clipboard copy. Files live in the
account's private temporary directory, with cancellation/error cleanup and
24-hour expiry on the next share. Successful destination import still needs
physical-device testing. Personal export includes readable templates and the
caller's notification read markers.

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

An archived group with a nonzero balance blocks deletion too. Its live owner can
reopen it in Group settings, then settle and transfer ownership or archive it
again before deletion. Reopening records an immutable lifecycle event and never
changes balances. If no live owner remains, a trusted operator may invoke
`recover_ownerless_archived_group` for an existing active registered successor,
with a documented reason. This service-role-only RPC is not exposed by the app;
there is no client deletion override or automatic debt forgiveness. See ADR 0012.
