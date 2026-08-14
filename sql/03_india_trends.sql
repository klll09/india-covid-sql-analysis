-- =====================================================================
-- 03_india_trends.sql
-- How the pandemic unfolded in India, Jan 2020 - Apr 2021.
-- =====================================================================

-- 1. India snapshot on the last date in the data
SELECT d.date,
       d.population,
       d.total_cases,
       d.total_deaths,
       ROUND(d.total_deaths / d.total_cases * 100, 2)        AS case_fatality_rate_pct,
       ROUND(d.total_cases  / d.population  * 100, 2)        AS pct_population_infected,
       ROUND(d.total_deaths / d.population  * 1000000, 1)    AS deaths_per_million,
       v.total_tests,
       ROUND(d.total_cases / v.total_tests * 100, 2)         AS overall_positivity_pct
FROM covid_deaths d
JOIN covid_vaccinations v USING (location, date)
WHERE d.location = 'India'
  AND d.date = (SELECT MAX(date) FROM covid_deaths);


-- 2. Month by month: cases, deaths, fatality rate and month-over-month growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', date)::date AS month,
           SUM(new_cases)  AS cases,
           SUM(new_deaths) AS deaths
    FROM covid_deaths
    WHERE location = 'India'
    GROUP BY 1
)
SELECT month,
       cases,
       deaths,
       ROUND(deaths / NULLIF(cases, 0) * 100, 2)                               AS monthly_cfr_pct,
       ROUND((cases - LAG(cases) OVER (ORDER BY month))
             / NULLIF(LAG(cases) OVER (ORDER BY month), 0) * 100, 1)           AS cases_mom_growth_pct
FROM monthly
WHERE cases > 0
ORDER BY month;


-- 3. The two waves: peak 7-day average in each.
--    Wave 1 = 2020, Wave 2 = 2021. A 7-day moving average smooths out
--    weekend reporting dips.
WITH smoothed AS (
    SELECT date,
           new_cases,
           AVG(new_cases)  OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS cases_7day_avg,
           AVG(new_deaths) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS deaths_7day_avg
    FROM covid_deaths
    WHERE location = 'India'
),
ranked AS (
    SELECT CASE WHEN date < '2021-01-01' THEN 'Wave 1 (2020)' ELSE 'Wave 2 (2021)' END AS wave,
           date,
           ROUND(cases_7day_avg)  AS peak_cases_7day_avg,
           ROUND(deaths_7day_avg) AS deaths_7day_avg_that_day,
           ROW_NUMBER() OVER (PARTITION BY date < '2021-01-01' ORDER BY cases_7day_avg DESC) AS rn
    FROM smoothed
)
SELECT wave, date AS peak_date, peak_cases_7day_avg, deaths_7day_avg_that_day
FROM ranked
WHERE rn = 1
ORDER BY peak_date;


-- 4. How fast did the second wave grow? Week-over-week change.
WITH weekly AS (
    SELECT DATE_TRUNC('week', date)::date AS week_start,
           SUM(new_cases) AS cases,
           COUNT(*)       AS days_in_week
    FROM covid_deaths
    WHERE location = 'India' AND date >= '2021-02-01'
    GROUP BY 1
)
SELECT week_start,
       cases,
       ROUND((cases / LAG(cases) OVER (ORDER BY week_start) - 1) * 100, 1) AS wow_growth_pct
FROM weekly
WHERE days_in_week = 7          -- drop the partial last week
ORDER BY week_start;


-- 5. Testing: did testing keep up? Weekly test positivity rate.
--    WHO guidance: positivity above 5% suggests too little testing.
SELECT DATE_TRUNC('week', date)::date      AS week_start,
       SUM(d.new_cases)                     AS cases,
       SUM(v.new_tests)                     AS tests,
       ROUND(SUM(d.new_cases) / NULLIF(SUM(v.new_tests), 0) * 100, 1) AS positivity_pct
FROM covid_deaths d
JOIN covid_vaccinations v USING (location, date)
WHERE location = 'India' AND date >= '2020-04-01'
GROUP BY 1
HAVING COUNT(*) = 7
ORDER BY 1;
