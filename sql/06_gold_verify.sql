-- Verify gold against independently computed expectations.
-- Expected: 1248 fact rows, 71028 calls, CSAT 6.88, 12 months,
-- Nov MoM +0.1233, worst-CSAT reason = Billing Issue (4.67).

SELECT 'fact rows' AS metric, CAST(COUNT(*) AS STRING) AS value
FROM `cx-medallion-gagp.gold.call_metrics_monthly`
UNION ALL
SELECT 'fact total calls', CAST(SUM(calls) AS STRING)
FROM `cx-medallion-gagp.gold.call_metrics_monthly`
UNION ALL
SELECT 'overall avg CSAT', CAST(ROUND(SAFE_DIVIDE(SUM(csat_sum), SUM(csat_responses)), 2) AS STRING)
FROM `cx-medallion-gagp.gold.call_metrics_monthly`
UNION ALL
SELECT 'months in kpi_monthly', CAST(COUNT(*) AS STRING)
FROM `cx-medallion-gagp.gold.kpi_monthly`
UNION ALL
SELECT 'Nov calls MoM %', CAST(calls_mom_pct AS STRING)
FROM `cx-medallion-gagp.gold.kpi_monthly` WHERE call_month = DATE '2024-11-01'
UNION ALL
SELECT 'worst-CSAT reason', CONCAT(call_reason, ' (', CAST(avg_csat AS STRING), ')')
FROM `cx-medallion-gagp.gold.contact_reason_scorecard` WHERE csat_rank_worst_first = 1;
