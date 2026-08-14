-- =====================================================================
-- 01_schema.sql
-- Creates the two tables and loads the CSVs from the data/ folder.
-- Run from the repo root:  psql -d covid -f sql/01_schema.sql
-- =====================================================================

DROP TABLE IF EXISTS covid_deaths, covid_vaccinations CASCADE;

CREATE TABLE covid_deaths (
    iso_code                                  TEXT,
    continent                                 TEXT,
    location                                  TEXT NOT NULL,
    date                                      DATE NOT NULL,
    population                                NUMERIC,
    total_cases                               NUMERIC,
    new_cases                                 NUMERIC,
    new_cases_smoothed                        NUMERIC,
    total_deaths                              NUMERIC,
    new_deaths                                NUMERIC,
    new_deaths_smoothed                       NUMERIC,
    total_cases_per_million                   NUMERIC,
    new_cases_per_million                     NUMERIC,
    new_cases_smoothed_per_million            NUMERIC,
    total_deaths_per_million                  NUMERIC,
    new_deaths_per_million                    NUMERIC,
    new_deaths_smoothed_per_million           NUMERIC,
    reproduction_rate                         NUMERIC,
    icu_patients                              NUMERIC,
    icu_patients_per_million                  NUMERIC,
    hosp_patients                             NUMERIC,
    hosp_patients_per_million                 NUMERIC,
    weekly_icu_admissions                     NUMERIC,
    weekly_icu_admissions_per_million         NUMERIC,
    weekly_hosp_admissions                    NUMERIC,
    weekly_hosp_admissions_per_million        NUMERIC,
    PRIMARY KEY (location, date)
);

CREATE TABLE covid_vaccinations (
    iso_code                                  TEXT,
    continent                                 TEXT,
    location                                  TEXT NOT NULL,
    date                                      DATE NOT NULL,
    new_tests                                 NUMERIC,
    total_tests                               NUMERIC,
    total_tests_per_thousand                  NUMERIC,
    new_tests_per_thousand                    NUMERIC,
    new_tests_smoothed                        NUMERIC,
    new_tests_smoothed_per_thousand           NUMERIC,
    positive_rate                             NUMERIC,
    tests_per_case                            NUMERIC,
    tests_units                               TEXT,
    total_vaccinations                        NUMERIC,
    people_vaccinated                         NUMERIC,
    people_fully_vaccinated                   NUMERIC,
    new_vaccinations                          NUMERIC,
    new_vaccinations_smoothed                 NUMERIC,
    total_vaccinations_per_hundred            NUMERIC,
    people_vaccinated_per_hundred             NUMERIC,
    people_fully_vaccinated_per_hundred       NUMERIC,
    new_vaccinations_smoothed_per_million     NUMERIC,
    stringency_index                          NUMERIC,
    population_density                        NUMERIC,
    median_age                                NUMERIC,
    aged_65_older                             NUMERIC,
    aged_70_older                             NUMERIC,
    gdp_per_capita                            NUMERIC,
    extreme_poverty                           NUMERIC,
    cardiovasc_death_rate                     NUMERIC,
    diabetes_prevalence                       NUMERIC,
    female_smokers                            NUMERIC,
    male_smokers                              NUMERIC,
    handwashing_facilities                    NUMERIC,
    hospital_beds_per_thousand                NUMERIC,
    life_expectancy                           NUMERIC,
    human_development_index                   NUMERIC,
    PRIMARY KEY (location, date)
);

-- Load data (\copy reads the file from your machine, not the server)
\copy covid_deaths       FROM 'data/covid_deaths.csv'       WITH (FORMAT csv, HEADER true)
\copy covid_vaccinations FROM 'data/covid_vaccinations.csv' WITH (FORMAT csv, HEADER true)

-- Index used by every country-level time series query
CREATE INDEX idx_deaths_continent ON covid_deaths (continent);

SELECT 'covid_deaths' AS table_name, COUNT(*) AS row_count FROM covid_deaths
UNION ALL
SELECT 'covid_vaccinations', COUNT(*) FROM covid_vaccinations;
