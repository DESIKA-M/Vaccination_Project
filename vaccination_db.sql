-- ============================================================================
-- VACCINATION DATA ANALYSIS - SQL DATABASE SCHEMA
-- ============================================================================
-- Database: vaccination_analysis
-- Purpose: Store cleaned vaccination, disease, and health data for analysis
-- ============================================================================

-- Create database
CREATE DATABASE IF NOT EXISTS vaccination_analysis;
USE vaccination_analysis;

-- ============================================================================
-- DIMENSION TABLES (Reference/Lookup Tables)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Dimension: Countries
-- Purpose: Central repository for all country information
-- ----------------------------------------------------------------------------
CREATE TABLE dim_countries (
    country_code VARCHAR(3) PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    who_region VARCHAR(10),
    group_classification VARCHAR(50),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_who_region (who_region),
    INDEX idx_country_name (country_name)
) COMMENT='Dimension table for country master data';

-- ----------------------------------------------------------------------------
-- Dimension: Years
-- Purpose: Date dimension for time-series analysis
-- ----------------------------------------------------------------------------
CREATE TABLE dim_years (
    year INT PRIMARY KEY,
    decade INT GENERATED ALWAYS AS (FLOOR(year / 10) * 10) STORED,
    is_modern_era BOOLEAN GENERATED ALWAYS AS (year >= 2000) STORED,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_decade (decade)
) COMMENT='Dimension table for temporal analysis';

-- ----------------------------------------------------------------------------
-- Dimension: Vaccines/Antigens
-- Purpose: Master list of all vaccine types
-- ----------------------------------------------------------------------------
CREATE TABLE dim_vaccines (
    antigen_code VARCHAR(50) PRIMARY KEY,
    antigen_description VARCHAR(200) NOT NULL,
    vaccine_family VARCHAR(100),
    is_routine BOOLEAN DEFAULT TRUE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_vaccine_family (vaccine_family)
) COMMENT='Dimension table for vaccine/antigen types';

-- ----------------------------------------------------------------------------
-- Dimension: Diseases
-- Purpose: Master list of all diseases tracked
-- ----------------------------------------------------------------------------
CREATE TABLE dim_diseases (
    disease_code VARCHAR(50) PRIMARY KEY,
    disease_description VARCHAR(200) NOT NULL,
    disease_category VARCHAR(100),
    severity_level VARCHAR(20),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_disease_category (disease_category)
) COMMENT='Dimension table for disease information';

-- ----------------------------------------------------------------------------
-- Dimension: Coverage Categories
-- Purpose: Types of coverage reporting
-- ----------------------------------------------------------------------------
CREATE TABLE dim_coverage_categories (
    category_code VARCHAR(20) PRIMARY KEY,
    category_description VARCHAR(200) NOT NULL,
    data_source VARCHAR(100),
    reliability_score DECIMAL(3,2),
    includes_admin_data BOOLEAN DEFAULT FALSE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) COMMENT='Dimension table for coverage category types';

-- ============================================================================
-- FACT TABLES (Transaction/Event Data)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Fact: Coverage Data
-- Purpose: Vaccination coverage statistics by country, year, vaccine, category
-- NOTE: Includes COVERAGE_CATEGORY in primary key due to multiple sources
-- ----------------------------------------------------------------------------
CREATE TABLE fact_coverage (
    -- Primary Key (4 columns required!)
    country_code VARCHAR(3) NOT NULL,
    year INT NOT NULL,
    antigen_code VARCHAR(50) NOT NULL,
    coverage_category VARCHAR(20) NOT NULL,
    
    -- Descriptive fields
    country_name VARCHAR(100),
    antigen_description VARCHAR(200),
    category_description VARCHAR(200),
    group_classification VARCHAR(50),
    
    -- Metrics
    target_number BIGINT,
    doses_administered BIGINT,
    coverage_percentage DECIMAL(5,2),
    
    -- Data quality flags
    has_admin_data BOOLEAN DEFAULT FALSE,
    data_completeness VARCHAR(20),
    
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Primary Key
    PRIMARY KEY (country_code, year, antigen_code, coverage_category),
    
    -- Foreign Keys
    FOREIGN KEY (country_code) REFERENCES dim_countries(country_code),
    FOREIGN KEY (year) REFERENCES dim_years(year),
    FOREIGN KEY (antigen_code) REFERENCES dim_vaccines(antigen_code),
    FOREIGN KEY (coverage_category) REFERENCES dim_coverage_categories(category_code),
    
    -- Indexes for performance
    INDEX idx_year (year),
    INDEX idx_country (country_code),
    INDEX idx_antigen (antigen_code),
    INDEX idx_category (coverage_category),
    INDEX idx_coverage_pct (coverage_percentage),
    INDEX idx_year_country (year, country_code),
    INDEX idx_has_admin (has_admin_data),
    
    -- Constraints
    CONSTRAINT chk_coverage_range CHECK (coverage_percentage >= 0 AND coverage_percentage <= 100),
    CONSTRAINT chk_target_positive CHECK (target_number IS NULL OR target_number >= 0),
    CONSTRAINT chk_doses_positive CHECK (doses_administered IS NULL OR doses_administered >= 0)
) COMMENT='Fact table for vaccination coverage data - PRIMARY KEY includes coverage_category!';


-- ----------------------------------------------------------------------------
-- Fact: Incidence Rate
-- Purpose: Disease incidence rates per population
-- ----------------------------------------------------------------------------
CREATE TABLE fact_incidence_rate (
    -- Primary Key
    country_code VARCHAR(3) NOT NULL,
    year INT NOT NULL,
    disease_code VARCHAR(50) NOT NULL,
    
    -- Descriptive fields
    country_name VARCHAR(100),
    disease_description VARCHAR(200),
    group_classification VARCHAR(50),
    
    -- Metrics
    denominator VARCHAR(50),
    incidence_rate DECIMAL(12,2),
    
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Primary Key
    PRIMARY KEY (country_code, year, disease_code),
    
    -- Foreign Keys
    FOREIGN KEY (country_code) REFERENCES dim_countries(country_code),
    FOREIGN KEY (year) REFERENCES dim_years(year),
    FOREIGN KEY (disease_code) REFERENCES dim_diseases(disease_code),
    
    -- Indexes
    INDEX idx_year (year),
    INDEX idx_country (country_code),
    INDEX idx_disease (disease_code),
    INDEX idx_incidence_rate (incidence_rate),
    INDEX idx_year_country (year, country_code),
    
    -- Constraints
    CONSTRAINT chk_incidence_positive CHECK (incidence_rate IS NULL OR incidence_rate >= 0)
) COMMENT='Fact table for disease incidence rates';

-- ----------------------------------------------------------------------------
-- Fact: Reported Cases
-- Purpose: Absolute number of disease cases reported
-- ----------------------------------------------------------------------------
CREATE TABLE fact_reported_cases (
    -- Primary Key
    country_code VARCHAR(3) NOT NULL,
    year INT NOT NULL,
    disease_code VARCHAR(50) NOT NULL,
    
    -- Descriptive fields
    country_name VARCHAR(100),
    disease_description VARCHAR(200),
    group_classification VARCHAR(50),
    
    -- Metrics
    cases_reported INT,
    
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Primary Key
    PRIMARY KEY (country_code, year, disease_code),
    
    -- Foreign Keys
    FOREIGN KEY (country_code) REFERENCES dim_countries(country_code),
    FOREIGN KEY (year) REFERENCES dim_years(year),
    FOREIGN KEY (disease_code) REFERENCES dim_diseases(disease_code),
    
    -- Indexes
    INDEX idx_year (year),
    INDEX idx_country (country_code),
    INDEX idx_disease (disease_code),
    INDEX idx_cases (cases_reported),
    INDEX idx_year_country (year, country_code),
    
    -- Constraints
    CONSTRAINT chk_cases_positive CHECK (cases_reported IS NULL OR cases_reported >= 0)
) COMMENT='Fact table for reported disease cases';

-- ----------------------------------------------------------------------------
-- Fact: Vaccine Introduction
-- Purpose: When vaccines were introduced in each country
-- ----------------------------------------------------------------------------
CREATE TABLE fact_vaccine_introduction (
    -- Primary Key
    country_code VARCHAR(3) NOT NULL,
    year INT NOT NULL,
    vaccine_name VARCHAR(100) NOT NULL,
    
    -- Descriptive fields
    country_name VARCHAR(100),
    who_region VARCHAR(10),
    intro_status VARCHAR(50),
    
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Primary Key
    PRIMARY KEY (country_code, year, vaccine_name),
    
    -- Foreign Keys
    FOREIGN KEY (country_code) REFERENCES dim_countries(country_code),
    FOREIGN KEY (year) REFERENCES dim_years(year),
    
    -- Indexes
    INDEX idx_year (year),
    INDEX idx_country (country_code),
    INDEX idx_vaccine (vaccine_name),
    INDEX idx_who_region (who_region),
    INDEX idx_intro_status (intro_status)
) COMMENT='Fact table for vaccine introduction timelines';

-- ----------------------------------------------------------------------------
-- Fact: Vaccine Schedule
-- Purpose: Vaccination schedules by country and target population
-- ----------------------------------------------------------------------------
CREATE TABLE fact_vaccine_schedule (
    -- Primary Key (5 columns required!)
    country_code VARCHAR(3) NOT NULL,
    year INT NOT NULL,
    vaccine_code VARCHAR(50) NOT NULL,
    schedule_round INT NOT NULL,
    target_population VARCHAR(50) NOT NULL,
    
    -- Descriptive fields
    country_name VARCHAR(100),
    vaccine_description VARCHAR(200),
    target_pop_description VARCHAR(200),
    who_region VARCHAR(10),
    geographic_area VARCHAR(50),
    age_administered VARCHAR(100),
    source_comment TEXT,
    
    -- Metadata
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Primary Key
    PRIMARY KEY (country_code, year, vaccine_code, schedule_round, target_population),
    
    -- Foreign Keys
    FOREIGN KEY (country_code) REFERENCES dim_countries(country_code),
    FOREIGN KEY (year) REFERENCES dim_years(year),
    
    -- Indexes
    INDEX idx_year (year),
    INDEX idx_country (country_code),
    INDEX idx_vaccine (vaccine_code),
    INDEX idx_target_pop (target_population),
    INDEX idx_who_region (who_region)
) COMMENT='Fact table for vaccination schedules';

-- ============================================================================
-- ANALYTICAL VIEWS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- View: Coverage with Admin Data Only
-- Purpose: Filter to records with actual dose administration data
-- Use For: Questions about actual vaccination doses administered
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_coverage_admin_data AS
SELECT 
    country_code,
    country_name,
    year,
    antigen_code,
    antigen_description,
    coverage_category,
    target_number,
    doses_administered,
    coverage_percentage,
    CASE 
        WHEN target_number > 0 
        THEN ROUND((doses_administered / target_number) * 100, 2)
        ELSE NULL 
    END AS calculated_coverage
FROM fact_coverage
WHERE coverage_category = 'ADMIN'
  AND doses_administered IS NOT NULL
  AND target_number IS NOT NULL;

-- ----------------------------------------------------------------------------
-- View: WHO Standard Coverage Estimates
-- Purpose: WHO/UNICEF estimates for international comparisons
-- Use For: Global benchmarking and trend analysis
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_coverage_who_estimates AS
SELECT 
    country_code,
    country_name,
    year,
    antigen_code,
    antigen_description,
    coverage_percentage,
    'WUENIC' as source
FROM fact_coverage
WHERE coverage_category = 'WUENIC'
  AND coverage_percentage IS NOT NULL;

-- ----------------------------------------------------------------------------
-- View: Best Available Coverage Data
-- Purpose: Select the most reliable source per country-year-vaccine
-- Priority: ADMIN > OFFICIAL > WUENIC
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_coverage_best_available AS
WITH ranked_coverage AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY country_code, year, antigen_code
            ORDER BY 
                CASE coverage_category
                    WHEN 'ADMIN' THEN 1
                    WHEN 'OFFICIAL' THEN 2
                    WHEN 'WUENIC' THEN 3
                    WHEN 'PAB' THEN 4
                    WHEN 'HPV' THEN 5
                    ELSE 6
                END,
                data_completeness DESC
        ) as priority_rank
    FROM fact_coverage
    WHERE coverage_percentage IS NOT NULL
)
SELECT 
    country_code,
    country_name,
    year,
    antigen_code,
    antigen_description,
    coverage_category,
    target_number,
    doses_administered,
    coverage_percentage,
    data_completeness
FROM ranked_coverage
WHERE priority_rank = 1;

-- ----------------------------------------------------------------------------
-- View: Vaccination Impact Analysis
-- Purpose: Join coverage with disease incidence/cases for correlation analysis
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_vaccination_impact AS
SELECT 
    c.country_code,
    c.country_name,
    c.year,
    c.antigen_code,
    c.coverage_percentage,
    i.disease_code,
    i.incidence_rate,
    r.cases_reported
FROM fact_coverage c
LEFT JOIN fact_incidence_rate i 
    ON c.country_code = i.country_code 
    AND c.year = i.year
LEFT JOIN fact_reported_cases r 
    ON c.country_code = r.country_code 
    AND c.year = r.year
    AND i.disease_code = r.disease_code
WHERE c.coverage_percentage IS NOT NULL;

-- ============================================================================
-- DATA LOADING NOTES
-- ============================================================================

/*
STEP 1: Populate Dimension Tables First
----------------------------------------
1. dim_countries - Extract unique countries from all tables
2. dim_years - Generate years 1940-2023
3. dim_vaccines - Extract unique antigens
4. dim_diseases - Extract unique diseases
5. dim_coverage_categories - Manual insert of 5 categories

STEP 2: Load Fact Tables
-------------------------
1. fact_coverage - Load from coverage_data_cleaned.csv
2. fact_incidence_rate - Load from incidence_rate_cleaned.csv
3. fact_reported_cases - Load from reported_cases_cleaned.csv
4. fact_vaccine_introduction - Load from vaccine_introduction_cleaned.csv
5. fact_vaccine_schedule - Load from vaccine_schedule_cleaned.csv

CRITICAL REMINDERS:
------------------
1. Coverage table uses 4-column primary key including coverage_category
2. Vaccine schedule uses 5-column primary key
3. All foreign keys reference dimension tables
4. Use views for specific analysis types
5. Coverage_percentage is already capped at 100 in cleaned data
*/
-- ============================================================================
-- VACCINATION DATA - DATA LOADING SCRIPT
-- ============================================================================
-- Run this AFTER creating the schema
-- Assumes cleaned CSV files are in 'cleaned_data/' folder
-- ============================================================================

USE vaccination_analysis;

-- ============================================================================
-- STEP 1: POPULATE DIMENSION TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1: Load Countries Dimension
-- Purpose: Create master list of all countries from all tables
-- ----------------------------------------------------------------------------

-- First, create temporary staging table to collect all countries
CREATE TEMPORARY TABLE temp_countries (
    country_code VARCHAR(3),
    country_name VARCHAR(100),
    who_region VARCHAR(10),
    group_classification VARCHAR(50)
);

-- Load countries from coverage data
LOAD DATA LOCAL INFILE 'cleaned_data/coverage_data_cleaned.csv'
INTO TABLE temp_countries
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(group_classification, country_code, country_name, @dummy, @dummy, @dummy, 
 @dummy, @dummy, @dummy, @dummy, @dummy, @dummy, @dummy);

-- Load countries from vaccine introduction
LOAD DATA LOCAL INFILE 'cleaned_data/vaccine_introduction_cleaned.csv'
INTO TABLE temp_countries
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_code, country_name, who_region, @dummy, @dummy, @dummy);

-- Insert unique countries into dimension table
INSERT INTO dim_countries (country_code, country_name, who_region, group_classification)
SELECT DISTINCT
    country_code,
    FIRST_VALUE(country_name) OVER (PARTITION BY country_code ORDER BY country_name) as country_name,
    FIRST_VALUE(who_region) OVER (PARTITION BY country_code ORDER BY who_region) as who_region,
    FIRST_VALUE(group_classification) OVER (PARTITION BY country_code ORDER BY group_classification) as group_classification
FROM temp_countries
WHERE country_code IS NOT NULL
GROUP BY country_code;

DROP TEMPORARY TABLE temp_countries;

SELECT CONCAT('✓ Loaded ', COUNT(*), ' countries') as status FROM dim_countries;

-- ----------------------------------------------------------------------------
-- 1.2: Load Years Dimension
-- Purpose: Generate years 1940-2023 (full range from all tables)
-- ----------------------------------------------------------------------------

INSERT INTO dim_years (year)
WITH RECURSIVE years_cte AS (
    SELECT 1940 as year
    UNION ALL
    SELECT year + 1
    FROM years_cte
    WHERE year < 2023
)
SELECT year FROM years_cte;

SELECT CONCAT('✓ Loaded ', COUNT(*), ' years (1940-2023)') as status FROM dim_years;

-- ----------------------------------------------------------------------------
-- 1.3: Load Vaccines Dimension
-- Purpose: Extract unique vaccines/antigens
-- ----------------------------------------------------------------------------

-- Create temp staging table
CREATE TEMPORARY TABLE temp_vaccines (
    antigen_code VARCHAR(50),
    antigen_description VARCHAR(200)
);

-- Load from coverage data
LOAD DATA LOCAL INFILE 'cleaned_data/coverage_data_cleaned.csv'
INTO TABLE temp_vaccines
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@dummy, @dummy, @dummy, @dummy, antigen_code, antigen_description, 
 @dummy, @dummy, @dummy, @dummy, @dummy, @dummy, @dummy);

-- Insert unique vaccines
INSERT INTO dim_vaccines (antigen_code, antigen_description, vaccine_family)
SELECT DISTINCT
    antigen_code,
    FIRST_VALUE(antigen_description) OVER (PARTITION BY antigen_code ORDER BY antigen_description) as antigen_description,
    -- Extract vaccine family from code (e.g., DTP from DTPCV1)
    CASE 
        WHEN antigen_code LIKE 'DTP%' THEN 'DTP'
        WHEN antigen_code LIKE 'HEP%' THEN 'Hepatitis'
        WHEN antigen_code LIKE 'HPV%' THEN 'HPV'
        WHEN antigen_code LIKE 'FLU%' THEN 'Influenza'
        WHEN antigen_code LIKE 'POL%' THEN 'Polio'
        WHEN antigen_code LIKE 'MCV%' OR antigen_code = 'MEASLES' THEN 'Measles'
        WHEN antigen_code = 'BCG' THEN 'TB'
        WHEN antigen_code LIKE 'PCV%' THEN 'Pneumococcal'
        WHEN antigen_code LIKE 'ROTA%' THEN 'Rotavirus'
        ELSE 'Other'
    END as vaccine_family
FROM temp_vaccines
WHERE antigen_code IS NOT NULL
GROUP BY antigen_code;

DROP TEMPORARY TABLE temp_vaccines;

SELECT CONCAT('✓ Loaded ', COUNT(*), ' vaccine types') as status FROM dim_vaccines;

-- ----------------------------------------------------------------------------
-- 1.4: Load Diseases Dimension
-- Purpose: Extract unique diseases
-- ----------------------------------------------------------------------------

CREATE TEMPORARY TABLE temp_diseases (
    disease_code VARCHAR(50),
    disease_description VARCHAR(200)
);

-- Load from incidence rate data
LOAD DATA LOCAL INFILE 'cleaned_data/incidence_rate_cleaned.csv'
INTO TABLE temp_diseases
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(@dummy, @dummy, @dummy, @dummy, disease_code, disease_description, @dummy, @dummy);

-- Insert unique diseases
INSERT INTO dim_diseases (disease_code, disease_description, disease_category)
SELECT DISTINCT
    disease_code,
    FIRST_VALUE(disease_description) OVER (PARTITION BY disease_code ORDER BY disease_description) as disease_description,
    CASE 
        WHEN disease_code IN ('DIPHT', 'TETANUS', 'PERTUSSIS') THEN 'Vaccine-Preventable'
        WHEN disease_code IN ('MEASLES', 'MUMPS', 'RUBELLA', 'CRS') THEN 'Vaccine-Preventable'
        WHEN disease_code IN ('POLIO', 'POLIOMYELITIS') THEN 'Vaccine-Preventable'
        WHEN disease_code IN ('HEPB', 'HEPA') THEN 'Hepatitis'
        WHEN disease_code IN ('TB', 'TUBERCULOSIS') THEN 'Tuberculosis'
        ELSE 'Other'
    END as disease_category
FROM temp_diseases
WHERE disease_code IS NOT NULL
GROUP BY disease_code;

DROP TEMPORARY TABLE temp_diseases;

SELECT CONCAT('✓ Loaded ', COUNT(*), ' disease types') as status FROM dim_diseases;

-- ----------------------------------------------------------------------------
-- 1.5: Load Coverage Categories Dimension
-- Purpose: Define the 5 coverage category types
-- ----------------------------------------------------------------------------

INSERT INTO dim_coverage_categories 
(category_code, category_description, data_source, reliability_score, includes_admin_data)
VALUES
    ('ADMIN', 'Administrative coverage - actual doses administered', 
     'Government administrative records', 0.85, TRUE),
    ('WUENIC', 'WHO/UNICEF estimates - standardized global estimates', 
     'WHO/UNICEF joint reporting', 0.90, FALSE),
    ('OFFICIAL', 'Official coverage - government surveys and reports', 
     'Government surveys', 0.75, FALSE),
    ('PAB', 'PAB Program coverage', 
     'Special program data', 0.70, FALSE),
    ('HPV', 'HPV-specific coverage tracking', 
     'HPV program data', 0.75, TRUE);

SELECT CONCAT('✓ Loaded ', COUNT(*), ' coverage categories') as status 
FROM dim_coverage_categories;

-- ============================================================================
-- STEP 2: LOAD FACT TABLES
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1: Load Coverage Fact Table
-- CRITICAL: Uses 4-column primary key including coverage_category
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'cleaned_data/coverage_data_cleaned.csv'
INTO TABLE fact_coverage
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(group_classification, country_code, country_name, year, antigen_code, 
 antigen_description, coverage_category, category_description, 
 @target, @doses, @coverage, has_admin_data, data_completeness)
SET 
    target_number = NULLIF(@target, ''),
    doses_administered = NULLIF(@doses, ''),
    coverage_percentage = NULLIF(@coverage, '');

SELECT CONCAT('✓ Loaded ', COUNT(*), ' coverage records') as status 
FROM fact_coverage;

-- Verify primary key uniqueness
SELECT 
    CASE 
        WHEN COUNT(*) = COUNT(DISTINCT country_code, year, antigen_code, coverage_category)
        THEN '✓ Primary key verified - all combinations unique'
        ELSE '✗ WARNING: Duplicate primary keys found!'
    END as pk_check
FROM fact_coverage;

-- ----------------------------------------------------------------------------
-- 2.2: Load Incidence Rate Fact Table
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'cleaned_data/incidence_rate_cleaned.csv'
INTO TABLE fact_incidence_rate
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(group_classification, country_code, country_name, year, disease_code, 
 disease_description, denominator, @incidence)
SET 
    incidence_rate = NULLIF(@incidence, '');

SELECT CONCAT('✓ Loaded ', COUNT(*), ' incidence rate records') as status 
FROM fact_incidence_rate;

-- ----------------------------------------------------------------------------
-- 2.3: Load Reported Cases Fact Table
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'cleaned_data/reported_cases_cleaned.csv'
INTO TABLE fact_reported_cases
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(group_classification, country_code, country_name, year, disease_code, 
 disease_description, @cases)
SET 
    cases_reported = NULLIF(@cases, '');

SELECT CONCAT('✓ Loaded ', COUNT(*), ' reported cases records') as status 
FROM fact_reported_cases;

-- ----------------------------------------------------------------------------
-- 2.4: Load Vaccine Introduction Fact Table
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'cleaned_data/vaccine_introduction_cleaned.csv'
INTO TABLE fact_vaccine_introduction
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_code, country_name, who_region, year, vaccine_name, intro_status);

SELECT CONCAT('✓ Loaded ', COUNT(*), ' vaccine introduction records') as status 
FROM fact_vaccine_introduction;

-- ----------------------------------------------------------------------------
-- 2.5: Load Vaccine Schedule Fact Table
-- CRITICAL: Uses 5-column primary key
-- ----------------------------------------------------------------------------

LOAD DATA LOCAL INFILE 'cleaned_data/vaccine_schedule_cleaned.csv'
INTO TABLE fact_vaccine_schedule
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(country_code, country_name, who_region, year, vaccine_code, vaccine_description,
 schedule_round, target_population, target_pop_description, geographic_area, 
 @age, @comment)
SET
    age_administered = NULLIF(@age, ''),
    source_comment = NULLIF(@comment, '');

SELECT CONCAT('✓ Loaded ', COUNT(*), ' vaccine schedule records') as status 
FROM fact_vaccine_schedule;

-- ============================================================================
-- STEP 3: DATA QUALITY VERIFICATION
-- ============================================================================

SELECT '============================================' as '';
SELECT 'DATA LOADING SUMMARY' as '';
SELECT '============================================' as '';

-- Dimension table counts
SELECT 'DIMENSION TABLES:' as '';
SELECT CONCAT('  Countries: ', COUNT(*)) as count FROM dim_countries;
SELECT CONCAT('  Years: ', COUNT(*)) as count FROM dim_years;
SELECT CONCAT('  Vaccines: ', COUNT(*)) as count FROM dim_vaccines;
SELECT CONCAT('  Diseases: ', COUNT(*)) as count FROM dim_diseases;
SELECT CONCAT('  Coverage Categories: ', COUNT(*)) as count FROM dim_coverage_categories;

SELECT '' as '';
SELECT 'FACT TABLES:' as '';
SELECT CONCAT('  Coverage Records: ', COUNT(*)) as count FROM fact_coverage;
SELECT CONCAT('  Incidence Rate Records: ', COUNT(*)) as count FROM fact_incidence_rate;
SELECT CONCAT('  Reported Cases Records: ', COUNT(*)) as count FROM fact_reported_cases;
SELECT CONCAT('  Vaccine Introductions: ', COUNT(*)) as count FROM fact_vaccine_introduction;
SELECT CONCAT('  Vaccine Schedules: ', COUNT(*)) as count FROM fact_vaccine_schedule;

SELECT '' as '';
SELECT 'DATA QUALITY CHECKS:' as '';

-- Check coverage data quality
SELECT 
    CONCAT('  Coverage with admin data: ', 
           ROUND(SUM(has_admin_data) / COUNT(*) * 100, 1), '%') as metric
FROM fact_coverage;

SELECT 
    CONCAT('  Coverage records with percentage: ', 
           ROUND(SUM(CASE WHEN coverage_percentage IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*) * 100, 1), '%') as metric
FROM fact_coverage;

-- Check for any data outside expected ranges
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '  ✓ All coverage percentages valid (0-100)'
        ELSE CONCAT('  ✗ WARNING: ', COUNT(*), ' coverage records outside 0-100 range!')
    END as validation
FROM fact_coverage
WHERE coverage_percentage < 0 OR coverage_percentage > 100;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '  ✓ All incidence rates non-negative'
        ELSE CONCAT('  ✗ WARNING: ', COUNT(*), ' negative incidence rates!')
    END as validation
FROM fact_incidence_rate
WHERE incidence_rate < 0;

SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '  ✓ All case counts non-negative'
        ELSE CONCAT('  ✗ WARNING: ', COUNT(*), ' negative case counts!')
    END as validation
FROM fact_reported_cases
WHERE cases_reported < 0;

SELECT '============================================' as '';
SELECT 'DATA LOADING COMPLETE!' as '';
SELECT '============================================' as '';

-- ============================================================================
-- STEP 4: CREATE INDEXES FOR PERFORMANCE (If not already in schema)
-- ============================================================================

-- Already created in schema, but adding here for reference
-- Indexes improve query performance for Power BI

-- Coverage table indexes (most frequently queried)
ALTER TABLE fact_coverage ADD INDEX idx_year_coverage (year, coverage_percentage);
ALTER TABLE fact_coverage ADD INDEX idx_country_year_antigen (country_code, year, antigen_code);

-- Incidence/Cases indexes for correlation queries
ALTER TABLE fact_incidence_rate ADD INDEX idx_year_disease_rate (year, disease_code, incidence_rate);
ALTER TABLE fact_reported_cases ADD INDEX idx_year_disease_cases (year, disease_code, cases_reported);

SELECT '✓ Performance indexes verified' as status;

-- ============================================================================
-- NOTES FOR POWER BI CONNECTION
-- ============================================================================

/*
POWER BI CONNECTION INSTRUCTIONS:
---------------------------------

1. In Power BI Desktop, click "Get Data" > "MySQL Database"

2. Server: localhost (or your MySQL server address)
   Database: vaccination_analysis

3. Import these tables:
   - All dim_* tables (small, import mode)
   - All fact_* tables (large, consider DirectQuery for real-time)
   - All vw_* views (for pre-aggregated analysis)

4. Relationship Configuration (Power BI will auto-detect most):
   - dim_countries[country_code] → fact_coverage[country_code]
   - dim_years[year] → fact_coverage[year]
   - dim_vaccines[antigen_code] → fact_coverage[antigen_code]
   - dim_diseases[disease_code] → fact_incidence_rate[disease_code]
   - dim_coverage_categories[category_code] → fact_coverage[coverage_category]

5. Use the views for specific analyses:
   - vw_coverage_admin_data: For dose-based analysis
   - vw_coverage_who_estimates: For global comparisons
   - vw_coverage_best_available: For trend analysis (auto-selects best source)
   - vw_vaccination_impact: For coverage vs disease correlation

6. Key DAX Measures to Create:
   - Average Coverage = AVERAGE(fact_coverage[coverage_percentage])
   - Total Doses = SUM(fact_coverage[doses_administered])
   - Total Cases = SUM(fact_reported_cases[cases_reported])
   - Coverage Trend = Calculate coverage year-over-year change
*/
show databases;
USE vaccination_analysis;

-- Disable foreign key checks and enable local file loading
SET FOREIGN_KEY_CHECKS=0;
SET GLOBAL local_infile = 1;

-- ============================================================================
-- STEP 1: LOAD DIMENSION TABLES MANUALLY
-- ============================================================================

-- 1. Load Years (1980-2023)
INSERT IGNORE INTO dim_years (year)
WITH RECURSIVE years_cte AS (
    SELECT 1980 as year
    UNION ALL
    SELECT year + 1 FROM years_cte WHERE year < 2023
)
SELECT year FROM years_cte;

SELECT CONCAT('✓ Loaded ', COUNT(*), ' years') as Status FROM dim_years;

-- 2. Load Coverage Categories
INSERT IGNORE INTO dim_coverage_categories 
(category_code, category_description, data_source, reliability_score, includes_admin_data)
VALUES
('ADMIN', 'Administrative coverage', 'Government records', 0.85, TRUE),
('WUENIC', 'WHO/UNICEF estimates', 'WHO/UNICEF', 0.90, FALSE),
('OFFICIAL', 'Official coverage', 'Government surveys', 0.75, FALSE),
('PAB', 'PAB Program coverage', 'Special program', 0.70, FALSE),
('HPV', 'HPV-specific coverage', 'HPV program', 0.75, TRUE);

SELECT CONCAT('✓ Loaded ', COUNT(*), ' coverage categories') as Status 
FROM dim_coverage_categories;

-- Re-enable foreign keys
SET FOREIGN_KEY_CHECKS=1;

SELECT '✓ Dimension tables loaded! Now use Python for the rest.' as Status;
Select * from dim_countries;