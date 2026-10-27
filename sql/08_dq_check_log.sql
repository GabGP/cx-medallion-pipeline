-- Optional: daily data-quality log (scheduled query: daily_dq_checks, 06:15 America/Guatemala).
-- Destination: silver.dq_check_log, write preference: Append to table.

SELECT CURRENT_TIMESTAMP() AS checked_at, *
FROM (
  WITH b AS (
    SELECT
      COUNT(*) AS bronze_rows,
      COUNTIF(SAFE_CAST(hour_of_day AS INT64)
              != EXTRACT(HOUR FROM SAFE.PARSE_DATETIME('%m/%d/%Y %I:%M:%S %p', call_timestamp))) AS source_hour_mismatches
    FROM `cx-medallion-gagp.bronze.call_center_raw`
  ),
  s AS (
    SELECT
      COUNT(*)                                                AS silver_rows,
      COUNT(*) - COUNT(DISTINCT call_id)                      AS duplicate_ids,
      COUNTIF(call_datetime IS NULL)                          AS null_timestamps,
      COUNTIF(csat_score IS NULL)                             AS null_csat,
      COUNTIF(csat_score NOT BETWEEN 1 AND 10)                AS csat_out_of_range,
      COUNTIF(call_duration_min < 0 OR queue_wait_min < 0 OR hold_time_min < 0) AS negative_times,
      COUNTIF(dq_fcr_conflict)                                AS fcr_conflicts
    FROM `cx-medallion-gagp.silver.calls`
  )
  SELECT 1 AS n, 'Row count matches bronze'            AS check_name, b.bronze_rows AS expected, s.silver_rows AS actual,
         IF(s.silver_rows = b.bronze_rows, 'PASS', 'FAIL') AS status FROM b, s
  UNION ALL SELECT 2, 'No duplicate call IDs',            0, s.duplicate_ids,     IF(s.duplicate_ids = 0, 'PASS', 'FAIL')     FROM s
  UNION ALL SELECT 3, 'No null timestamps',               0, s.null_timestamps,   IF(s.null_timestamps = 0, 'PASS', 'FAIL')   FROM s
  UNION ALL SELECT 4, 'No null CSAT scores',              0, s.null_csat,         IF(s.null_csat = 0, 'PASS', 'FAIL')         FROM s
  UNION ALL SELECT 5, 'CSAT within 1-10',                 0, s.csat_out_of_range, IF(s.csat_out_of_range = 0, 'PASS', 'FAIL') FROM s
  UNION ALL SELECT 6, 'No negative durations',            0, s.negative_times,    IF(s.negative_times = 0, 'PASS', 'FAIL')    FROM s
  UNION ALL SELECT 7, 'FCR flagged but escalated (info)', 0, s.fcr_conflicts,     IF(s.fcr_conflicts = 0, 'PASS', 'WARN')     FROM s
  UNION ALL SELECT 8, 'Source hour vs timestamp (info)',  0, b.source_hour_mismatches, IF(b.source_hour_mismatches = 0, 'PASS', 'WARN') FROM b
  ORDER BY n
);
