# 0016: Private image receipts through a trusted gateway

- Status: Accepted
- Date: 2026-10-28

Receipt support is an explicit configured capability. Ordinary app builds hide
it until `--dart-define=OWELOOP_RECEIPTS_ENABLED=true`; the local setup must opt
into `dev:start -- --storage`. This enables Storage and Edge only in the generated
per-checkout configuration and copies the checked-in functions. Hosted provisioning
and function deployment remain separate owner-approved release work.

The native picker uses Flutter's maintained [file_selector 1.1.0](https://pub.dev/packages/file_selector),
with Android/iOS type filters. This direct runtime dependency is necessary for
native file selection; Flutter handles in-app image viewing without another viewer.
No camera/gallery-wide permissions or new background service are introduced.
PDF/WebP are deliberately unsupported in this bounded first implementation.
Native picker/device/iOS behavior is separate from mocked widget verification.

Only PNG/JPEG up to 4 MiB and 4096 pixels per side are accepted. The client reads
bounded chunks and checks extension/signature. The trusted gateway verifies Auth
online, bounds the JSON body to 6 MiB, validates magic/PNG chunk structure or JPEG
dimension markers, checks the declared type and hashes bytes. This is structural
validation, not antivirus or a complete image decoder; only an image widget ever
renders the bytes. Original image metadata is retained. SVG/HTML/executable content
without the accepted image structure is rejected. Server filenames are opaque
expense/receipt UUIDs with a type-derived extension, never original filenames.

`expense_receipts` is an upload/delete state machine; it cannot change expenses.
Client-generated upload UUIDs bind caller, expense, SHA-256, type and size.
The gateway reserves an intent through caller-scoped SQL, writes using a server
credential and alone may confirm completion. Concurrent/interrupted uploads must
verify exact stored bytes before completion; they never overwrite an object.
A lost completion response keeps the object because it may already be ready.
Selected bytes/ID are retained in memory for explicit same-ID retry, not in the
financial-operation store. After process death refresh server state; a retained
uncompleted intent can be explicitly deleted before reselecting a file. No
financial outcome or operation ID changes as part of this workflow.

Metadata/download reads have thirty-second client deadlines; gateway writes have
sixty seconds. A timed-out write remains uncertain and retains its selected ID.
No timeout is interpreted as proof that the server did not store or delete a file.

The [private bucket](https://supabase.com/docs/guides/storage/buckets/fundamentals)
uses current membership RLS for authenticated downloads. No public/signed URL is
created. Restrictive write policies prevent direct client upload/update/delete,
even if another permissive policy is later added. Metadata/event DML is revoked;
trusted completion and stale cleanup RPCs are service-role-only. Pending files
are not readable by other members. Archive permits ready-file reads but no new
uploads/deletions. Voiding retains ready receipts and permits audited uploader/
admin deletion only in active groups. Removal immediately revokes future reads.
Auth deletion de-identifies creator/actor links and retains shared files/audit.

Deletion revokes reads first (`deleting`), removes the object, then records
`deleted`; failures remain retryable. Append-only receipt events record each
transition. No hard deletion of expense or financial audit rows occurs.
At most twenty non-deleted attachments/intents exist per expense. Operator cleanup
claims only pending/deleting/deleted records older than 24h with a timestamp guard,
then deletes their exact object and confirms the tombstone. Ready objects are
never candidates. Old tombstones are also swept to handle a late object from an
interrupted upload. `receipts:cleanup` refuses hosted URLs, handles at most fifty
candidates and returns an opaque continuation ID; it never runs automatically.
Privacy/retention notices and hosted operator ownership remain release gates.

Personal export includes currently readable receipt metadata/events, not image
bytes, credentials or access URLs. Native viewing holds only memory bytes and
clears selection/preview and decoded cache on account change. In-flight authorized
downloads can already have delivered bytes; revocation cannot recall those copies.
