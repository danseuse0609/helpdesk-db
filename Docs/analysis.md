# ANALYSIS.md — Help Desk Ticket System
## CS-630 Final Project | Data Science Track

This document contains 15 analytical queries answering distinct business and
statistical questions about the help desk data.  Each query includes:
- The question it answers
- Commented SQL using advanced features (CTEs, window functions, aggregates)
- Performance notes relevant to large-scale datasets

---

### Query 1: Average Resolution Time by Priority

**Question:** What is the average, minimum, and maximum resolution time (in hours)
for each ticket priority level?

```sql
-- Average resolution time distribution per priority.
-- Only considers tickets that have been resolved (resolved_at IS NOT NULL).
SELECT
    t.priority,
    COUNT(*)                                           AS total_resolved,
    ROUND(AVG(
        (t.resolved_at - t.created_at) * 24            -- Oracle interval to hours
    ), 2)                                              AS avg_hrs,
    ROUND(MIN(
        (t.resolved_at - t.created_at) * 24
    ), 2)                                              AS min_hrs,
    ROUND(MAX(
        (t.resolved_at - t.created_at) * 24
    ), 2)                                              AS max_hrs
FROM tickets t
WHERE t.resolved_at IS NOT NULL
GROUP BY t.priority
ORDER BY
    CASE t.priority
        WHEN 'critical' THEN 1
        WHEN 'high'     THEN 2
        WHEN 'medium'   THEN 3
        WHEN 'low'      THEN 4
    END;
```

**Performance notes:** Index on `(priority, resolved_at, created_at)` enables
an index-only scan for this aggregate.  At millions of rows, a partial index
filtered to `resolved_at IS NOT NULL` cuts I/O significantly.

---

### Query 2: Technician Leaderboard by Resolved Tickets

**Question:** Which technicians have resolved the most tickets, and what is
their average CSAT score?

```sql
-- Ranks technicians by tickets resolved; joins CSAT for satisfaction score.
SELECT
    u.full_name,
    COUNT(t.ticket_id)                                 AS tickets_resolved,
    ROUND(AVG(cs.score), 2)                            AS avg_csat,
    RANK() OVER (ORDER BY COUNT(t.ticket_id) DESC)     AS resolution_rank
FROM users u
JOIN tickets t
    ON t.assigned_to = u.user_id
    AND t.status IN ('resolved', 'closed')
LEFT JOIN csat_scores cs
    ON cs.ticket_id = t.ticket_id
WHERE u.role = 'technician'
GROUP BY u.user_id, u.full_name
ORDER BY tickets_resolved DESC;
```

**Performance notes:** `RANK()` window function runs over the result set after
aggregation — no extra sort needed if `ORDER BY` matches the window.
Composite index on `tickets(assigned_to, status)` avoids a full table scan.

---

### Query 3: SLA Breach Rate per Company

**Question:** Which companies breach SLA the most often, and for which
priority levels?

```sql
-- Calculates breach rate = breaches / total resolved tickets per company/priority.
WITH resolved_counts AS (
    SELECT company_id, priority, COUNT(*) AS total_resolved
    FROM   tickets
    WHERE  status IN ('resolved', 'closed')
    GROUP  BY company_id, priority
),
breach_counts AS (
    SELECT
        t.company_id,
        t.priority,
        COUNT(sb.breach_id) AS total_breaches
    FROM   tickets t
    JOIN   sla_breaches sb ON sb.ticket_id = t.ticket_id
    GROUP  BY t.company_id, t.priority
)
SELECT
    c.company_name,
    rc.priority,
    rc.total_resolved,
    NVL(bc.total_breaches, 0)                          AS total_breaches,
    ROUND(NVL(bc.total_breaches, 0) / rc.total_resolved * 100, 1)
                                                       AS breach_pct
FROM   resolved_counts rc
JOIN   companies c        ON c.company_id  = rc.company_id
LEFT JOIN breach_counts bc ON bc.company_id = rc.company_id
                           AND bc.priority   = rc.priority
ORDER  BY breach_pct DESC;
```

**Performance notes:** Two CTEs keep the logic modular and let the optimizer
choose the best join order.  Indexes on `sla_breaches(ticket_id)` and
`tickets(company_id, priority, status)` are key for large datasets.

---

### Query 4: Monthly Ticket Volume Trend

**Question:** How does total ticket volume and the share of critical/high
tickets change month-over-month?

```sql
-- Monthly ticket counts with critical+high share trend.
SELECT
    TO_CHAR(created_at, 'YYYY-MM')                     AS month,
    COUNT(*)                                           AS total_tickets,
    SUM(CASE WHEN priority IN ('critical','high') THEN 1 ELSE 0 END)
                                                       AS urgent_tickets,
    ROUND(
        SUM(CASE WHEN priority IN ('critical','high') THEN 1 ELSE 0 END)
        / COUNT(*) * 100, 1
    )                                                  AS urgent_pct,
    -- Month-over-month change using LAG window function
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY TO_CHAR(created_at, 'YYYY-MM'))
                                                       AS mom_change
FROM tickets
GROUP BY TO_CHAR(created_at, 'YYYY-MM')
ORDER BY month;
```

**Performance notes:** `LAG()` over the aggregated monthly result set is
inexpensive.  An index on `created_at` supports the implicit range scan
during aggregation.

---

### Query 5: First-Response Time Distribution (Histogram Buckets)

**Question:** What percentage of tickets receive their first technician
comment within 1 hour, 4 hours, 24 hours, and beyond?

```sql
-- Uses ticket_comments to find the first technician response per ticket,
-- then buckets the gap from ticket creation.
WITH first_response AS (
    SELECT
        tc.ticket_id,
        MIN(tc.created_at) AS first_comment_at
    FROM ticket_comments tc
    JOIN users u ON u.user_id = tc.author_id AND u.role = 'technician'
    GROUP BY tc.ticket_id
),
response_gaps AS (
    SELECT
        t.ticket_id,
        t.priority,
        (fr.first_comment_at - t.created_at) * 24  AS response_hrs
    FROM tickets t
    JOIN first_response fr ON fr.ticket_id = t.ticket_id
)
SELECT
    CASE
        WHEN response_hrs <= 1   THEN '<=1 hr'
        WHEN response_hrs <= 4   THEN '1–4 hrs'
        WHEN response_hrs <= 24  THEN '4–24 hrs'
        ELSE                          '>24 hrs'
    END                                                AS bucket,
    COUNT(*)                                           AS ticket_count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1)  AS pct
FROM response_gaps
GROUP BY
    CASE
        WHEN response_hrs <= 1   THEN '<=1 hr'
        WHEN response_hrs <= 4   THEN '1–4 hrs'
        WHEN response_hrs <= 24  THEN '4–24 hrs'
        ELSE                          '>24 hrs'
    END
ORDER BY MIN(response_hrs);
```

**Performance notes:** Composite index on `ticket_comments(ticket_id, created_at)`
makes the MIN() aggregate fast.  The window `SUM(COUNT(*)) OVER ()` avoids
a second pass over the table.

---

### Query 6: Top 10 Ticket Categories by Average Resolution Time

**Question:** Which ticket categories take the longest to resolve on average?

```sql
SELECT
    category,
    COUNT(*)                                           AS total,
    ROUND(AVG((resolved_at - created_at) * 24), 2)    AS avg_resolution_hrs,
    ROUND(MEDIAN((resolved_at - created_at) * 24), 2) AS median_resolution_hrs
FROM tickets
WHERE resolved_at IS NOT NULL
GROUP BY category
ORDER BY avg_resolution_hrs DESC
FETCH FIRST 10 ROWS ONLY;
```

**Performance notes:** `FETCH FIRST` (Oracle 12c+) uses a STOPKEY plan,
avoiding a full sort.  `MEDIAN` is computed in a single pass in Oracle.

---

### Query 7: Reopen Rate — Tickets That Were Resolved Then Reopened

**Question:** What fraction of tickets get reopened after resolution,
broken down by technician?

```sql
-- Counts tickets that have a 'reopened' entry in the status history.
WITH reopened AS (
    SELECT DISTINCT ticket_id
    FROM   ticket_status_history
    WHERE  new_status = 'reopened'
)
SELECT
    u.full_name                                        AS technician,
    COUNT(t.ticket_id)                                 AS total_resolved,
    COUNT(r.ticket_id)                                 AS reopened_count,
    ROUND(COUNT(r.ticket_id) / COUNT(t.ticket_id) * 100, 1)
                                                       AS reopen_rate_pct
FROM   users u
JOIN   tickets t  ON t.assigned_to = u.user_id
                  AND t.status IN ('resolved','closed','reopened')
LEFT JOIN reopened r ON r.ticket_id = t.ticket_id
WHERE  u.role = 'technician'
GROUP  BY u.user_id, u.full_name
HAVING COUNT(t.ticket_id) >= 5   -- exclude techs with tiny samples
ORDER  BY reopen_rate_pct DESC;
```

**Performance notes:** The CTE materializes the `DISTINCT` set once.
The `HAVING` clause filters noise from low-volume technicians, which also
helps if the result is used as a training signal.

---

### Query 8: Knowledge Base Article Effectiveness

**Question:** Do tickets that reference a KB article resolve faster than
those that do not?

```sql
-- Compares average resolution time for tickets with vs without KB references.
SELECT
    CASE WHEN kb_ref.ticket_id IS NOT NULL THEN 'With KB Article'
         ELSE 'Without KB Article'
    END                                                AS kb_used,
    COUNT(t.ticket_id)                                 AS ticket_count,
    ROUND(AVG((t.resolved_at - t.created_at) * 24), 2)
                                                       AS avg_resolution_hrs
FROM   tickets t
LEFT JOIN (
    SELECT DISTINCT ticket_id FROM ticket_kb_references
) kb_ref ON kb_ref.ticket_id = t.ticket_id
WHERE  t.resolved_at IS NOT NULL
GROUP  BY CASE WHEN kb_ref.ticket_id IS NOT NULL THEN 'With KB Article'
               ELSE 'Without KB Article' END;
```

**Performance notes:** The subquery on `ticket_kb_references` uses DISTINCT
to avoid inflating counts when multiple articles are linked.  An index on
`ticket_kb_references(ticket_id)` makes the left join a nested-loop lookup.

---

### Query 9: Cumulative Tickets Resolved per Technician (Running Total)

**Question:** What is the running total of tickets resolved by each
technician over time (useful for capacity planning)?

```sql
-- Running total using SUM() OVER (PARTITION BY ... ORDER BY ...).
SELECT
    u.full_name,
    TRUNC(t.resolved_at, 'MM')                        AS resolution_month,
    COUNT(t.ticket_id)                                 AS monthly_resolved,
    SUM(COUNT(t.ticket_id)) OVER (
        PARTITION BY u.user_id
        ORDER BY TRUNC(t.resolved_at, 'MM')
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                  AS running_total
FROM   tickets t
JOIN   users u ON u.user_id = t.assigned_to
WHERE  t.status IN ('resolved', 'closed')
AND    t.resolved_at IS NOT NULL
GROUP  BY u.user_id, u.full_name, TRUNC(t.resolved_at, 'MM')
ORDER  BY u.full_name, resolution_month;
```

**Performance notes:** Partitioned window functions avoid a self-join.
Pre-aggregating by month before the window keeps the frame small.

---

### Query 10: Correlation Proxy — Priority vs. Resolution Time

**Question:** Is there a statistical relationship between priority level
and time to resolve? (Pearson correlation proxy using SQL.)

```sql
-- Pearson correlation between priority_encoded and time_to_resolve_hrs
-- from the pre-computed ticket_features table.
SELECT
    ROUND(
        (COUNT(*) * SUM(priority_encoded * time_to_resolve_hrs)
          - SUM(priority_encoded) * SUM(time_to_resolve_hrs))
        /
        SQRT(
          (COUNT(*) * SUM(priority_encoded * priority_encoded) - POWER(SUM(priority_encoded),2))
          *
          (COUNT(*) * SUM(time_to_resolve_hrs * time_to_resolve_hrs) - POWER(SUM(time_to_resolve_hrs),2))
        )
    , 4) AS pearson_correlation
FROM ticket_features
WHERE time_to_resolve_hrs IS NOT NULL;
```

**Performance notes:** All arithmetic runs in a single pass over
`ticket_features`, which is a pre-aggregated table — ideal for statistical
computations at scale.  No indexes needed for a full-scan aggregate.

---

### Query 11: CSAT Score Distribution (Percentiles)

**Question:** What are the 25th, 50th, 75th, and 95th percentile CSAT
scores per company?

```sql
-- Uses PERCENTILE_CONT (Oracle analytic function) for exact percentiles.
SELECT
    c.company_name,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY cs.score), 2)  AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY cs.score), 2)  AS median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY cs.score), 2)  AS p75,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cs.score), 2)  AS p95,
    COUNT(cs.csat_id)                                                  AS responses
FROM   csat_scores cs
JOIN   tickets t   ON t.ticket_id  = cs.ticket_id
JOIN   companies c ON c.company_id = t.company_id
GROUP  BY c.company_id, c.company_name
ORDER  BY median DESC;
```

**Performance notes:** `PERCENTILE_CONT` is an ordered-set aggregate that
requires a sort; this is unavoidable.  For very large tables, a
pre-bucketed summary (like `company_weekly_stats`) can approximate the
distribution without re-sorting raw data.

---

### Query 12: Ticket Backlog Aging Report

**Question:** How many open tickets are overdue (older than their SLA
resolution target), broken down by priority?

```sql
-- Identifies open/in_progress tickets older than their SLA resolution target.
SELECT
    t.priority,
    COUNT(*) AS backlog_tickets,
    SUM(CASE
        WHEN (SYSTIMESTAMP - t.created_at) * 24 > sp.resolution_hrs
        THEN 1 ELSE 0
    END)     AS overdue_tickets,
    ROUND(
        SUM(CASE
            WHEN (SYSTIMESTAMP - t.created_at) * 24 > sp.resolution_hrs
            THEN 1 ELSE 0
        END) / COUNT(*) * 100
    , 1)     AS overdue_pct
FROM   tickets t
JOIN   sla_policies sp ON sp.company_id = t.company_id
                       AND sp.priority   = t.priority
WHERE  t.status IN ('open', 'in_progress')
GROUP  BY t.priority
ORDER  BY
    CASE t.priority
        WHEN 'critical' THEN 1 WHEN 'high' THEN 2
        WHEN 'medium'   THEN 3 WHEN 'low'  THEN 4
    END;
```

**Performance notes:** `SYSTIMESTAMP` is evaluated once per statement.
The join to `sla_policies` is small (few rows per company) and will be
a hash broadcast join at scale.

---

### Query 13: Tag Co-occurrence — Which Tags Appear Together Most Often

**Question:** Which pairs of tags most frequently appear on the same ticket?
(Useful for auto-tagging or topic modeling.)

```sql
-- Self-join on ticket_tags to find co-occurring tag pairs.
SELECT
    t1.tag_name  AS tag_a,
    t2.tag_name  AS tag_b,
    COUNT(*)     AS co_occurrences
FROM   ticket_tags tt1
JOIN   ticket_tags tt2  ON tt2.ticket_id = tt1.ticket_id
                        AND tt2.tag_id   > tt1.tag_id   -- avoid duplicates
JOIN   tags t1          ON t1.tag_id = tt1.tag_id
JOIN   tags t2          ON t2.tag_id = tt2.tag_id
GROUP  BY t1.tag_name, t2.tag_name
ORDER  BY co_occurrences DESC
FETCH FIRST 20 ROWS ONLY;
```

**Performance notes:** The `tt2.tag_id > tt1.tag_id` condition halves the
result set, avoiding (A,B) and (B,A) duplicates.  An index on
`ticket_tags(ticket_id, tag_id)` makes both sides of the self-join fast.

---

### Query 14: Technician Workload Balance (Standard Deviation)

**Question:** How evenly distributed is the current open ticket workload
across technicians? A high standard deviation signals imbalance.

```sql
-- Computes mean and stddev of open ticket assignments per technician.
WITH load AS (
    SELECT
        u.user_id,
        u.full_name,
        COUNT(t.ticket_id) AS open_tickets
    FROM   users u
    LEFT JOIN tickets t ON t.assigned_to = u.user_id
                       AND t.status IN ('open', 'in_progress')
    WHERE  u.role = 'technician'
    GROUP  BY u.user_id, u.full_name
)
SELECT
    full_name,
    open_tickets,
    ROUND(AVG(open_tickets)    OVER (), 2)  AS team_avg,
    ROUND(STDDEV(open_tickets) OVER (), 2)  AS team_stddev,
    -- Z-score: how many stddevs from mean
    ROUND(
        (open_tickets - AVG(open_tickets) OVER ())
        / NULLIF(STDDEV(open_tickets) OVER (), 0)
    , 2)                                    AS z_score
FROM load
ORDER BY open_tickets DESC;
```

**Performance notes:** All three window functions (`AVG`, `STDDEV`, Z-score)
operate over the same partition, so Oracle evaluates them in a single pass
over the CTE result set.

---

### Query 15: EXPLAIN PLAN — Optimizing the Resolution Time Query at Scale

**Question (operational):** Can the resolution time aggregation (Query 1)
be executed efficiently at 10 million+ rows?

```sql
-- Step 1: View the execution plan for the resolution time query.
EXPLAIN PLAN FOR
SELECT
    t.priority,
    ROUND(AVG((t.resolved_at - t.created_at) * 24), 2) AS avg_hrs
FROM tickets t
WHERE t.resolved_at IS NOT NULL
GROUP BY t.priority;

-- Step 2: Display the plan output.
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

**Expected plan analysis:**

| Step | Operation | Notes |
|------|-----------|-------|
| 1 | TABLE ACCESS FULL (or INDEX RANGE SCAN) | Full scan acceptable if no filter on priority; range scan if filtered |
| 2 | HASH GROUP BY | Oracle chooses hash aggregation for large cardinality groups |

**Optimization recommendation:**

Create a partial composite index:

```sql
CREATE INDEX idx_tickets_resolution
ON tickets (priority, resolved_at, created_at)
WHERE resolved_at IS NOT NULL;
```

This index allows an **index-only scan** — the optimizer never touches the
main table.  At 10M rows with ~70% resolved, this reduces I/O from a full
heap scan (~500 MB) to the index leaf blocks (~50 MB).

Additionally, for recurring dashboard queries, populate `company_weekly_stats`
with a nightly batch job so dashboards query the aggregate table instead of
raw tickets — reducing query time from seconds to milliseconds at scale.
