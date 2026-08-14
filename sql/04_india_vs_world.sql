-- =====================================================================
-- 04_india_vs_world.sql
-- Where does India stand compared with other countries?
-- =====================================================================

-- 1. One row per country with its latest cumulative numbers.
--    Used by the ranking queries below.
WITH latest AS (
    SELECT DISTINCT ON (location)
           location, continent, population, total_cases, total_deaths
    FROM covid_deaths
    WHERE continent IS NOT NULL            -- exclude 'World', 'Asia', etc.
      AND total_cases IS NOT NULL
    ORDER BY location, date DESC
),
ranked AS (
    SELECT location,
           total_cases,
           total_deaths,
           ROUND(total_deaths / population * 1000000, 1)   AS deaths_per_million,
           ROUND(total_cases  / population * 100, 2)       AS pct_infected,
           RANK() OVER (ORDER BY total_cases  DESC)                    AS rank_cases,
           RANK() OVER (ORDER BY total_deaths DESC NULLS LAST)         AS rank_deaths,
           RANK() OVER (ORDER BY total_deaths / population DESC NULLS LAST) AS rank_deaths_per_million,
           COUNT(*) OVER ()                                            AS countries
    FROM latest
)
-- India's rank in absolute numbers vs. per-person numbers
SELECT *
FROM ranked
WHERE location = 'India';


-- 2. Global case fatality rate vs India
--    (SUM of daily values over countries only, so aggregates aren't double-counted)
SELECT 'World' AS area,
       SUM(new_cases)  AS cases,
       SUM(new_deaths) AS deaths,
       ROUND(SUM(new_deaths) / SUM(new_cases) * 100, 2) AS cfr_pct
FROM covid_deaths
WHERE continent IS NOT NULL
UNION ALL
SELECT 'India',
       SUM(new_cases),
       SUM(new_deaths),
       ROUND(SUM(new_deaths) / SUM(new_cases) * 100, 2)
FROM covid_deaths
WHERE location = 'India';


-- 3. India vs South Asian neighbours and other large countries.
--    Cumulative columns only grow, so MAX() gives the latest value.
--    (Taking the last row instead fails here: many countries didn't
--    report total_tests on 30 Apr, so that row is NULL.)
SELECT d.location,
       MAX(v.median_age)                                         AS median_age,
       ROUND(MAX(d.total_cases)  / MAX(d.population) * 100, 2)     AS pct_infected,
       ROUND(MAX(d.total_deaths) / MAX(d.population) * 1000000, 1) AS deaths_per_million,
       ROUND(MAX(d.total_deaths) / MAX(d.total_cases) * 100, 2)    AS cfr_pct,
       ROUND(MAX(v.total_tests)  / MAX(d.population) * 1000, 1)    AS tests_per_1000
FROM covid_deaths d
JOIN covid_vaccinations v USING (location, date)
WHERE d.location IN ('India', 'Pakistan', 'Bangladesh', 'Sri Lanka', 'Nepal',
                     'United States', 'Brazil', 'Indonesia', 'United Kingdom')
GROUP BY d.location
ORDER BY deaths_per_million DESC;


-- 4. Is a younger population linked to fewer deaths per million?
--    Group countries into age quartiles with NTILE and compare.
WITH latest AS (
    SELECT DISTINCT ON (d.location)
           d.location, d.population, d.total_deaths, v.median_age
    FROM covid_deaths d
    JOIN covid_vaccinations v USING (location, date)
    WHERE d.continent IS NOT NULL
      AND v.median_age IS NOT NULL
      AND d.total_deaths IS NOT NULL
    ORDER BY d.location, d.date DESC
),
bucketed AS (
    SELECT *, NTILE(4) OVER (ORDER BY median_age) AS age_quartile
    FROM latest
)
SELECT age_quartile,
       MIN(median_age) || ' - ' || MAX(median_age)                    AS median_age_range,
       COUNT(*)                                                        AS countries,
       ROUND(SUM(total_deaths) / SUM(population) * 1000000, 1)         AS deaths_per_million,
       BOOL_OR(location = 'India')                                     AS includes_india
FROM bucketed
GROUP BY age_quartile
ORDER BY age_quartile;


-- 5. Deaths by continent - the RIGHT way.
--    A common mistake is MAX(total_deaths) GROUP BY continent: that returns
--    the single worst-hit country in each continent, not the continent total.
--    Correct approach: take each country's latest total, then SUM per continent.
WITH country_totals AS (
    SELECT continent, location, MAX(total_deaths) AS deaths
    FROM covid_deaths
    WHERE continent IS NOT NULL
    GROUP BY continent, location
)
SELECT continent,
       SUM(deaths)                         AS correct_total_deaths,
       MAX(deaths)                         AS wrong_max_method,
       ROUND(MAX(deaths) / SUM(deaths) * 100, 1) AS wrong_method_captures_pct
FROM country_totals
GROUP BY continent
ORDER BY correct_total_deaths DESC;
