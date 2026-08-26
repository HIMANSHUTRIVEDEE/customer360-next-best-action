-- =============================================================================
-- sql/01_raw/02_stage_file_format.sql
-- Purpose: Create internal stage and CSV file format for data loading
-- Administrative role required: C360_DATA_ENGINEER (RAW schema owner)
-- Idempotent: Uses CREATE OR REPLACE
-- =============================================================================

USE DATABASE CUSTOMER360_DB;
USE SCHEMA RAW;

-- =============================================================================
-- File format: CSV with UTF-8 encoding, header row skipped
-- =============================================================================
CREATE OR REPLACE FILE FORMAT RAW.CSV_LOAD_FORMAT
    TYPE = 'CSV'
    COMPRESSION = 'NONE'
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE = FALSE
    NULL_IF = ('')
    EMPTY_FIELD_AS_NULL = TRUE
    ENCODING = 'UTF8'
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'CSV format for synthetic data load. UTF-8, comma-delimited, header skipped, empty = NULL, strict column count.';

-- =============================================================================
-- Internal stage: landing area for generated CSV files
-- =============================================================================
CREATE OR REPLACE STAGE RAW.C360_LOAD_STAGE
    FILE_FORMAT = RAW.CSV_LOAD_FORMAT
    COMMENT = 'Internal stage for Customer360 synthetic data CSVs. Used by COPY INTO during setup.';
