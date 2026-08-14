-- =====================================================================
-- 06_views.sql
-- Reusable views - connect Tableau / Power BI / Excel straight to these.
-- =====================================================================

-- India: one row per day with smoothed trends and vaccination progress
CREATE OR REPLACE VIEW v_india_daily AS
SELECT d.date,
       d.new_cases,
       d.new_deaths,
       ROUND(AVG(d.new_cases)  OVER w7)                             AS cases_7day_avg,
       ROUND(AVG(d.new_deaths) OVER w7)                             AS deaths_7day_avg,
       d.total_cases,
       d.total_deaths,
       ROUND(d.total_deaths / NULLIF(d.total_cases, 0) * 100, 2)    AS cfr_pct,
       v.new_tests,
       ROUND(d.new_cases / NULLIF(v.new_tests, 0) * 100, 1)         AS positivity_pct,
       v.total_vaccinations                                         AS doses_to_date,
       ROUND(v.people_vaccinated / d.population * 100, 2)           AS pct_at_least_one_dose
FROM covid_deaths d
JOIN covid_vaccinations v USING (location, date)
WHERE d.location = 'India'
WINDOW w7 AS (ORDER BY d.date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW);


-- Every country's latest cumulative figures (countries only, no aggregates)
CREATE OR REPLACE VIEW v_country_snapshot AS
SELECT d.location,
       MAX(d.continent)                                             AS continent,
       MAX(d.population)                                            AS population,
       MAX(d.total_cases)                                           AS total_cases,
       MAX(d.total_deaths)                                          AS total_deaths,
       ROUND(MAX(d.total_cases)  / MAX(d.population) * 100, 2)        AS pct_infected,
       ROUND(MAX(d.total_deaths) / MAX(d.population) * 1000000, 1)    AS deaths_per_million,
       ROUND(MAX(d.total_deaths) / NULLIF(MAX(d.total_cases), 0) * 100, 2) AS cfr_pct,
       MAX(v.total_vaccinations)                                    AS doses,
       ROUND(MAX(v.people_vaccinated) / MAX(d.population) * 100, 2)   AS pct_at_least_one_dose,
       MAX(v.median_age)                                            AS median_age
FROM covid_deaths d
JOIN covid_vaccinations v USING (location, date)
WHERE d.continent IS NOT NULL
GROUP BY d.location;


-- Continent totals built correctly from country totals
CREATE OR REPLACE VIEW v_continent_deaths AS
SELECT continent,
       SUM(total_deaths) AS total_deaths,
       SUM(population)   AS population,
       ROUND(SUM(total_deaths) / SUM(population) * 1000000, 1) AS deaths_per_million
FROM v_country_snapshot
GROUP BY continent;


-- Quick check that the views work
SELECT * FROM v_continent_deaths ORDER BY total_deaths DESC;
SELECT location, total_cases, deaths_per_million, pct_at_least_one_dose
FROM v_country_snapshot
WHERE location = 'India';
