# 0015: Server-calendar recurrence with explicit financial review

- Status: Accepted
- Date: 2026-10-28

Schedules pin the validated template name/configuration at creation. Editing or
deleting the live template cannot change these snapshots; a deleted creator is
de-identified while shared schedules/history remain. Members can opt in by creating
a schedule; only creator/admin can edit, pause, resume or permanently cancel it.
There is no end-date control in this first version; cancellation stops all review.

Daily, weekly, fortnightly and monthly cadence uses PostgreSQL calendar dates in
an explicitly chosen IANA timezone. The server clock determines due status, not
the phone clock. Monthly anchors clamp to shorter month ends and return to the
original anchor day next month. DST changes cannot shift calendar-day identities.

Opening Recurring drafts discovers only dates from server-today minus 90 days
through today. Unmaterialized older dates are deliberately omitted, stated in UI.
No background worker or cron runs. Upcoming dates are derived without creating
proposals. At most 100 schedules exist per group; history uses 50 rows plus one
lookahead and `(due_date,id)` keyset cursors. Existing discovered history remains.
Unique `(schedule_id,due_date)` identities and the group lock prevent duplicates
on concurrent opens or resume. Calendar edits must anchor tomorrow or later;
old due proposals keep their pinned fields, while future discovery uses the new
calendar. Pausing/cancelling makes all pending proposals nonactionable. Archive
allows authorized reads and rejects generation/mutation; reopening restores it.

Review opens the ordinary expense form, with current membership filtering and
the due date prefilled. User changes are reviewed and explicitly posted. The
form disables unrelated template/draft actions to retain the occurrence link;
edits before submission are not saved between navigation. Pending payloads are
still encrypted before send and retain the original operation ID and occurrence
reference. Unknown outcomes use ordinary check/retry; no background posting exists.

`post_scheduled_expense` takes the stable group/occurrence locks, verifies current
authorization/actionability and calls existing categorized posting. Completion
and expense linkage occur atomically. One occurrence references at most one
expense, and one expense can complete at most one occurrence. Matching completed
replays return the existing record, even for another currently authorized reviewer;
conflicting payloads reject. Voiding does not reopen the proposal: correction is
an ordinary explicit duplicate. Skips are retained and replay-idempotent.

New tables have RLS and no direct client DML. RPCs have fixed search paths and
caller-derived authority. Personal export includes currently readable schedules
and occurrences, without generating any due records. No dependency was added.
