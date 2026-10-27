-- Profile bronze before building silver: completeness, uniqueness, castability.
-- Expected on the 2024 file: 71028 rows, 71028 distinct ids, 1 file, 0 bad values.

SELECT
  COUNT(*)                                   AS total_rows,
  COUNT(DISTINCT call_id)                    AS distinct_call_ids,
  COUNT(DISTINCT _FILE_NAME)                 AS source_files,
  COUNTIF(SAFE.PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', call_timestamp) IS NULL) AS unparseable_timestamps,
  MIN(SAFE.PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', call_timestamp))           AS first_call,
  MAX(SAFE.PARSE_TIMESTAMP('%m/%d/%Y %I:%M:%S %p', call_timestamp))           AS last_call,
  COUNTIF(SAFE_CAST(csat_score AS INT64) IS NULL)                             AS bad_csat_values,
  COUNTIF(first_call_resolution NOT IN ('True', 'False'))                     AS bad_fcr_values,
  COUNTIF(contact_channel = 'Phone')         AS phone_calls
FROM `cx-medallion-gagp.bronze.call_center_raw`;
