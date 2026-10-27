# 0013: Reviewable templates and consistent private exports

- Status: Accepted
- Date: 2026-10-25

Categories are optional stable keys rather than localized labels. Categorized
posting includes the key in its fingerprint and inserts it before finalization.
Legacy pending requests keep using the unchanged seven-argument contract. A
category cannot be updated after creation; corrections use void/duplicate.

Group templates contain whitelisted form configuration, never operation IDs or
financial records. PostgreSQL validates field types, exact default amount range,
category, split method, active same-group members and a 20KB payload bound.
Names are case-insensitively unique within a group. Identical create replay is
idempotent; editing/deleting uses an expected timestamp to avoid lost updates.
Only creator/admin may change them. A NULL deleted creator does not confer edit
authority. Archived templates are readable but immutable. Account deletion
retains shared configuration and removes its Auth link. Template review omits
inactive identities, clears an unavailable payer and requires explicit posting.
Templates do not implement recurrence or automatically create expenses.

Expense and settlement exports use scalar STABLE SQL functions: one statement
snapshot includes every relevant record and allocation, including voids. This
replaces cursor-walking exports. Lists still use indexed keyset pages; settlement
filters apply before pagination in either chronological direction. Complete
exports still materialize JSON in memory and are not streaming export jobs.

Native sharing uses maintained [share_plus](https://pub.dev/packages/share_plus/versions/13.3.1)
13.3.1 and a direct [path_provider](https://pub.dev/packages/path_provider)
dependency (already transitive). This adds platform share/save integration
without a custom Android/iOS bridge. Files are UTF-8 CSV/JSON with explicit MIME
types and safe generated filenames. Only an explicit user action writes the
app-private account cache; never public storage. Cancelled/error files are
deleted. Successful/unknown handoffs remain for up to 24 hours so destinations
can finish reading, and are pruned on later sharing. Account deletion clears
its cached exports best-effort. No outcome claims that the destination saved a
file; users must verify it. Sharing is bounded to 20MB and native behavior still
requires device validation.
