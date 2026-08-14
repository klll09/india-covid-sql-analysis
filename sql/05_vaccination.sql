-- =====================================================================
-- 05_vaccination.sql
-- India's vaccine rollout (started 16 Jan 2021).
-- Remember from 02_data_quality.sql:
--   total_vaccinations = doses given,  people_vaccinated = people with 1+ dose
-- =====================================================================

-- 1. Rolling vaccination progress with a CTE + window functions.
--    - running doses: carry the last reported total forward over missing days
--    - 7-day average of daily doses
WITH daily AS (
    SELECT d.date,
           d.population,
           v.new_vaccinations,
           v.total_vaccinations,
           v.people_vaccinated,
           v.people_fully_vaccinated,
           -- number each "reported" value so missing days join the group of
           -- the last reported day (a standard trick to forward-fill in SQL)
           COUNT(v.total_vaccinations) OVER (ORDER BY d.date) AS grp
    FROM covid_deaths d
    JOIN covid_vaccinations v USING (location, date)
    WHERE d.location = 'India' AND d.date >= '2021-01-16'
),
filled AS (
    SELECT *,
           MAX(total_vaccinations) OVER (PARTITION BY grp) AS doses_to_date
    FROM daily
)
SELECT date,
       new_vaccinations,
       ROUND(AVG(new_vaccinations) OVER (ORDER BY date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)) AS doses_7day_avg,
       doses_to_date,
       ROUND(doses_to_date / population * 100, 2)                         AS doses_per_100_people,
       ROUND(people_vaccinated / population * 100, 2)                     AS pct_at_least_one_dose,
       ROUND(people_fully_vaccinated / population * 100, 2)               AS pct_fully_vaccinated
FROM filled
ORDER BY date;


-- 2. Milestones: first day India crossed each 25M-dose mark
WITH milestones AS (
    SELECT generate_series(25000000, 150000000, 25000000) AS doses
)
SELECT m.doses AS milestone,
       MIN(v.date) AS date_reached,
       MIN(v.date) - DATE '2021-01-16' AS days_since_rollout
FROM milestones m
JOIN covid_vaccinations v
  ON v.location = 'India' AND v.total_vaccinations >= m.doses
GROUP BY m.doses
ORDER BY m.doses;


-- 3. India's global rank: absolute doses vs doses per 100 people.
WITH country AS (
    SELECT d.location,
           MAX(v.total_vaccinations)                         AS doses,
           MAX(v.total_vaccinations) / MAX(d.population) * 100 AS doses_per_100
    FROM covid_deaths d
    JOIN covid_vaccinations v USING (location, date)
    WHERE d.continent IS NOT NULL
    GROUP BY d.location
    HAVING MAX(v.total_vaccinations) IS NOT NULL
),
ranked AS (
    SELECT location,
           doses,
           ROUND(doses_per_100, 1) AS doses_per_100,
           RANK() OVER (ORDER BY doses DESC)         AS rank_total_doses,
           RANK() OVER (ORDER BY doses_per_100 DESC) AS rank_per_100,
           COUNT(*) OVER ()                          AS countries_reporting
    FROM country
)
SELECT * FROM ranked
WHERE location = 'India' OR rank_total_doses <= 3
ORDER BY rank_total_doses;


-- 4. Days needed to give everyone two doses at the April 2021 pace
--    (a simple projection - assumes the pace stays flat).
WITH april AS (
    SELECT AVG(new_vaccinations)  AS avg_daily_doses,
           MAX(total_vaccinations) AS doses_so_far,
           MAX(population)         AS population
    FROM covid_vaccinations v
    JOIN covid_deaths d USING (location, date)
    WHERE location = 'India' AND date BETWEEN '2021-04-01' AND '2021-04-30'
)
SELECT ROUND(avg_daily_doses)                                     AS avg_daily_doses_april,
       ROUND((population * 2 - doses_so_far) / avg_daily_doses)   AS days_to_two_doses_for_all,
       ROUND((population * 2 - doses_so_far) / avg_daily_doses / 365, 1) AS years_to_two_doses_for_all
FROM april;
