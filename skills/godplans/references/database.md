# Database planning module

Plans the data layer so checks a database auditor would perform later become requirements before schema work begins. The orchestrator loads this module for any archetype that persists state (saas-dashboard, api-service, mobile-app backend, ml-pipeline metadata); it is excluded, with a stated reason, only for stateless CLIs, static marketing sites, and pure libraries.

## Lineage

Descends from aihxp dbauditor, the read-only after-the-fact audit of schema, relationships, indexing, queries, transactions, migrations, data protection, search, and scale. dbauditor grades shipped DDL, never the ORM's promise, and hunts paper controls (FK NOT VALID never VALIDATEd, RLS ENABLEd but not FORCEd, inert @Transactional). This module inverts every one of its checks into a plan-time obligation: the discipline that carries over is evidence over assertion, the substitution test on every sentence, one owning dimension per defect class, and the rule that a control which does not bind in the database does not count.

## Decisions to force

1. Engine and workload paradigm.
   - Question: OLTP relational, document/KV, analytics warehouse, or mixed, and which engine?
   - Why locked in: every later choice (types, constraints, index kinds, migration mechanics) is engine-specific; a paradigm swap is a rewrite, not a refactor.
   - Options: Postgres (native uuid, jsonb, RLS, EXCLUDE, partial indexes), MySQL 8+ (only if the team owns it; CHECK enforced from 8.0.16, utf8mb4 mandatory), SQLite (single-writer tools only; PRAGMA foreign_keys per connection), document store (only when access patterns are genuinely aggregate-shaped).
   - Default: Postgres.
2. Primary key strategy.
   - Question: BIGINT identity, UUIDv7/ULID, or UUIDv4, decided per table class?
   - Why locked in: the PK type is mirrored into every FK column and every index; migrating an INT PK approaching 2.1 billion rows is a multi-deploy expand-contract under load.
   - Options: BIGINT identity (internal, high-insert), UUIDv7/ULID as native uuid (externally exposed IDs, distributed writers). Never random UUIDv4 as a clustered PK on hot tables; never INT/SERIAL on tables that can grow.
   - Default: BIGINT identity internally, UUIDv7 for anything exposed in a URL or API.
3. Tenancy isolation model.
   - Question: shared schema with RLS FORCEd, schema-per-tenant, or database-per-tenant?
   - Why locked in: retrofitting isolation onto a shared schema means touching every table, every query, and every index.
   - Options: shared schema with tenant_id plus Postgres RLS FORCEd (fits most SaaS), schema-per-tenant (few large tenants). App-layer WHERE alone is not an option; dbauditor scores it a hard Critical.
   - Default: shared schema, tenant_id NOT NULL on every tenant-owned table, RLS FORCEd with policies that survive pooled connections.
4. Money representation.
   - Question: integer minor units or NUMERIC(p,s), and where does currency live?
   - Why locked in: float contamination spreads through backfills, reports, and downstream copies; correcting it means re-deriving balances from history.
   - Options: BIGINT minor units plus currency column, or NUMERIC(p,s) with explicit precision and scale. FLOAT/DOUBLE/REAL for money is a hard Critical and a grade cap.
   - Default: integer minor units with a currency column.
5. Time representation.
   - Question: which columns are instants and which are wall-clock concepts, and what does the DDL say?
   - Why locked in: a TIMESTAMP-without-tz column filled from mixed zones is unrecoverable; you cannot reconstruct the original offsets.
   - Options: TIMESTAMPTZ written in UTC for all instants; date or plain timestamp only for genuine wall-clock concepts (birthdays, local opening hours).
   - Default: TIMESTAMPTZ + UTC, decided per column in the plan's data model.
6. Soft-delete policy.
   - Question: hard delete, deleted_at soft delete, or archive tables, per table class?
   - Why locked in: soft delete changes every UNIQUE (partial index WHERE deleted_at IS NULL), every FK story (parent invisible but children satisfied), and GDPR erasure reach.
   - Options: hard delete for disposable rows; soft delete with declared partial-unique and child-visibility rules; archive-and-purge for audit data.
   - Default: hard delete unless a requirement names recovery or audit; if soft delete, the plan states the full ruleset.

## Plan requirements

1. R-DB-1 PLAN.mdx declares the workload paradigm (OLTP/analytics/document/mixed), engine and version, data sensitivity classes present (PII/PHI/financial), tenancy model, and per-table expected scale (rows at 12 months, write rate); any deliberate denormalization names its maintenance mechanism.
   Criterion: WHEN the database domain is applicable THE PLAN SHALL contain a data-layer profile block stating paradigm, engine, sensitivity, tenancy, and per-table scale, and SHALL pair every denormalized or derived column with the job or trigger that maintains it.
2. R-DB-2 The plan's data model (erDiagram plus table list) gives every table a primary key, models every M:N through a junction table with composite PK and both FKs, and contains no CSV/JSON id lists, no repeating-group columns (phone1/2/3), and no unjustified EAV.
   Criterion: WHEN the plan defines a table THE PLAN SHALL state its PK, and IF a many-to-many relationship exists THE PLAN SHALL model it as a junction table, never as a delimited or JSON list column.
3. R-DB-3 Status and type fields are single state columns constrained by CHECK, lookup FK, or (non-Postgres-native) enum, never boolean-flag explosions; polymorphic associations use per-parent FK columns with an exclusive-arc CHECK; a naming convention is declared and applied; any planned triggers or stored procedures are listed with an owner.
   Criterion: WHEN a lifecycle or category is modeled THE PLAN SHALL specify one constrained state column, and IF a row can belong to one of several parent types THE PLAN SHALL specify per-parent FKs with an exclusive-arc CHECK rather than an unenforceable type+id pair.
4. R-DB-4 Money columns are integer minor units or NUMERIC with explicit precision and scale, always beside a currency column; the plan contains no floating-point money anywhere, including intermediates.
   Criterion: IF the system stores or moves money THE PLAN SHALL type it as integer minor units or NUMERIC(p,s) with a currency column, and SHALL state that FLOAT/DOUBLE/REAL is banned for monetary values.
5. R-DB-5 Temporal, identifier, and storage types are decided per column: TIMESTAMPTZ in UTC for instants, native uuid (or BINARY(16)) never VARCHAR(36), UUIDv7/ULID or BIGINT for high-insert PKs, jsonb never json/TEXT, utf8mb4 at server, table, and driver DSN on MySQL, intentional string lengths, BIGINT on any table or mirrored FK that can approach 2.1 billion, blobs in object storage by reference, NULL instead of sentinel values.
   Criterion: WHEN the plan types a column THE PLAN SHALL use the native type for its semantic (timestamptz, uuid, jsonb, boolean), and IF a table can exceed INT range THE PLAN SHALL type its PK and every mirroring FK as BIGINT.
6. R-DB-6 Every column referencing another table's key gets a real DB FOREIGN KEY with an intentional ON DELETE/ON UPDATE decided per child: CASCADE only for disposable children (sessions, tokens, join rows), RESTRICT or managed delete for independently valuable data (orders, invoices, ledger, audit); FK types and collations match both sides; mandatory relationships are NOT NULL; cascade behavior lives in DDL, not only in ORM options.
   Criterion: WHEN the plan defines a relationship THE PLAN SHALL specify the DDL FOREIGN KEY and its ON DELETE action with a one-line justification, and SHALL NOT specify CASCADE reaching financial or audit tables.
7. R-DB-7 The soft-delete policy (if any) states how children, hard FKs, and partial-unique indexes behave when the parent is soft-deleted; cross-database or cross-service references are paired with an outbox or reconciliation job plus a periodic orphan check; right-to-erasure reaches denormalized copies, caches, and logs.
   Criterion: IF soft delete or a cross-service reference exists THE PLAN SHALL state the child-row and orphan-handling policy, and IF PII is stored THE PLAN SHALL trace erasure through every denormalized copy.
8. R-DB-8 Constraints are DB-enforced: NOT NULL on every required column, DB DEFAULTs mirroring app defaults, CHECK constraints for domain and range invariants (qty >= 0, start <= end), CHECK ((a IS NULL) = (b IS NULL)) for paired nullables, natural business keys (email, sku, (tenant_id, slug)) under DB UNIQUE beside any surrogate PK, tenant-scoped UNIQUEs including tenant_id, and nullable-UNIQUE semantics decided explicitly (NULLS NOT DISTINCT or a partial index).
   Criterion: WHEN the plan states an invariant THE PLAN SHALL bind it with a named DDL constraint, and SHALL NOT delegate uniqueness or ranges to application validation alone.
9. R-DB-9 Every payment, webhook, or dedup path persists a UNIQUE-constrained idempotency key in the same transaction as its effect; overlap invariants (bookings, reservations) use EXCLUDE USING gist, not check-then-act.
   Criterion: IF a retried or externally triggered write path exists THE PLAN SHALL specify its UNIQUE idempotency key and the transaction it is written in.
10. R-DB-10 The plan maps every hot query (list endpoints, joins, auth lookups, search) to the exact index that serves it, in a table: query shape -> index DDL. Every FK child column is indexed on Postgres/Oracle; composites are ordered equality-first-range-last and aligned with ORDER BY direction; case-insensitive lookups get an expression index or citext.
   Criterion: WHEN the plan names a query path THE PLAN SHALL name the index that serves it including column order, and WHEN a FOREIGN KEY is planned on Postgres THE PLAN SHALL index the child column.
11. R-DB-11 Index types match access patterns: GIN for jsonb/array/tsvector/trigram, GiST for ranges and nearest-neighbor, BRIN for append-only time order; no redundant prefix-duplicate indexes, no lone low-cardinality single-column indexes, few composites rather than many singles on write-heavy tables.
   Criterion: IF a non-scalar or pattern-match access exists THE PLAN SHALL choose the matching index type, and SHALL NOT plan a B-tree for a leading-wildcard or jsonb predicate.
12. R-DB-12 The query layer section specifies the eager-loading primitive per relation to prevent N+1, explicit column projections on hot paths, mandatory pagination with a hard cap on every list path using keyset/seek (deep OFFSET banned), sargable predicates with typed bind parameters, batch reads via WHERE id = ANY(:ids), and a COUNT strategy (estimate, counter, or LIMIT k+1) for large tables.
   Criterion: WHEN the plan defines a list endpoint THE PLAN SHALL specify keyset pagination with a hard cap and the index it rides, and WHEN a relation is rendered in a collection THE PLAN SHALL name its eager-load mechanism.
13. R-DB-13 Runtime posture is planned: statement, lock, and idle-in-transaction timeouts set at the role default and verified to survive the pooler; connection pool sized against max_connections (including serverless fan-out); session and connection cleanup on all error paths.
   Criterion: WHEN the plan configures the database THE PLAN SHALL state the three timeouts and pool sizing arithmetic, and IF a transaction-mode pooler is used THE PLAN SHALL forbid session state it cannot carry (prepared statements, SET, advisory locks) or choose a compatible mode.
14. R-DB-14 Every multi-statement write is wrapped in one transaction with try/finally commit/rollback; read-modify-write is replaced by atomic SET col = col + delta, version-checked UPDATE (version in the WHERE, rowcount checked), or SELECT FOR UPDATE; one canonical lock ordering is declared; bulk writes are chunked; isolation level is chosen per invariant with a 40001 retry loop wherever SERIALIZABLE is used.
   Criterion: WHEN the plan defines a write path touching mutable shared values THE PLAN SHALL name the concurrency mechanism (atomic update, optimistic version, or row lock) and the transaction boundary.
15. R-DB-15 No external I/O (HTTP, payment, email) inside an open transaction: commit first or use a transactional outbox; cross-service workflows get sagas or compensation plus a durable outbox; cache-fronted reads get an explicit invalidation and stampede policy implementing the tier, staleness budget, and trigger set by R-ARCH-23.
   Criterion: IF a write path calls an external service THE PLAN SHALL sequence it as commit-then-call or route it through an outbox table written in the same transaction.
16. R-DB-16 Migration policy is expand-contract for every rename, drop, and type change (add, dual-write, backfill in batches with separate commits, cut over, tombstone, drop across deploys); CREATE INDEX CONCURRENTLY outside a transaction; ADD COLUMN without volatile defaults then batched backfill; SET NOT NULL via CHECK NOT VALID -> VALIDATE -> SET NOT NULL; every NOT VALID constraint has its VALIDATE step scheduled in the same plan; lock_timeout set for the migration session.
   Criterion: WHEN the plan schedules a schema change on a populated table THE PLAN SHALL decompose it into lock-safe steps across deploys, and SHALL NOT plan a single-step rewrite, rename, or direct SET NOT NULL.
17. R-DB-17 Every migration is reversible with a tested down path or an explicit backup gate for destructive steps; DDL is idempotent; a single migration head is enforced; a CI migration safety gate (strong_migrations or squawk lint, dry-run, up-then-down round trip) is a task in the pipeline from day one.
   Criterion: WHEN the plan introduces migration tooling THE PLAN SHALL include a CI gate task that lints migrations and round-trips up-then-down, and IF a migration is destructive THE PLAN SHALL require a backup gate before it runs.
18. R-DB-18 Access is parameterized queries only, with an allowlist for dynamic sort and table identifiers; the app connects as a least-privilege role with DML only on its tables; a separate migration identity owns DDL; secrets live in env or vault, never in the repo (rotation required on any historical exposure); TLS is verify-full; encryption at rest is declared in IaC; the database binds to a private network only.
   Criterion: WHEN the plan defines database access THE PLAN SHALL specify parameterized queries, the two-role split (app DML vs migration DDL), verify-full TLS, and private binding, and SHALL NOT place a connection string in any committed file.
19. R-DB-19 Data protection is DB-enforced: multi-tenant isolation via RLS FORCEd (never app WHERE alone) with policies that survive pooled connections; column-level encryption or tokenization for PII/PHI; passwords under argon2id or bcrypt; CVV never stored; an audit trail on sensitive tables; views over PII scoped and security_invoker.
   Criterion: IF the system is multi-tenant THE PLAN SHALL enforce isolation with FORCEd RLS at the database, and IF PII/PHI/financial data is stored THE PLAN SHALL name the column-level protection per sensitive column.
20. R-DB-20 If a search surface exists, the plan picks the primitive per feature up front: pg_trgm GIN for substring and fuzzy, tsvector plus GIN with a matching config for FTS, relevance ranking always specified; external engines sync via transactional outbox plus CDC with delete propagation and a documented reindex path (handler dual-write banned); vector columns get an ANN index whose operator class matches the query's distance operator, built after load; tenant and ACL filtering is enforced in the source of truth.
   Criterion: WHEN the plan includes a search feature THE PLAN SHALL name the index primitive and ranking function per feature, and IF an external engine is used THE PLAN SHALL specify outbox-plus-CDC sync with delete propagation.
21. R-DB-21 Every growth-bearing table (events, logs, audit, sessions, outbox) gets a retention or TTL policy with an automated reaper or partition drop; large append-only tables get declarative range partitioning with automated partition management; hot single-row counters become sharded counters or append-and-aggregate ledgers; partitioning and read routing implement the key and per-entity read stances set by R-ARCH-21, and post-write reads on money, auth, or inventory get read-your-writes routing; slow-query observability (pg_stat_statements or equivalent), backup/PITR posture, and any materialized-view refresh (scheduled, CONCURRENT) are stated.
   Criterion: WHEN the plan defines an append-only or high-churn table THE PLAN SHALL pair it with its retention mechanism, and WHEN replicas serve reads THE PLAN SHALL declare read-your-writes routing for money, auth, and inventory paths.
22. R-DB-22 The plan enforces invariants in shipped DDL, not ORM annotations, bans every paper-control pattern by name (NOT VALID without a scheduled VALIDATE, UNIQUE on nullable without a semantics decision, RLS ENABLEd but not FORCEd, @Transactional without verified semantics, timeouts that die at the pooler), and includes a strengths-to-preserve inventory (real FKs, NUMERIC or integer money, keyset pagination, DB-enforced uniqueness) that later tasks must not regress.
   Criterion: WHEN the plan claims an integrity or security control THE PLAN SHALL bind it to specific DDL a later audit can read, and SHALL list the strengths inventory that executing agents are forbidden to regress.
23. R-DB-23 The plan requires money flows to reconcile end to end across every stage and store: the amount authorized or charged equals the amount persisted on the order or booking, the invoice, the settlement, any refund, and any marketplace payout or transfer, with add-ons, discounts, credits, and tax accounted on every side; provider status (payment, refund, transfer, payout) is confirmed before a local record is marked final; a marketplace refund reverses the already-released transfer; and a later price or status change reconciles the already-settled invoice rather than silently diverging.
   Criterion: WHEN a payment, refund, payout, or transfer path is planned THE PLAN SHALL name the fields compared at each reconciliation point and SHALL include a test that drives a paid order through an add-on change, a refund, and a marketplace payout and asserts every side of the ledger balances.

## Task seeds

- [ ] GP-xxx Author initial schema migration with DDL-enforced invariants
  - Files: db/migrations/0001_init.sql, docs/data-model.md
  - Acceptance: every CREATE TABLE has a PRIMARY KEY; every *_id column has REFERENCES with an explicit ON DELETE; money columns are BIGINT or NUMERIC with a currency column; instants are TIMESTAMPTZ; natural keys carry UNIQUE; required columns carry NOT NULL
  - Verify: grep -nE "FLOAT|DOUBLE|REAL" db/migrations/0001_init.sql | grep -iv comment; exit 1 expected, and grep -c "REFERENCES" db/migrations/0001_init.sql matches the relationship count in docs/data-model.md
  - Requirements: R-DB-2, R-DB-4, R-DB-5, R-DB-6, R-DB-8
- [ ] GP-xxx Build the query-to-index map and index migration
  - Files: docs/index-map.md, db/migrations/0002_indexes.sql
  - Acceptance: docs/index-map.md is a table mapping every list endpoint, join, and auth lookup to one index DDL line; every FK child column appears; composites are equality-first-range-last; CREATE INDEX uses CONCURRENTLY
  - Verify: grep -c "CREATE INDEX CONCURRENTLY" db/migrations/0002_indexes.sql equals the row count of docs/index-map.md minus header
  - Requirements: R-DB-10, R-DB-11
- [ ] GP-xxx Implement transaction and concurrency policy on write paths
  - Files: src/db/tx.ts, src/services/payments.ts, docs/concurrency.md
  - Acceptance: multi-statement writes go through one withTransaction helper with try/finally; balance updates are atomic SET or version-checked UPDATE with rowcount asserted; no HTTP client import inside a transaction body; idempotency key insert shares the effect's transaction
  - Verify: grep -n "fetch\|axios\|http" src/db/tx.ts src/services/payments.ts returns no hit inside withTransaction blocks; grep -c "FOR UPDATE\|SET .* = .* +\|version =" src/services/payments.ts >= 1
  - Requirements: R-DB-9, R-DB-14, R-DB-15
- [ ] GP-xxx Wire the migration CI safety gate
  - Files: .github/workflows/migrations.yml, db/README.md
  - Acceptance: CI job lints migrations (squawk or strong_migrations), asserts a single migration head, and round-trips up-then-down against a disposable database; destructive ops require an explicit allow marker with justification
  - Verify: grep -c "squawk\|strong_migrations" .github/workflows/migrations.yml >= 1 and grep -c "down" .github/workflows/migrations.yml >= 1
  - Requirements: R-DB-16, R-DB-17
- [ ] GP-xxx Establish DB security baseline: roles, RLS, TLS, binding
  - Files: db/migrations/0003_roles_rls.sql, infra/db.tf, .env.example
  - Acceptance: app role has DML only, migration role owns DDL; every tenant-owned table has ALTER TABLE ... FORCE ROW LEVEL SECURITY and a tenant policy; infra declares private binding, TLS verify-full, encryption at rest; .env.example carries placeholders only
  - Verify: grep -c "FORCE ROW LEVEL SECURITY" db/migrations/0003_roles_rls.sql equals the tenant-owned table count; grep -n "postgres://" -r . --include="*.ts" --include="*.yml" returns nothing outside .env.example
  - Requirements: R-DB-18, R-DB-19
- [ ] GP-xxx Add retention, partitioning, and observability posture
  - Files: db/migrations/0004_partitions.sql, jobs/reaper.ts, docs/db-operations.md
  - Acceptance: every table listed as growth-bearing in the plan has a partition-drop schedule or reaper job; pg_stat_statements enabled; statement, lock, and idle-in-transaction timeouts set at role level; backup/PITR posture documented
  - Verify: grep -c "PARTITION BY RANGE\|DROP PARTITION\|delete_before" db/migrations/0004_partitions.sql jobs/reaper.ts >= growth-bearing table count; grep -c "statement_timeout" db/migrations/0004_partitions.sql >= 1
  - Requirements: R-DB-13, R-DB-21
- [ ] GP-xxx Implement search primitives per the plan's search table
  - Files: db/migrations/0005_search.sql, src/search/query.ts
  - Acceptance: each search feature uses its planned primitive (pg_trgm GIN, tsvector GIN, or ANN index) with the index expression matching the query expression; ranking function present; no LIKE '%term%' without a trigram index
  - Verify: grep -c "USING GIN\|USING gist\|USING hnsw" db/migrations/0005_search.sql >= search feature count; grep -n "LIKE '%" src/search/query.ts returns nothing unindexed
  - Requirements: R-DB-20

## Self-audit rubric

Base weights mirror dbauditor; drop N/A dimensions and re-normalize to 100, never zero-and-keep.

- Referential integrity (14): every relationship has a DDL FK with a justified ON DELETE, matched types both sides, NOT NULL where mandatory; soft-delete and cross-service policies stated; no cascade path reaches financial or audit data.
- Indexing (13): the query-to-index map exists and is total over hot paths; FK children indexed; composite order and index types justified per pattern; no planned redundancy.
- Query layer (12): eager-loading named per relation, keyset pagination with caps on every list path, sargable typed predicates, batch reads, a COUNT strategy, timeouts and pool arithmetic that survive the pooler.
- DB security (12): parameterized-only access, two-role split, verify-full TLS, private binding, secrets never committed, FORCEd RLS for tenancy, per-column PII protection, erasure reach traced.
- Schema design (11): PKs everywhere, junction tables for M:N, constrained state columns, exclusive-arc polymorphism, declared naming convention, denormalization paired with maintenance.
- Constraints (10): NOT NULL, DEFAULTs, CHECKs, tenant-scoped and natural-key UNIQUEs, idempotency keys, nullable-UNIQUE semantics all decided in DDL terms.
- Transactions (9, if write path): transaction boundaries, concurrency mechanism per mutable value, lock ordering, no I/O in transactions, outbox and saga coverage, isolation with retry.
- Types (7): money, time, uuid, jsonb, charset, BIGINT headroom, blob placement, and NULL-over-sentinel all decided per column.
- Migrations (6, if tooling): expand-contract policy, lock-safe step decomposition, scheduled VALIDATEs, reversibility or backup gates, CI gate task present.
- Search (4, if search surface): primitive, ranking, sync architecture, and ANN operator-class match specified per feature.
- Scale and operations (2, re-weight up on growth signals): retention per growth table, partitioning, counter strategy, read-your-writes routing, observability and backup posture.

Full marks require the criterion of every requirement in that dimension to be checkable against the plan text alone. A module total below 85 forces a revision before the plan ships. One unmitigated hard-Critical pattern in the plan (float money, app-only tenancy, plaintext PII, missing idempotency UNIQUE on a payment path) caps the module score at 69.

## Anti-patterns refused

- ORM-promise integrity: validations, unique flags, and associations declared only in models while the DDL enforces nothing. Refusal: the planner writes invariants as DDL in the schema tasks; model annotations are documentation, never the control.
- Paper controls: NOT VALID without a VALIDATE step, UNIQUE on a nullable column with no semantics decision, RLS ENABLEd but not FORCEd, @Transactional with unverified semantics, timeouts that a transaction pooler discards. Refusal: every planned control names the exact DDL and the condition under which it binds; known-inert forms are banned by requirement R-DB-22.
- Float money: FLOAT/DOUBLE/REAL on ledger or balance columns. Refusal: the planner types money before any table is written and marks the choice as a hard-to-reverse decision; a plan containing float money does not pass the self-audit gate.
- App-only uniqueness: SELECT-then-INSERT dedup on identity, payment, or idempotency keys. Refusal: the planner adds the DB UNIQUE at design time and routes retried paths through R-DB-9.
- Lock-heavy migration theater: single-step renames, volatile-default ADD COLUMN, direct SET NOT NULL, CREATE INDEX without CONCURRENTLY on populated tables. Refusal: every schema-evolution task is pre-decomposed into expand-contract steps with lock_timeout set; the CI gate task rejects regressions.
- Dual-write search sync: the request handler writing to both the database and the search engine. Refusal: search sync is planned as transactional outbox plus CDC with delete propagation, or the feature stays in-database.
- Add-indexes platitude: recommendations that would read true for any repo. Refusal: the substitution test applies to every plan sentence; each index, constraint, and policy names its table, columns, and the query it serves.
- App-WHERE tenancy: multi-tenant isolation living only in query builders. Refusal: tenancy is a forced decision (Decision 3); shared-schema plans require FORCEd RLS with pooler-safe policies before the plan can emit.
- Invented database work: planning database sections for a project with no persistent state. Refusal: the orchestrator excludes the domain with a stated reason instead of fabricating tables.
