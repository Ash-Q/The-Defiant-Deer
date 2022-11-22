-- Q1: For each Chicago police district, how many officers per capita are deployed to it?
-- (this means officers with a resignation date of NULL, example of per capita is "1 officer
-- per 1000 people"), according to the most current year of the data.

CREATE TEMP TABLE officers_per_capita AS
    ( WITH population_per_district AS
        (SELECT u.id unit_id, area_id, name, SUM(count) population, ST_ASGeojson(a.polygon) polygon
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, a.polygon)
      SELECT p.unit_id, p.name, population, COUNT(*), population/COUNT(*)::FLOAT officers_per_capita,
             10000/(population/COUNT(*)::FLOAT) officers_per_10k_civ, p.polygon
      FROM data_officer o
          JOIN population_per_district p ON p.unit_id = o.last_unit_id
      WHERE resignation_date IS NULL
      GROUP BY p.unit_id, population, p.name, p.polygon
      ORDER BY officers_per_10k_civ);

SELECT *, ROW_NUMBER () OVER (ORDER BY officers_per_capita)
FROM officers_per_capita;


-- Q2: For the two districts with the most and least (min and max) officers per capita,
-- what is their racial distribution?

-- PART 1: MAX
CREATE TEMP TABLE max_capita_race_distr AS
SELECT name, pop_per_cap.race, population
FROM (SELECT u.id unit_id, area_id, name, SUM(count) population, p.race
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, p.race) AS pop_per_cap
WHERE name = (SELECT name
                FROM officers_per_capita
                    WHERE  officers_per_10k_civ =
                           (SELECT MAX(officers_per_capita.officers_per_10k_civ)
                                FROM officers_per_capita))
ORDER BY population;

SELECT name, race, population, population/ (SELECT sum(population) FROM max_capita_race_distr) proportion
FROM max_capita_race_distr
GROUP BY name, race, population
ORDER BY proportion;

-- PART 2: MIN
CREATE TEMP TABLE min_capita_race_distr AS
SELECT name, pop_per_cap.race, population
FROM (SELECT u.id unit_id, area_id, name, SUM(count) population, p.race
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, p.race) AS pop_per_cap
WHERE name = (SELECT name
                FROM officers_per_capita
                    WHERE officers_per_10k_civ =
                           (SELECT MIN(officers_per_capita.officers_per_10k_civ)
                                FROM officers_per_capita))
ORDER BY population;

SELECT name, race, population, population/ (SELECT sum(population) FROM min_capita_race_distr) proportion
FROM min_capita_race_distr
GROUP BY name, race, population
ORDER BY proportion;

-- PART 3A: Average
SELECT AVG(officers_per_10k_civ)
FROM officers_per_capita;
-- Average of the rate for officers_per_10k_civ is 33.49521992223351
-- The district with the closest rate of officers_per_10k_civ is the 20th District

-- PART 3B: Average o_per_10k rate
CREATE TEMP TABLE avg_capita_race_distr AS
(SELECT name, pop_per_cap.race, population
FROM (SELECT u.id unit_id, area_id, name, SUM(count) population, p.race
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, p.race) AS pop_per_cap
WHERE name = '20th'
ORDER BY population);

SELECT name, race, population, population/ (SELECT sum(population) FROM avg_capita_race_distr) proportion
FROM avg_capita_race_distr
GROUP BY name, race, population
ORDER BY proportion;


-- Q3: What districts have the most officer hours allocated to them per capita?
CREATE TEMP TABLE unit_hrs_yr AS
(WITH hours_worked AS
    (SELECT unit::INT, EXTRACT(year FROM start_timestamp AT TIME ZONE 'America/Chicago') start_year,
            EXTRACT(epoch FROM end_timestamp - start_timestamp)/3600.0 hours_worked
    FROM data_officerassignmentattendance
    WHERE present_for_duty),
hours_per_year AS (
    SELECT unit, start_year, SUM(hours_worked) total_hrs
    FROM hours_worked
    GROUP BY unit, start_year),
avg_hr_yr AS (
    SELECT unit, AVG(total_hrs) avg_hr_yr
    FROM hours_per_year
    GROUP BY unit),
population_per_district AS
        (SELECT u.id unit_id, area_id, left(name, -2)::INT unit_num, SUM(count) population
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name)
SELECT a.unit, avg_hr_yr, population
FROM avg_hr_yr a
JOIN population_per_district p ON a.unit = p.unit_num);

--- Averaging by population
SELECT unit, avg_hr_yr, population, avg_hr_yr/population avg_hr_per_person_yr
FROM unit_hrs_yr
ORDER BY avg_hr_per_person_yr DESC;

--- Averaging by the officers per capita and officers per 10k civillians
SELECT unit, avg_hr_yr, u.population, opc.officers_per_capita, avg_hr_yr/u.population avg_hr_per_person_yr,
       avg_hr_yr/opc.officers_per_capita hr_per_o_capita, avg_hr_yr/opc.officers_per_10k_civ hr_per_off_10k
FROM unit_hrs_yr u JOIN officers_per_capita opc on u.population = opc.population
ORDER BY avg_hr_per_person_yr DESC;


-- Q4: What is the per capita complaint rate for the top 5 districts with the highest officer deployment rate?

WITH population_per_district AS
        (SELECT u.id unit_id, area_id, left(name, -2)::INT unit_num, SUM(count) population
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name)
SELECT u.unit, COUNT(*) allegation_cnt, u.population,population/COUNT(*)::FLOAT person_per_alleg,
       u.avg_hr_yr/population avg_hr_per_person_yr
FROM data_allegation da
    JOIN data_area a ON ST_INTERSECTS(a.polygon, da.point)
    JOIN unit_hrs_yr u ON u.unit = left(name, -2)::INT
WHERE area_type='police-districts'
GROUP BY name, u.population, u.unit, u.avg_hr_yr, u.avg_hr_yr/population
ORDER BY avg_hr_per_person_yr DESC;

