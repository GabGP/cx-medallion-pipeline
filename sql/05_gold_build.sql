-- Gold: reporting tables for the dashboard.
-- Scheduled daily at 06:30 America/Guatemala (scheduled query: daily_gold_build).
-- Runs as one script; statements execute in order.

-- 1) Gold fact: additive monthly metrics at the grain the dashboard filters on
CREATE OR REPLACE TABLE `cx-medallion-gagp.gold.call_metrics_monthly`
OPTIONS (description = 'Gold fact: monthly call metrics by team, channel, call type and reason. Additive sums and counts only; ratios are computed at report time.')
AS
SELECT
  call_month,
  team,
  contact_channel,
  call_type,
  call_reason,
  COUNT(*)                          AS calls,
  COUNT(csat_score)                 AS csat_responses,
  SUM(csat_score)                   AS csat_sum,
  COUNTIF(csat_score >= 9)          AS csat_top2_responses,
  COUNTIF(resolved_first_contact)   AS resolved_first_contact_calls,
  COUNTIF(first_call_resolution)    AS fcr_flagged_calls,
  COUNTIF(is_escalated)             AS escalated_calls,
  COUNTIF(dropped_call)             AS dropped_calls,
  COUNTIF(callback_requested)       AS callback_calls,
  COUNTIF(queue_wait_min <= 1)      AS answered_within_1_min_calls,
  SUM(transfer_count)               AS transfers,
  SUM(call_duration_min)            AS call_duration_min_sum,
  SUM(queue_wait_min)               AS queue_wait_min_sum,
  SUM(hold_time_min)                AS hold_time_min_sum,
  SUM(sentiment_score)              AS sentiment_sum,
  COUNT(sentiment_score)            AS sentiment_responses,
  CURRENT_TIMESTAMP()               AS refreshed_at
FROM `cx-medallion-gagp.silver.calls`
GROUP BY call_month, team, contact_channel, call_type, call_reason;

-- 2) Gold KPI summary: one row per month, headline KPIs + month-over-month change
CREATE OR REPLACE TABLE `cx-medallion-gagp.gold.kpi_monthly`
OPTIONS (description = 'Gold: one row per month with headline contact-center KPIs and month-over-month change.')
AS
WITH m AS (
  SELECT
    call_month,
    SUM(calls)                        AS calls,
    SUM(csat_sum)                     AS csat_sum,
    SUM(csat_responses)               AS csat_responses,
    SUM(csat_top2_responses)          AS csat_top2,
    SUM(resolved_first_contact_calls) AS rfc,
    SUM(escalated_calls)              AS esc,
    SUM(dropped_calls)                AS dropped,
    SUM(answered_within_1_min_calls)  AS sl,
    SUM(call_duration_min_sum)        AS dur,
    SUM(queue_wait_min_sum)           AS wait,
    SUM(hold_time_min_sum)            AS hold
  FROM `cx-medallion-gagp.gold.call_metrics_monthly`
  GROUP BY call_month
),
k AS (
  SELECT
    call_month,
    calls,
    ROUND(SAFE_DIVIDE(csat_sum, csat_responses), 2)  AS avg_csat,
    ROUND(SAFE_DIVIDE(csat_top2, csat_responses), 4) AS csat_top2_rate,
    ROUND(SAFE_DIVIDE(rfc, calls), 4)                AS fcr_rate,
    ROUND(SAFE_DIVIDE(esc, calls), 4)                AS escalation_rate,
    ROUND(SAFE_DIVIDE(dropped, calls), 4)            AS dropped_rate,
    ROUND(SAFE_DIVIDE(sl, calls), 4)                 AS service_level_1min,
    ROUND(SAFE_DIVIDE(dur, calls), 2)                AS avg_call_duration_min,
    ROUND(SAFE_DIVIDE(wait, calls), 2)               AS avg_queue_wait_min,
    ROUND(SAFE_DIVIDE(hold, calls), 2)               AS avg_hold_min
  FROM m
)
SELECT
  k.*,
  ROUND(SAFE_DIVIDE(calls - LAG(calls) OVER w, LAG(calls) OVER w), 4) AS calls_mom_pct,
  ROUND(avg_csat - LAG(avg_csat) OVER w, 2)                           AS avg_csat_mom_change,
  ROUND(fcr_rate - LAG(fcr_rate) OVER w, 4)                           AS fcr_rate_mom_change,
  CURRENT_TIMESTAMP()                                                 AS refreshed_at
FROM k
WINDOW w AS (ORDER BY call_month);

-- 3) Gold contact-reason scorecard: full period, ranked, compared with overall
CREATE OR REPLACE TABLE `cx-medallion-gagp.gold.contact_reason_scorecard`
OPTIONS (description = 'Gold: full-period scorecard per contact reason, ranked by volume and by CSAT, compared with the overall average.')
AS
WITH r AS (
  SELECT
    team,
    call_reason,
    SUM(calls)                        AS calls,
    SUM(csat_sum)                     AS csat_sum,
    SUM(csat_responses)               AS csat_responses,
    SUM(resolved_first_contact_calls) AS rfc,
    SUM(escalated_calls)              AS esc,
    SUM(call_duration_min_sum)        AS dur,
    SUM(queue_wait_min_sum)           AS wait,
    SUM(hold_time_min_sum)            AS hold
  FROM `cx-medallion-gagp.gold.call_metrics_monthly`
  GROUP BY team, call_reason
),
overall AS (
  SELECT SAFE_DIVIDE(SUM(csat_sum), SUM(csat_responses)) AS avg_csat_all
  FROM r
)
SELECT
  r.team,
  r.call_reason,
  r.calls,
  ROUND(SAFE_DIVIDE(r.calls, SUM(r.calls) OVER ()), 4)                          AS share_of_calls,
  RANK() OVER (ORDER BY r.calls DESC)                                           AS volume_rank,
  ROUND(SAFE_DIVIDE(r.csat_sum, r.csat_responses), 2)                           AS avg_csat,
  ROUND(SAFE_DIVIDE(r.csat_sum, r.csat_responses) - o.avg_csat_all, 2)          AS csat_vs_overall,
  RANK() OVER (ORDER BY SAFE_DIVIDE(r.csat_sum, r.csat_responses) ASC)          AS csat_rank_worst_first,
  ROUND(SAFE_DIVIDE(r.rfc, r.calls), 4)                                         AS fcr_rate,
  ROUND(SAFE_DIVIDE(r.esc, r.calls), 4)                                         AS escalation_rate,
  ROUND(SAFE_DIVIDE(r.dur, r.calls), 2)                                         AS avg_call_duration_min,
  ROUND(SAFE_DIVIDE(r.hold, r.calls), 2)                                        AS avg_hold_min,
  ROUND(SAFE_DIVIDE(r.wait, r.calls), 2)                                        AS avg_queue_wait_min,
  CURRENT_TIMESTAMP()                                                           AS refreshed_at
FROM r
CROSS JOIN overall AS o;
