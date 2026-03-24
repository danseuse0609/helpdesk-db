-- =============================================================
-- HELP DESK TICKET SYSTEM: 15 ANALYSIS QUERIES (FIXED FOR ORACLE)
-- =============================================================

-- 1. Average Resolution Time by Priority
-- Fix: Used EXTRACT to convert INTERVAL to NUMBER
SELECT
    t.priority,
    COUNT(*) AS total_resolved,
    ROUND(AVG(
        EXTRACT(DAY FROM (t.resolved_at - t.created_at)) * 24 +
        EXTRACT(HOUR FROM (t.resolved_at - t.created_at)) +
        EXTRACT(MINUTE FROM (t.resolved_at - t.created_at)) / 60
    ), 2) AS avg_hrs,
    ROUND(MIN(
        EXTRACT(DAY FROM (t.resolved_at - t.created_at)) * 24 +
        EXTRACT(HOUR FROM (t.resolved_at - t.created_at))
    ), 2) AS min_hrs,
    ROUND(MAX(
        EXTRACT(DAY FROM (t.resolved_at - t.created_at)) * 24 +
        EXTRACT(HOUR FROM (t.resolved_at - t.created_at))
    ), 2) AS max_hrs
FROM tickets t
WHERE t.resolved_at IS NOT NULL
GROUP BY t.priority
ORDER BY 
    CASE t.priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END;

-- 2. Technician Leaderboard (Resolutions vs CSAT)
SELECT
    u.full_name,
    COUNT(t.ticket_id)                                 AS tickets_resolved,
    ROUND(AVG(cs.score), 2)                            AS avg_csat,
    RANK() OVER (ORDER BY COUNT(t.ticket_id) DESC)     AS resolution_rank
FROM users u
JOIN tickets t ON t.assigned_to = u.user_id
LEFT JOIN csat_scores cs ON cs.ticket_id = t.ticket_id
WHERE u.role = 'technician' 
  AND t.status IN ('resolved', 'closed')
GROUP BY u.user_id, u.full_name
ORDER BY tickets_resolved DESC;

-- 3. SLA Breach Rate per Company
WITH resolved_counts AS (
    SELECT company_id, priority, COUNT(*) AS total_resolved
    FROM tickets WHERE status IN ('resolved', 'closed')
    GROUP BY company_id, priority
),
breach_counts AS (
    SELECT t.company_id, t.priority, COUNT(sb.breach_id) AS total_breaches
    FROM tickets t
    JOIN sla_breaches sb ON sb.ticket_id = t.ticket_id
    GROUP BY t.company_id, t.priority
)
SELECT
    c.company_name,
    rc.priority,
    rc.total_resolved,
    NVL(bc.total_breaches, 0) AS total_breaches,
    ROUND(NVL(bc.total_breaches, 0) / NULLIF(rc.total_resolved, 0) * 100, 1) AS breach_pct
FROM resolved_counts rc
JOIN companies c ON c.company_id = rc.company_id
LEFT JOIN breach_counts bc ON bc.company_id = rc.company_id AND bc.priority = rc.priority
ORDER BY breach_pct DESC;

-- 4. Monthly Ticket Volume Trend
SELECT
    TO_CHAR(created_at, 'YYYY-MM') AS month,
    COUNT(*) AS total_tickets,
    SUM(CASE WHEN priority IN ('critical','high') THEN 1 ELSE 0 END) AS urgent_tickets,
    ROUND(SUM(CASE WHEN priority IN ('critical','high') THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100, 1) AS urgent_pct,
    COUNT(*) - LAG(COUNT(*)) OVER (ORDER BY TO_CHAR(created_at, 'YYYY-MM')) AS mom_change
FROM tickets
GROUP BY TO_CHAR(created_at, 'YYYY-MM')
ORDER BY month;

-- 5. First-Response Time Distribution
-- Fix: Conversion from interval to numeric hours
WITH first_response AS (
    SELECT tc.ticket_id, MIN(tc.created_at) AS first_comment_at
    FROM ticket_comments tc
    JOIN users u ON u.user_id = tc.author_id AND u.role = 'technician'
    GROUP BY tc.ticket_id
),
response_gaps AS (
    SELECT t.ticket_id, 
    (EXTRACT(DAY FROM (fr.first_comment_at - t.created_at)) * 24 +
     EXTRACT(HOUR FROM (fr.first_comment_at - t.created_at))) AS response_hrs
    FROM tickets t
    JOIN first_response fr ON fr.ticket_id = t.ticket_id
)
SELECT
    CASE WHEN response_hrs <= 1 THEN '<=1 hr'
         WHEN response_hrs <= 4 THEN '1-4 hrs'
         WHEN response_hrs <= 24 THEN '4-24 hrs'
         ELSE '>24 hrs' END AS bucket,
    COUNT(*) AS ticket_count,
    ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 1) AS pct
FROM response_gaps
GROUP BY 
    CASE WHEN response_hrs <= 1 THEN '<=1 hr' 
         WHEN response_hrs <= 4 THEN '1-4 hrs' 
         WHEN response_hrs <= 24 THEN '4-24 hrs' 
         ELSE '>24 hrs' END;

-- 6. Top 10 Longest Resolving Categories
SELECT category, COUNT(*) AS total,
    ROUND(AVG(
        EXTRACT(DAY FROM (resolved_at - created_at)) * 24 +
        EXTRACT(HOUR FROM (resolved_at - created_at))
    ), 2) AS avg_hrs
FROM tickets
WHERE resolved_at IS NOT NULL
GROUP BY category
ORDER BY avg_hrs DESC
FETCH FIRST 10 ROWS ONLY;

-- 7. Reopen Rate by Technician
WITH reopened AS (
    SELECT DISTINCT ticket_id FROM ticket_status_history WHERE new_status = 'reopened'
)
SELECT u.full_name, COUNT(t.ticket_id) AS total_resolved, COUNT(r.ticket_id) AS reopened_count,
    ROUND(COUNT(r.ticket_id) / NULLIF(COUNT(t.ticket_id), 0) * 100, 1) AS reopen_rate
FROM users u
JOIN tickets t ON t.assigned_to = u.user_id
LEFT JOIN reopened r ON r.ticket_id = t.ticket_id
WHERE u.role = 'technician'
GROUP BY u.user_id, u.full_name
ORDER BY reopen_rate DESC;

-- 8. KB Article Effectiveness
SELECT
    CASE WHEN kb_ref.ticket_id IS NOT NULL THEN 'With KB' ELSE 'Without KB' END AS kb_status,
    COUNT(t.ticket_id) AS total,
    ROUND(AVG(
        EXTRACT(DAY FROM (t.resolved_at - t.created_at)) * 24 +
        EXTRACT(HOUR FROM (t.resolved_at - t.created_at))
    ), 2) AS avg_res_hrs
FROM tickets t
LEFT JOIN (SELECT DISTINCT ticket_id FROM ticket_kb_references) kb_ref ON kb_ref.ticket_id = t.ticket_id
WHERE t.resolved_at IS NOT NULL
GROUP BY CASE WHEN kb_ref.ticket_id IS NOT NULL THEN 'With KB' ELSE 'Without KB' END;

-- 9. Cumulative Tickets Resolved (Running Total)
SELECT u.full_name, TRUNC(t.resolved_at, 'MM') AS res_month,
    COUNT(t.ticket_id) AS monthly_resolved,
    SUM(COUNT(t.ticket_id)) OVER (PARTITION BY u.user_id ORDER BY TRUNC(t.resolved_at, 'MM')) AS running_total
FROM tickets t
JOIN users u ON u.user_id = t.assigned_to
WHERE t.status IN ('resolved', 'closed') AND t.resolved_at IS NOT NULL
GROUP BY u.user_id, u.full_name, TRUNC(t.resolved_at, 'MM')
ORDER BY u.full_name, res_month;

-- 10. Priority vs Resolution Time Correlation
-- Fix: Extract numeric hours before calculation
SELECT
    ROUND((COUNT(*) * SUM(p_val * res_hrs) - SUM(p_val) * SUM(res_hrs)) /
    NULLIF(SQRT((COUNT(*) * SUM(p_val * p_val) - POWER(SUM(p_val), 2)) *
         (COUNT(*) * SUM(res_hrs * res_hrs) - POWER(SUM(res_hrs), 2))), 0), 4) AS correlation
FROM (
    SELECT 
        (EXTRACT(DAY FROM (resolved_at - created_at)) * 24 +
         EXTRACT(HOUR FROM (resolved_at - created_at))) AS res_hrs,
        CASE priority WHEN 'low' THEN 1 WHEN 'medium' THEN 2 WHEN 'high' THEN 3 WHEN 'critical' THEN 4 END AS p_val
    FROM tickets WHERE resolved_at IS NOT NULL
);

-- 11. CSAT Score Percentiles by Company
SELECT c.company_name,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY cs.score), 2) AS median_csat,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY cs.score), 2) AS p95_csat,
    COUNT(cs.score) AS feedback_count
FROM csat_scores cs
JOIN tickets t ON t.ticket_id = cs.ticket_id
JOIN companies c ON c.company_id = t.company_id
GROUP BY c.company_name;

-- 12. Historical Backlog Trend
SELECT snapshot_date, company_id, open_tickets, solved_today, avg_handle_time_hrs
FROM ticket_daily_snapshot
ORDER BY snapshot_date DESC, company_id;

-- 13. Tag Co-occurrence
SELECT t1.tag_name AS tag_a, t2.tag_name AS tag_b, COUNT(*) AS occurrences
FROM ticket_tags tt1
JOIN ticket_tags tt2 ON tt2.ticket_id = tt1.ticket_id AND tt2.tag_id > tt1.tag_id
JOIN tags t1 ON t1.tag_id = tt1.tag_id
JOIN tags t2 ON t2.tag_id = tt2.tag_id
GROUP BY t1.tag_name, t2.tag_name
ORDER BY occurrences DESC 
FETCH FIRST 10 ROWS ONLY;

-- 14. Technician Workload Imbalance (Z-Score)
WITH load AS (
    SELECT u.full_name, COUNT(t.ticket_id) AS open_count
    FROM users u
    LEFT JOIN tickets t ON t.assigned_to = u.user_id AND t.status IN ('open', 'in_progress')
    WHERE u.role = 'technician' GROUP BY u.full_name
)
SELECT full_name, open_count,
    ROUND((open_count - AVG(open_count) OVER()) / NULLIF(STDDEV(open_count) OVER(), 0), 2) AS workload_z_score
FROM load
ORDER BY workload_z_score DESC;

-- 15. Execution Plan
-- Fix: Corrected query to avoid the same ORA-00932 inside explain
EXPLAIN PLAN FOR
SELECT priority, 
       AVG(EXTRACT(DAY FROM (resolved_at - created_at))*24 + EXTRACT(HOUR FROM (resolved_at - created_at))) 
FROM tickets
WHERE resolved_at IS NOT NULL 
GROUP BY priority;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
