# Local scale observations

## Sprint III — measured 2026-10-28

Migration 29 retains all authorization, per-expense allocation validation,
settlement validation, individual bigint checks and group zero-sum checks. It
aggregates payer/split totals once and computes canonical member rows once,
replacing per-expense lateral rescans and the second canonical-row calculation.
Seven additional corruption/removed-identity assertions fail closed as before.

Two independent disposable PostgreSQL 17.6 stacks ran identical bounded fixtures.
For each fixture the benchmark copies the released public read function into a
temporary, test-only namespace, performs three alternating warm reads of each
implementation and requires identical ordered financial/member rows. The original
26 migrations remain unchanged. The first read is after fixture insertion; it
does **not** represent a cold OS/database data cache. No caches were forcibly cleared.

| Members / expenses / settlements | Run 1 released → current median ms | Run 2 released → current median ms |
| --- | ---: | ---: |
| 2 / 20 / 10 | 5.807 → 3.628 | 3.202 → 2.048 |
| 20 / 300 / 100 | 103.447 → 68.194 | 94.013 → 70.533 |
| 100 / 1,000 / 500 | 497.130 → 401.850 | 505.447 → 430.482 |
| 1,000 / 2,000 / 1,000 | 1,899.726 → 1,614.612 | 1,975.233 → 1,719.795 |

Observed median improvements were 13–38%, with substantial variance/outliers.
This supports retaining the smaller aggregate query; it establishes no latency
target or production capacity. The history plans retain bounded index-only scans.
Raw timing samples and all summary observations are in
[SPRINT_III_BENCHMARK.json](SPRINT_III_BENCHMARK.json).

The same helper also seeds one **committed fictional fixture only in its uniquely
named disposable stack**, then measures actual Auth/PostgREST responses, including
serialization and Node JSON parsing. Its own stack cleanup removes the data.

| Actual HTTP RPC, 1,000 members / 2,000 expenses / 1,000 settlements | Rows | UTF-8 bytes | Three elapsed ms |
| --- | ---: | ---: | --- |
| Balance snapshot | 1,000 | 203,910 | 1,290.115 / 1,202.489 / 1,155.403 |
| Membership snapshot | 1,000 | 138,937 | 15.139 / 12.768 / 13.974 |
| Expense export snapshot | 2,000 | 2,350,000 | 362.949 / 362.254 / 381.756 |
| Settlement export snapshot | 1,000 | 436,000 | 125.942 / 26.538 / 27.716 |

Node RSS before/after reads was 40,079,360 / 63,639,552 bytes; process maximum RSS
was 74,358,784 bytes. Startup, GC and full response materialization affect these
figures. **No Flutter/Android/iOS memory, scrolling or production load result is
claimed.** Different fixtures/statistics explain why HTTP and SQL timings differ.

Reproduce with `./scripts/check-local.ps1 -SkipInstall -DartIntegration -StorageAndFunctions -Benchmark`.
SQL fixtures roll back; HTTP fixtures are confined to the helper's own stack.
The helper restores its process environment and stops only that stack.

Resource policies remain explicit: history/occurrences use 50+lookahead pages;
schedule discovery is 90 days/100 schedules; receipts are 4 MiB/4096px/20 active
per expense with 6 MiB gateway bodies and 50-item stale-cleanup batches. Native
CSV/JSON sharing remains capped at 20 MiB. Complete ledger/personal exports and
memberships/balances still materialize whole responses. They are not streaming
exports or a supported group-size guarantee. Native profiling remains a release
engineering task; integrity checks must not be weakened to satisfy a timer.

## Historical Sprint II observations

Measured 2026-10-25 on the Windows Docker Desktop local Linux engine,
PostgreSQL 17.6, through `scripts/benchmark-local.mjs`. These are individual
warm/local SQL observations, not production latency targets, device/UI timings
or an HTTP load test. Fixture insertion, assertions and reads use a single
rollback-only transaction. No hosted endpoint is accepted.

```powershell
.\scripts\check-local.ps1 -SkipInstall -Benchmark
```

For an already-running disposable local stack, set `OWELOOP_DB_CONTAINER` to
its local database container and run `npm run benchmark:local`. The script
checks local Docker context, complete member/export counts, canonical zero sum,
and prints bounded EXPLAIN ANALYZE/BUFFERS history plans. No credentials are
required in benchmark arguments.

| Members / expenses / settlements | Balance ms | First history ms | Expense export ms | Settlement export ms | Inbox ms | Personal export ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 2 / 20 / 10 | 6.657 | 2.828 | 2.548 | 0.797 | 3.891 | 1.352 |
| 20 / 300 / 100 | 112.861 | 0.746 | 15.847 | 1.127 | 3.670 | 3.852 |
| 100 / 1,000 / 500 | 518.683 | 1.470 | 77.265 | 551.912 | 12.224 | 26.734 |
| 1,000 / 2,000 / 1,000 | 1,700.208 | 1.298 | 393.135 | 46.144 | 58.073 | 130.643 |

All four fixtures passed. The 551 ms settlement observation is an outlier in
this single run; do not infer a scaling curve from it. Personal exports include
previous fixtures in the same transaction and are cumulative. At the largest
fixture, next/filtered history took 0.627/0.766 ms, membership snapshot 5.622 ms,
and safe activity 1.388 ms. History used `expenses_history_cursor` index-only
scans with 51 returned rows for all but the smallest fixture (sequential scan).

History widgets are lazy and keyset paged; export snapshots, memberships,
canonical balances and personal JSON are still materialized in memory.
Balance validation is the main measured large-fixture cost. Do not weaken its
invariants to improve a timing. Profile the whole Android/iOS journey, memory,
scrolling and network payloads before setting supported group-size limits.
Export sharing currently rejects documents larger than 20 MiB. Notifications
derive current authorization from source records; revisit their source-query
plans as audit history grows.
