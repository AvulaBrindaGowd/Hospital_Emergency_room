-- ---------------------------------------------------------------------
-- A. SETUP: create the database and table, then import your CSV
-- ---------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS hospital_er;
USE hospital_er;

-- =====================================================================
-- STEP 1: CLEAN THE TABLE 
-- =====================================================================
USE hospital_er;
SET SQL_SAFE_UPDATES = 0;

-- 1a. Rename the first column (the one shown as "ï»¿Patient Id").
--     This looks up its exact name automatically, so no copy/paste needed.
SET @old = (
    SELECT COLUMN_NAME
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'hospital_er'
      AND TABLE_NAME   = 'hospital_er_data'
      AND ORDINAL_POSITION = 1
);
SET @sql = CONCAT('ALTER TABLE hospital_er_data CHANGE `', @old, '` patient_id VARCHAR(20)');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 1b. Rename the other columns to clean names
ALTER TABLE hospital_er_data
    RENAME COLUMN `Patient Admission Date`   TO patient_admin_date,
    RENAME COLUMN `Patient First Inital`     TO patient_first_initial,
    RENAME COLUMN `Patient Last Name`        TO patient_last_name,
    RENAME COLUMN `Patient Gender`           TO patient_gender,
    RENAME COLUMN `Patient Age`              TO patient_age,
    RENAME COLUMN `Patient Race`             TO patient_race,
    RENAME COLUMN `Department Referral`      TO department_referral,
    RENAME COLUMN `Patient Admission Flag`   TO patient_admission_flag,
    RENAME COLUMN `Patient Satisfaction Score` TO patient_satisfaction_score,
    RENAME COLUMN `Patient Waittime`         TO patient_waittime,
    RENAME COLUMN `Patients CM`              TO patients_cm;

-- 1c. Check the result
DESCRIBE hospital_er_data;

-- =====================================================================
-- STEP 2: FIX THE DATE (it is stored as text)
-- First LOOK at the raw values and test the format:
-- =====================================================================
SELECT patient_admin_date,
       STR_TO_DATE(patient_admin_date, '%d-%m-%Y %H:%i') AS parsed
FROM hospital_er_data
LIMIT 10;
-- If "parsed" is NULL, your format is different. Common alternatives:
--   '%d/%m/%Y %H:%i'   '%m/%d/%Y %H:%i'   '%Y-%m-%d %H:%i:%s'
-- Change the format string below to match, then run:

ALTER TABLE hospital_er_data ADD COLUMN patient_admin_dt DATETIME;

UPDATE hospital_er_data
SET patient_admin_dt = STR_TO_DATE(patient_admin_date, '%d-%m-%Y %H:%i');

-- Should return 0 (rows that failed to convert):
SELECT COUNT(*) AS failed_dates
FROM hospital_er_data
WHERE patient_admin_dt IS NULL;

-- =====================================================================
-- STEP 3: FIX THE SATISFACTION SCORE (stored as text, may contain blanks)
-- =====================================================================
UPDATE hospital_er_data
SET patient_satisfaction_score = NULL
WHERE TRIM(patient_satisfaction_score) = '';

ALTER TABLE hospital_er_data
    MODIFY patient_satisfaction_score DECIMAL(4,1) NULL;

-- =====================================================================
-- STEP 4: LOOK AT THE CODES USED IN YOUR DATA
-- (the analysis script needs to know these)
-- =====================================================================
SELECT DISTINCT patient_admission_flag FROM hospital_er_data;
SELECT DISTINCT department_referral    FROM hospital_er_data;
