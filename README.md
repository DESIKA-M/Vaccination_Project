# Vaccination Data Analysis & Data Warehouse Project

## 1. Project Overview

This project implements a complete end-to-end data analytics pipeline for global vaccination data using Python, MySQL, SQL, and Power BI.

The primary objective is to transform raw healthcare datasets into a structured dimensional data warehouse and generate actionable insights through business intelligence visualization.

The workflow includes:

1. Data Cleaning and Exploratory Data Analysis using Python
2. Dimensional Modeling using SQL (Star Schema)
3. Data Warehouse Implementation in MySQL
4. Interactive Dashboard Development in Power BI

## 2. Project Architecture

Raw CSV Data
→ Python (EDA and Cleaning)
→ MySQL (Dimension and Fact Tables – Star Schema)
→ Power BI Dashboard
→ Insight Generation

## 3. Technology Stack

1. Python – Data Cleaning, EDA, ETL
2. Pandas – Data Manipulation and Transformation
3. MySQL – Data Warehouse Storage
4. SQL – Schema Design and Querying
5. Power BI – Data Visualization and Reporting

## 4. Dataset Description

The project integrates multiple vaccination-related datasets:

1. Coverage Data
2. Reported Cases Data
3. Incidence Rate Data
4. Vaccine Introduction Data
5. Vaccine Schedule Data

Key attributes included:

1. Country Code
2. Country Name
3. Year
4. Disease
5. Antigen or Vaccine
6. Coverage Percentage
7. Doses Administered
8. Reported Cases
9. WHO Region
10. Target Population

## 5. Python – Data Cleaning and EDA

### 5.1 Data Cleaning

The following preprocessing steps were performed using Pandas:

1. Removal of duplicate records
2. Handling missing values using `pd.isna()`
3. Standardization of column names
4. Data type conversion (integer, float, string)
5. Normalization of categorical fields
6. Export of cleaned datasets to CSV

### 5.2 Exploratory Data Analysis

EDA was conducted to understand patterns and guide dimensional modeling decisions.

Analysis included:

1. Country-wise vaccination trends
2. Year-over-year coverage growth
3. Disease incidence pattern analysis
4. Missing data assessment
5. Aggregation and grouping operations
6. Statistical summaries using `describe()`

Example operations:

df.groupby(['Country', 'Year'])['Coverage'].mean()
df.isnull().sum()
df.describe()

## 6. SQL – Dimensional Data Warehouse Design

A Star Schema architecture was implemented to optimize analytical performance.

### 6.1 Dimension Tables

1. dim_countries

   1. country_code (Primary Key)
   2. country_name
   3. who_region
   4. group_classification

2. dim_vaccines

   1. antigen_code (Primary Key)
   2. antigen_description

3. dim_diseases

   1. disease_code (Primary Key)
   2. disease_description


### 6.2 Fact Tables

1. fact_coverage
   Grain: Country + Year + Antigen + Coverage Category
   Measures:

   1. target_number
   2. doses_administered
   3. coverage_percentage
   4. has_admin_data
   5. data_completeness

2. fact_incidence_rate
   Grain: Country + Year + Disease
   Measures:

   1. incidence_rate
   2. denominator

3. fact_reported_cases
   Grain: Country + Year + Disease
   Measure:

   1. cases_reported

4. fact_vaccine_introduction
   Grain: Country + Year + Vaccine
   Measure:

   1. intro_status

5. fact_vaccine_schedule
   Grain: Country + Year + Vaccine
   Attributes:

   1. schedule_round
   2. target_population
   3. age_administered
   4. geographic_area

## 7. ETL Implementation (Python to MySQL)

The ETL pipeline was implemented using `mysql.connector`.

Process steps:

1. Establish database connection
2. Disable foreign key checks
3. Load dimension tables first
4. Load fact tables in controlled batches
5. Commit transactions periodically
6. Re-enable foreign key checks
7. Validate record counts

Performance strategies used:

1. Batch insertion of 5000 rows
2. Use of `INSERT IGNORE` to prevent duplication
3. Controlled transaction commits
4. Data type validation before insertion

## 8. Power BI Dashboard

An interactive Power BI dashboard was created using the star schema model.

### 8.1 Key Visualizations

1. Total Vaccination Coverage by Country
2. Year-wise Vaccination Trend Analysis
3. Disease Incidence Comparison
4. Reported Cases Trend
5. WHO Region Performance Analysis
6. Vaccine Introduction Timeline
7. Coverage Category Comparison

### 8.2 Dashboard Features

1. Country and Year slicers
2. Drill-down capability
3. KPI cards for quick metrics
4. Time-series line charts
5. Comparative bar charts
6. Regional performance filtering

## 9. Key Insights

1. Identification of countries with high and low vaccination coverage
2. Detection of temporal trends in disease incidence
3. Regional disparities in immunization programs
4. Relationship between vaccination coverage and reported cases
5. Impact of vaccine introduction across years

## 10. Performance Optimization

1. Star schema for efficient aggregation
2. Indexed foreign keys
3. Batch ETL processing
4. Duplicate-safe loading strategy
5. Data normalization for reduced redundancy

## 12. Business Impact

This project demonstrates:

1. Real-world healthcare data analytics
2. Dimensional modeling expertise
3. SQL data warehousing capability
4. Business intelligence dashboard development
5. Large-scale dataset handling
6. End-to-end analytics implementation

## 13. Future Enhancements

1. Implement Slowly Changing Dimensions (SCD Type 2)
2. Add a time dimension table
3. Automate ETL using workflow orchestration tools
4. Deploy database to cloud infrastructure
5. Implement time-series forecasting models
6. Add advanced DAX measures in Power BI

