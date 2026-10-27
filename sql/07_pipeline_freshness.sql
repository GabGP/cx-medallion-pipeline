-- Confirm the scheduled refresh ran: last build time and row counts per layer.

SELECT 'silver.calls' AS table_name, MAX(processed_at) AS last_built, COUNT(*) AS row_count
FROM `cx-medallion-gagp.silver.calls`
UNION ALL
SELECT 'gold.call_metrics_monthly', MAX(refreshed_at), SUM(calls)
FROM `cx-medallion-gagp.gold.call_metrics_monthly`;
