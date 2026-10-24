# Local scale observations

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
