-- Silver: typed, trimmed, deduplicated call records with data-quality flags and lineage.
-- Scheduled daily at 06:00 America/Guatemala (scheduled query: daily_silver_build).
--
-- Rules
--   * Types: STRING -> INT64 / FLOAT64 / BOOL / DATETIME via SAFE casts
--   * Trim every text value; empty strings become NULL
--   * Reject rows without call_id or a parseable timestamp
--   * Non-key nulls stay NULL (no imputation)
--   * One row per call_id; the latest ingest_date wins
--   * Hour/weekday derived from the timestamp (source hour_of_day is wrong in the
--     March 10 DST gap), strict FCR + conflict flag, normalized agent languages

CREATE OR REPLACE TABLE `cx-medallion-gagp.silver.calls`
PARTITION BY call_date
CLUSTER BY team, contact_channel
OPTIONS (description = 'Silver: typed, trimmed, deduplicated call records with data-quality flags and lineage.')
AS
WITH src AS (
  SELECT *, _FILE_NAME AS source_file
  FROM `cx-medallion-gagp.bronze.call_center_raw`
),
typed AS (
  SELECT
    NULLIF(TRIM(call_id), '')                                            AS call_id,
    SAFE.PARSE_DATETIME('%m/%d/%Y %I:%M:%S %p', TRIM(call_timestamp))    AS call_datetime,
    NULLIF(TRIM(call_type), '')                                          AS call_type,
    NULLIF(TRIM(contact_channel), '')                                    AS contact_channel,
    NULLIF(TRIM(call_reason), '')                                        AS call_reason,
    NULLIF(TRIM(team), '')                                               AS team,
    NULLIF(TRIM(resolution_status), '')                                  AS resolution_status,
    NULLIF(TRIM(escalation_level), '')                                   AS escalation_level,
    SAFE_CAST(TRIM(csat_score) AS INT64)                                 AS csat_score,
    CASE LOWER(TRIM(first_call_resolution)) WHEN 'true' THEN TRUE WHEN 'false' THEN FALSE END AS first_call_resolution,
    CASE LOWER(TRIM(callback_requested))    WHEN 'true' THEN TRUE WHEN 'false' THEN FALSE END AS callback_requested,
    CASE LOWER(TRIM(dropped_call))          WHEN 'true' THEN TRUE WHEN 'false' THEN FALSE END AS dropped_call,
    SAFE_CAST(TRIM(call_duration_min) AS INT64)                          AS call_duration_min,
    SAFE_CAST(TRIM(queue_wait_time_min) AS INT64)                        AS queue_wait_min,
    SAFE_CAST(TRIM(hold_time_min) AS INT64)                              AS hold_time_min,
    SAFE_CAST(TRIM(call_transfer_count) AS INT64)                        AS transfer_count,
    SAFE_CAST(TRIM(sentiment_score) AS FLOAT64)                          AS sentiment_score,
    NULLIF(TRIM(agent_id), '')                                           AS agent_id,
    NULLIF(TRIM(agent_name), '')                                         AS agent_name,
    SAFE_CAST(TRIM(agent_tenure_months) AS INT64)                        AS agent_tenure_months,
    NULLIF(TRIM(skill_level), '')                                        AS skill_level,
    (SELECT STRING_AGG(TRIM(l), ', ' ORDER BY TRIM(l))
       FROM UNNEST(SPLIT(languages, ',')) AS l)                          AS agent_languages,
    ARRAY_LENGTH(SPLIT(languages, ','))                                  AS agent_language_count,
    NULLIF(TRIM(customer_id), '')                                        AS customer_id,
    NULLIF(TRIM(customer_type), '')                                      AS customer_type,
    SAFE_CAST(TRIM(account_age_days) AS INT64)                           AS account_age_days,
    NULLIF(TRIM(customer_location), '')                                  AS customer_location,
    source_file,
    SAFE.PARSE_DATE('%Y-%m-%d', REGEXP_EXTRACT(source_file, r'ingest_date=(\d{4}-\d{2}-\d{2})')) AS ingest_date
  FROM src
),
deduped AS (
  SELECT *
  FROM typed
  WHERE call_id IS NOT NULL
    AND call_datetime IS NOT NULL
  QUALIFY ROW_NUMBER() OVER (PARTITION BY call_id ORDER BY ingest_date DESC, source_file DESC) = 1
)
SELECT
  call_id,
  call_datetime,
  DATE(call_datetime)                              AS call_date,
  DATE_TRUNC(DATE(call_datetime), MONTH)           AS call_month,
  EXTRACT(HOUR FROM call_datetime)                 AS call_hour,
  FORMAT_DATETIME('%A', call_datetime)             AS day_of_week,
  call_type,
  contact_channel,
  call_reason,
  team,
  resolution_status,
  escalation_level,
  resolution_status = 'Escalated'                  AS is_escalated,
  csat_score,
  first_call_resolution,
  COALESCE(first_call_resolution, FALSE) AND resolution_status = 'Resolved' AS resolved_first_contact,
  COALESCE(first_call_resolution, FALSE) AND resolution_status = 'Escalated' AS dq_fcr_conflict,
  callback_requested,
  dropped_call,
  call_duration_min,
  queue_wait_min,
  hold_time_min,
  transfer_count,
  sentiment_score,
  agent_id,
  agent_name,
  agent_tenure_months,
  skill_level,
  agent_languages,
  agent_language_count,
  customer_id,
  customer_type,
  account_age_days,
  customer_location,
  source_file,
  ingest_date,
  CURRENT_TIMESTAMP()                              AS processed_at
FROM deduped;
