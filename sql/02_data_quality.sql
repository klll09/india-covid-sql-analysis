-- =====================================================================
-- 02_data_quality.sql
-- Checks run BEFORE any analysis, so the numbers later can be trusted.
-- =====================================================================

-- 1. Coverage: date range and how many real countries are in the data
SELECT MIN(date) AS first_date,
       MAX(date) AS last_date,
       COUNT(DISTINCT location) FILTER (WHERE continent IS NOT NULL) AS countries
FROM covid_deaths;

-- 2. Aggregate rows hiding in the "location" column.
--    Rows like 'World' or 'Asia' have continent = NULL. If we don't filter
--    them out, any SUM over locations double-counts everything.
SELECT location
FROM covid_deaths
WHERE continent IS NULL
GROUP BY location
ORDER BY location;

-- 3. Every deaths row has a matching vaccinations row (safe to INNER JOIN)
SELECT COUNT(*) AS unmatched_rows
FROM covid_deaths d
LEFT JOIN covid_vaccinations v USING (location, date)
WHERE v.location IS NULL;

-- 4. Negative daily values = later corrections to earlier reports
SELECT COUNT(*) FILTER (WHERE new_cases  < 0) AS negative_case_days,
       COUNT(*) FILTER (WHERE new_deaths < 0) AS negative_death_days
FROM covid_deaths;

SELECT location, date, new_cases, new_deaths
FROM covid_deaths
WHERE location = 'India' AND (new_cases < 0 OR new_deaths < 0);

-- 5. Do India's daily numbers add up to the cumulative columns?
SELECT SUM(new_cases)    AS sum_daily_cases,
       MAX(total_cases)  AS reported_total_cases,
       SUM(new_deaths)   AS sum_daily_deaths,
       MAX(total_deaths) AS reported_total_deaths
FROM covid_deaths
WHERE location = 'India';

-- 6. Same check for vaccinations. These do NOT match: new_vaccinations
--    has missing days, so a running SUM(new_vaccinations) undercounts.
--    Also, doses != people (one person can get two doses).
--    => use total_vaccinations for doses and people_vaccinated for people.
SELECT SUM(new_vaccinations)       AS sum_daily_doses,
       MAX(total_vaccinations)     AS reported_total_doses,
       MAX(people_vaccinated)      AS people_with_at_least_one_dose,
       COUNT(*) FILTER (WHERE date >= '2021-01-16' AND new_vaccinations IS NULL) AS missing_days_since_rollout
FROM covid_vaccinations
WHERE location = 'India';
