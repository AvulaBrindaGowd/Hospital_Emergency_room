-- =====================================================================
-- HOSPITAL EMERGENCY ROOM ANALYSIS (MySQL 8.0+)
-- Run 01_fix_table_mysql.sql first.
-- =====================================================================
USE hospital_er;

-- ---------------------------------------------------------------------
-- 0. CLEAN VIEW
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_er AS
SELECT
    patient_id,
    patient_admin_dt                                        AS admit_dt,
    DATE(patient_admin_dt)                                  AS admit_date,
    HOUR(patient_admin_dt)                                  AS admit_hour,
    CONCAT(patient_first_initial, ' ', patient_last_name)   AS patient_full_name,
    patient_gender,
    patient_age,
    patient_race,
    CASE WHEN department_referral IS NULL
              OR TRIM(department_referral) IN ('', 'None')
         THEN 'No referral'
         ELSE TRIM(department_referral) END                 AS department_referral,
    CASE WHEN UPPER(TRIM(patient_admission_flag)) IN ('TRUE', '1', 'YES', 'ADMITTED')
         THEN 'Admitted' ELSE 'Not Admitted' END            AS admission_status,
    patient_satisfaction_score,
    patient_waittime
FROM hospital_er_data;


-- ---------------------------------------------------------------------
-- 1. DATA QUALITY CHECKS
-- ---------------------------------------------------------------------
SELECT
    COUNT(*)                                AS total_rows,
    COUNT(DISTINCT patient_id)              AS unique_patients,
    MIN(admit_date)                         AS first_date,
    MAX(admit_date)                         AS last_date,
    SUM(patient_waittime IS NULL)           AS missing_waittime,
    SUM(patient_satisfaction_score IS NULL) AS missing_score
FROM vw_er;

-- Duplicate patient IDs
SELECT patient_id, COUNT(*) AS n
FROM vw_er
GROUP BY patient_id
HAVING COUNT(*) > 1;


-- ---------------------------------------------------------------------
-- 2. HEADLINE KPIs 
-- ---------------------------------------------------------------------
SELECT
    COUNT(DISTINCT patient_id)                  AS number_of_patients,
    ROUND(AVG(patient_waittime), 1)             AS avg_wait_time_min,
    ROUND(AVG(patient_satisfaction_score), 2)   AS avg_satisfaction_score,
    SUM(department_referral IS NOT NULL)        AS patients_referred
FROM vw_er;

-- For a date range, add:  WHERE admit_date BETWEEN '2023-04-01' AND '2024-10-31'


-- ---------------------------------------------------------------------
-- 3. MONTHLY VIEW: KPIs by month
-- ---------------------------------------------------------------------
SELECT
    DATE_FORMAT(admit_date, '%Y-%m')            AS month_year,
    COUNT(DISTINCT patient_id)                  AS number_of_patients,
    ROUND(AVG(patient_waittime), 1)             AS avg_wait_time_min,
    ROUND(AVG(patient_satisfaction_score), 2)   AS avg_satisfaction_score,
    SUM(department_referral IS NOT NULL)        AS patients_referred
FROM vw_er
GROUP BY month_year
ORDER BY month_year;


-- ---------------------------------------------------------------------
-- 4. DAILY TRENDS 
-- ---------------------------------------------------------------------
SELECT
    admit_date,
    COUNT(DISTINCT patient_id)                  AS number_of_patients,
    ROUND(AVG(patient_waittime), 1)             AS avg_wait_time_min,
    ROUND(AVG(patient_satisfaction_score), 2)   AS avg_satisfaction_score,
    SUM(department_referral IS NOT NULL)        AS patients_referred
FROM vw_er
GROUP BY admit_date
ORDER BY admit_date;


-- ---------------------------------------------------------------------
-- 5. ADMISSION STATUS
-- ---------------------------------------------------------------------
SELECT
    admission_status,
    COUNT(*)                                            AS patients,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_total
FROM vw_er
GROUP BY admission_status
ORDER BY patients DESC;


-- ---------------------------------------------------------------------
-- 6. AGE DISTRIBUTION (10-year groups)
-- ---------------------------------------------------------------------
SELECT
    CONCAT(FLOOR(patient_age / 10) * 10, '-', FLOOR(patient_age / 10) * 10 + 9) AS age_group,
    COUNT(*)                                            AS patients
FROM vw_er
GROUP BY FLOOR(patient_age / 10), age_group
ORDER BY FLOOR(patient_age / 10);


-- ---------------------------------------------------------------------
-- 7. DEPARTMENT REFERRALS
-- ---------------------------------------------------------------------
SELECT
    COALESCE(department_referral, 'No referral')        AS department,
    COUNT(*)                                            AS patients,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)    AS pct_of_total
FROM vw_er
GROUP BY department
ORDER BY patients DESC;


-- ---------------------------------------------------------------------
-- 8. TIMELINESS: % of patients seen within 30 minutes
-- ---------------------------------------------------------------------
SELECT
    ROUND(100 * SUM(patient_waittime <= 30) / COUNT(*), 1) AS pct_seen_within_30_min
FROM vw_er
WHERE patient_waittime IS NOT NULL;

-- By month
SELECT
    DATE_FORMAT(admit_date, '%Y-%m')                    AS month_year,
    ROUND(100 * SUM(patient_waittime <= 30) / COUNT(*), 1) AS pct_seen_within_30_min
FROM vw_er
WHERE patient_waittime IS NOT NULL
GROUP BY month_year
ORDER BY month_year;


-- ---------------------------------------------------------------------
-- 9. GENDER AND RACE
-- ---------------------------------------------------------------------
SELECT patient_gender, COUNT(*) AS patients,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM vw_er
GROUP BY patient_gender
ORDER BY patients DESC;

SELECT patient_race, COUNT(*) AS patients,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_total
FROM vw_er
GROUP BY patient_race
ORDER BY patients DESC;


-- ---------------------------------------------------------------------
-- 10. TIME ANALYSIS: by day of week and by hour
-- ---------------------------------------------------------------------
SELECT DAYNAME(admit_date) AS day_name, COUNT(*) AS patients
FROM vw_er
GROUP BY day_name
ORDER BY patients DESC;

SELECT admit_hour, COUNT(*) AS patients
FROM vw_er
GROUP BY admit_hour
ORDER BY patients DESC;

-- Day x hour heatmap (Monday first)
SELECT
    WEEKDAY(admit_date) + 1                             AS day_number,
    DAYNAME(admit_date)                                 AS day_name,
    admit_hour,
    COUNT(*)                                            AS patients
FROM vw_er
GROUP BY day_number, day_name, admit_hour
ORDER BY day_number, admit_hour;


-- ---------------------------------------------------------------------
-- 11. WAIT-TIME INTERVALS BY DAY
-- ---------------------------------------------------------------------
SELECT
    DAYNAME(admit_date)                                 AS day_name,
    CASE
        WHEN patient_waittime <= 30 THEN '0-30 min'
        WHEN patient_waittime <= 60 THEN '31-60 min'
        ELSE '60+ min'
    END                                                 AS waiting_interval,
    COUNT(*)                                            AS patients
FROM vw_er
WHERE patient_waittime IS NOT NULL
GROUP BY day_name, waiting_interval
ORDER BY day_name, waiting_interval;


SELECT
    ROUND(100 * SUM(patient_waittime <= 30) / COUNT(*), 2) AS pct_seen_within_30_min
FROM vw_er
WHERE patient_waittime IS NOT NULL;
-- ---------------------------------------------------------------------
-- 12. PATIENT DETAILS GRID
-- ---------------------------------------------------------------------
SELECT
    patient_id, patient_full_name, patient_gender, patient_age,
    admit_dt, patient_race, patient_waittime,
    COALESCE(department_referral, 'None') AS department_referral,
    admission_status
FROM vw_er
ORDER BY admit_dt DESC;
