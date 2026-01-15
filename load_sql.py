import pandas as pd
import mysql.connector
from mysql.connector import Error

print("="*80)
print("LOADING REMAINING DATA INTO MySQL")
print("="*80)

# Configuration
MYSQL_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': 'root',  # ← CHANGE THIS
    'database': 'vaccination_analysis',
    'autocommit': False,
    'allow_local_infile': True
}

DATA_FOLDER = 'cleaned_data/'

# Connect
print("\nConnecting to MySQL...")
try:
    conn = mysql.connector.connect(**MYSQL_CONFIG)
    cursor = conn.cursor()
    
    
    
    # Disable foreign key checks
    cursor.execute("SET FOREIGN_KEY_CHECKS=0")
    conn.commit()
    
    print("✓ Connected successfully\n")
except Error as e:
    print(f"✗ Error: {e}")
    exit(1)

# ============================================================================
# LOAD DIMENSION TABLES (Countries, Vaccines, Diseases)
# ============================================================================

print("="*80)
print("LOADING DIMENSION TABLES")
print("="*80)

# 1. Countries
print("\n1. Loading Countries...")
coverage_df = pd.read_csv(f'{DATA_FOLDER}coverage_data_cleaned.csv')
intro_df = pd.read_csv(f'{DATA_FOLDER}vaccine_introduction_cleaned.csv')

countries = pd.concat([
    coverage_df[['CODE', 'NAME', 'GROUP']],
    intro_df[['ISO_3_CODE', 'COUNTRYNAME', 'WHO_REGION']].rename(
        columns={'ISO_3_CODE': 'CODE', 'COUNTRYNAME': 'NAME', 'WHO_REGION': 'WHO_REGION'})
]).drop_duplicates(subset=['CODE'])

count = 0
for _, row in countries.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO dim_countries (country_code, country_name, who_region, group_classification)
            VALUES (%s, %s, %s, %s)
        """, (row['CODE'], row.get('NAME'), row.get('WHO_REGION'), row.get('GROUP')))
        count += 1
    except: pass
conn.commit()
print(f"   ✓ Loaded {count} countries")

# 2. Vaccines
print("\n2. Loading Vaccines...")
vaccines = coverage_df[['ANTIGEN', 'ANTIGEN_DESCRIPTION']].drop_duplicates()
count = 0
for _, row in vaccines.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO dim_vaccines (antigen_code, antigen_description)
            VALUES (%s, %s)
        """, (row['ANTIGEN'], row['ANTIGEN_DESCRIPTION']))
        count += 1
    except: pass
conn.commit()
print(f"   ✓ Loaded {count} vaccines")

# 3. Diseases
print("\n3. Loading Diseases...")
incidence_df = pd.read_csv(f'{DATA_FOLDER}incidence_rate_cleaned.csv')
diseases = incidence_df[['DISEASE', 'DISEASE_DESCRIPTION']].drop_duplicates()
count = 0
for _, row in diseases.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO dim_diseases (disease_code, disease_description)
            VALUES (%s, %s)
        """, (row['DISEASE'], row['DISEASE_DESCRIPTION']))
        count += 1
    except: pass
conn.commit()
print(f"   ✓ Loaded {count} diseases")

# ============================================================================
# LOAD FACT TABLES (Smaller first)
# ============================================================================

print("\n" + "="*80)
print("LOADING FACT TABLES")
print("="*80)

# 1. Incidence Rate
print("\n1. Loading Incidence Rate Data...")
count = 0
for idx, row in incidence_df.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO fact_incidence_rate 
            (country_code, year, disease_code, country_name, disease_description,
             group_classification, denominator, incidence_rate)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            row['CODE'], int(row['YEAR']), row['DISEASE'], row.get('NAME'),
            row.get('DISEASE_DESCRIPTION'), row.get('GROUP'), row.get('DENOMINATOR'),
            None if pd.isna(row.get('INCIDENCE_RATE')) else float(row['INCIDENCE_RATE'])
        ))
        count += 1
        if count % 5000 == 0:
            conn.commit()
            print(f"   Progress: {count:,} rows...")
    except Exception as e:
        if count == 0: print(f"   Warning: {e}")
conn.commit()
print(f"   ✓ Loaded {count:,} incidence records")

# 2. Reported Cases
print("\n2. Loading Reported Cases Data...")
cases_df = pd.read_csv(f'{DATA_FOLDER}reported_cases_cleaned.csv')
count = 0
for idx, row in cases_df.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO fact_reported_cases 
            (country_code, year, disease_code, country_name, disease_description,
             group_classification, cases_reported)
            VALUES (%s, %s, %s, %s, %s, %s, %s)
        """, (
            row['CODE'], int(row['YEAR']), row['DISEASE'], row.get('NAME'),
            row.get('DISEASE_DESCRIPTION'), row.get('GROUP'),
            None if pd.isna(row.get('CASES')) else int(row['CASES'])
        ))
        count += 1
        if count % 5000 == 0:
            conn.commit()
            print(f"   Progress: {count:,} rows...")
    except: pass
conn.commit()
print(f"   ✓ Loaded {count:,} reported cases")

# 3. Vaccine Introduction
print("\n3. Loading Vaccine Introduction Data...")
count = 0
for idx, row in intro_df.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO fact_vaccine_introduction 
            (country_code, year, vaccine_name, country_name, who_region, intro_status)
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (
            row['ISO_3_CODE'], int(row['YEAR']), row['DESCRIPTION'],
            row.get('COUNTRYNAME'), row.get('WHO_REGION'), row.get('INTRO')
        ))
        count += 1
        if count % 10000 == 0:
            conn.commit()
            print(f"   Progress: {count:,} rows...")
    except: pass
conn.commit()
print(f"   ✓ Loaded {count:,} vaccine introductions")

# 4. Vaccine Schedule
print("\n4. Loading Vaccine Schedule Data...")
schedule_df = pd.read_csv(f'{DATA_FOLDER}vaccine_schedule_cleaned.csv')
count = 0
for idx, row in schedule_df.iterrows():
    try:
        cursor.execute("""
            INSERT IGNORE INTO fact_vaccine_schedule 
            (country_code, year, vaccine_code, schedule_round, target_population,
             country_name, vaccine_description, target_pop_description, who_region,
             geographic_area, age_administered, source_comment)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (
            row['ISO_3_CODE'], int(row['YEAR']), row['VACCINECODE'], 
            int(row['SCHEDULEROUNDS']), str(row.get('TARGETPOP', 'ALL'))[:50],
            row.get('COUNTRYNAME'), row.get('VACCINE_DESCRIPTION'),
            row.get('TARGETPOP_DESCRIPTION'), row.get('WHO_REGION'),
            row.get('GEOAREA'), row.get('AGEADMINISTERED'), row.get('SOURCECOMMENT')
        ))
        count += 1
    except: pass
conn.commit()
print(f"   ✓ Loaded {count:,} vaccine schedules")

# 5. Coverage Data (LARGEST - will take time)
print("\n5. Loading Coverage Data (This will take 5-10 minutes)...")
count = 0
batch_size = 5000

for i in range(0, len(coverage_df), batch_size):
    batch = coverage_df.iloc[i:i+batch_size]
    for _, row in batch.iterrows():
        try:
            cursor.execute("""
                INSERT IGNORE INTO fact_coverage 
                (country_code, year, antigen_code, coverage_category, country_name, 
                 antigen_description, category_description, group_classification,
                 target_number, doses_administered, coverage_percentage, 
                 has_admin_data, data_completeness)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """, (
                row['CODE'], int(row['YEAR']), row['ANTIGEN'], row['COVERAGE_CATEGORY'],
                row.get('NAME'), row.get('ANTIGEN_DESCRIPTION'), 
                row.get('COVERAGE_CATEGORY_DESCRIPTION'), row.get('GROUP'),
                None if pd.isna(row.get('TARGET_NUMBER')) else int(row['TARGET_NUMBER']),
                None if pd.isna(row.get('DOSES')) else int(row['DOSES']),
                None if pd.isna(row.get('COVERAGE')) else float(row['COVERAGE']),
                bool(row.get('has_admin_data', 0)),
                str(row.get('data_completeness', 'Missing'))
            ))
            count += 1
        except: pass
    
    conn.commit()
    print(f"   Progress: {count:,} rows...")

print(f"   ✓ Loaded {count:,} coverage records")

# Re-enable foreign keys
cursor.execute("SET FOREIGN_KEY_CHECKS=1")
conn.commit()

# Verification
print("\n" + "="*80)
print("VERIFICATION")
print("="*80)

tables = [
    'dim_countries', 'dim_vaccines', 'dim_diseases',
    'fact_coverage', 'fact_incidence_rate', 'fact_reported_cases',
    'fact_vaccine_introduction', 'fact_vaccine_schedule'
]

for table in tables:
    cursor.execute(f"SELECT COUNT(*) FROM {table}")
    count = cursor.fetchone()[0]
    print(f"{table}: {count:,}")

cursor.close()
conn.close()

print("\n" + "="*80)
print("✓ DATA LOADING COMPLETE!")
print("="*80)