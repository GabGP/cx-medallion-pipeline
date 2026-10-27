-- Bronze: external table over the landing bucket.
-- Stores nothing itself; reads every CSV under raw/call_center/ in place.
-- All columns are STRING (values untouched); typing happens in silver.

CREATE OR REPLACE EXTERNAL TABLE `cx-medallion-gagp.bronze.call_center_raw` (
  call_id STRING,
  call_timestamp STRING,
  call_type STRING,
  call_duration_min STRING,
  call_reason STRING,
  resolution_status STRING,
  csat_score STRING,
  first_call_resolution STRING,
  agent_id STRING,
  agent_name STRING,
  agent_tenure_months STRING,
  skill_level STRING,
  languages STRING,
  team STRING,
  customer_id STRING,
  customer_location STRING,
  customer_type STRING,
  account_age_days STRING,
  contact_channel STRING,
  day_of_week STRING,
  hour_of_day STRING,
  queue_wait_time_min STRING,
  call_transfer_count STRING,
  sentiment_score STRING,
  escalation_level STRING,
  callback_requested STRING,
  dropped_call STRING,
  hold_time_min STRING
)
OPTIONS (
  format = 'CSV',
  uris = ['gs://cx-medallion-gagp-landing/raw/call_center/*.csv'],
  skip_leading_rows = 1,
  description = 'Bronze: raw call-center CSVs read in place from the landing bucket. All columns STRING, values untouched.'
);
