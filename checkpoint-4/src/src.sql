-- QUESTION 1:
-- Quantile dot plots: When discussing quantile dot plots, I reference this code about making them.
-- Pulling from their paper, Matthew Kay, Tara Kola, Jessica Hullman, Sean Munson, created this tool
-- to think about distributions of event likelihood. I am able to explore the question of officer density
-- in areas. I was curious if we could predict or better understand the range of officer density at the
-- district level within a day? Using quantile dot plots, I will predict/estimate how many officers are in
-- a district on any given day using the number of officers in relation to the population size, district
-- area, and time spent.

-- Create table with area of districts as square miles
DROP table IF EXISTS areas_p;
CREATE TEMP table areas_p AS
SELECT name, ST_AREA(st_transform(st_setsrid(ST_ASGeojson(a.polygon:: geometry), 4326),
    31467))/ 1609.34^2/2 area
FROM data_area a
WHERE area_type='police-districts';

-- Create table to calculate officer per capita rates by district
DROP TABLE IF EXISTS officers_per_capita;
CREATE TEMP TABLE officers_per_capita AS
    ( WITH population_per_district AS
        (SELECT u.id unit_id, area_id, name, SUM(count) population, ST_ASGeojson(a.polygon) polygon
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, a.polygon)
      SELECT p.unit_id, p.name, population, COUNT(*) num_officers, population/COUNT(*)::FLOAT officers_per_capita,
             10000/(population/COUNT(*)::FLOAT) officers_per_10k_civ, p.polygon
      FROM data_officer o
          JOIN population_per_district p ON p.unit_id = o.last_unit_id
      WHERE resignation_date IS NULL
      GROUP BY p.unit_id, population, p.name, p.polygon
      ORDER BY officers_per_10k_civ);

SELECT *
FROM officers_per_capita;

-- Combine the first two tables into one to compare officers per capita with area of district
DROP TABLE IF EXISTS rate_and_sqmi;
create temp table rate_and_sqmi AS
SELECT unit_id, ap.name, population, num_officers,o.officers_per_capita, officers_per_10k_civ, area,
       o.population/ ap.area pop_per_sqmi, o.num_officers/ ap.area officers_per_sqmi
FROM officers_per_capita o JOIN areas_p ap on o.name= ap.name;

-- Calculate the number of hours worked each year per district
DROP TABLE IF EXISTS unit_hrs_yr_old;
CREATE TEMP TABLE unit_hrs_yr_old AS
    (WITH hours_worked AS
        (SELECT unit_id, EXTRACT(year FROM start_timestamp AT TIME ZONE 'America/Chicago') start_year,
                EXTRACT(epoch FROM end_timestamp - start_timestamp)/3600.0 hours_worked
         FROM data_officerassignmentattendance
         WHERE present_for_duty),
    hours_per_year AS (
         SELECT unit_id, start_year, SUM(hours_worked) total_hrs
         FROM hours_worked
         GROUP BY unit_id, start_year),
    avg_hr_yr AS (
         SELECT unit_id, AVG(total_hrs) avg_hr_yr
         FROM hours_per_year
         GROUP BY unit_id),
    population_per_district AS
        (SELECT u.id unit_id, area_id, left(name, -2)::INT unit_num, unit_name, u.description unit_description,
         SUM(count) population
         FROM data_racepopulation p
             JOIN data_area a ON a.id = p.area_id
             JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, polygon)
     SELECT a.unit_id, unit_num, unit_name, unit_description, avg_hr_yr, population
     FROM avg_hr_yr a
         JOIN population_per_district p ON a.unit_id = p.unit_id);

-- Convert these numbers to find the number of people working each day
DROP TABLE IF EXISTS officer_hours;
create temp table officer_hours AS
SELECT *, avg_hr_yr / 365 officer_hours_per_day
FROM unit_hrs_yr_old
ORDER BY avg_hr_yr, population;

-- This table culminates all the different sections above to show how the 12 districts are distributed
-- in relation to districts, resident sizes, officer rates as spread and density.
DROP TABLE IF EXISTS part_1;
create temp table part_1 AS
select name, officer_hours.population, num_officers, area::FLOAT area_sqmi, pop_per_sqmi, officers_per_sqmi,
       officers_per_capita, officers_per_10k_civ, avg_hr_yr, officer_hours_per_day,
       officer_hours_per_day/ 8 officer_per_day,  (officer_hours_per_day/8)/area avg_o_per_sqmi_ea_day,
        ((officer_hours_per_day/8)/area)/ rate_and_sqmi.pop_per_sqmi chance_in_same_spot
from rate_and_sqmi JOIN officer_hours on officer_hours.unit_id = rate_and_sqmi.unit_id;

-- FULL CSV FOR PART 1
select *
from part_1;

-- CALCULATING NECESSARY VALUES
select avg(avg_o_per_sqmi_ea_day), stddev(avg_o_per_sqmi_ea_day), avg(pop_per_sqmi),
       avg(chance_in_same_spot), stddev(chance_in_same_spot)
from part_1;


-- QUESTION 2:
-- From part 1, I am exploring how officers might be distributed across a space over time. I am then curious how
-- might officers be spending their time. Although we do not have an in depth look into where they were, a dimension
-- of the time they spent in the district is reflected in the number of allegation counts they received. I will use a
-- decision tree model to predict whether officers received at least one allegation in their time based on their
-- average number of hours spent on duty in a given year.


-- calculating the number of hours worked by each individual officer
DROP TABLE IF EXISTS hours_worked_per_officer;
CREATE TEMP TABLE hours_worked_per_officer AS
SELECT officer_id, unit, EXTRACT(year FROM start_timestamp AT TIME ZONE 'America/Chicago') start_year,
       EXTRACT(epoch FROM end_timestamp - start_timestamp)/3600.0 length, start_timestamp, end_timestamp
FROM data_officerassignmentattendance;

---  Finding shift lengths across all officers
DROP TABLE IF EXISTS hours_worked_by_OID;
CREATE TEMP TABLE hours_worked_by_OID AS
SELECT officer_id, unit, start_year, SUM(length) hours_worked_by_oid_in_yr, COUNT(*) total_num_shifts
FROM hours_worked_per_officer
GROUP BY officer_id, unit, start_year;

--- 86,632 unique combinations with 13,768 distinct officer ids
select *
from hours_worked_by_OID;

---- Joining tables to get information across different features
DROP TABLE IF EXISTS o_alleg_count;
CREATE TEMP TABLE o_alleg_count AS
SELECT d.officer_id, o.unit, EXTRACT(year FROM incident_date AT TIME ZONE 'America/Chicago') incident_yr, COUNT(*) case_counts
FROM data_allegation
JOIN data_officerallegation d on data_allegation.crid = d.allegation_id
JOIN data_officerassignmentattendance o on d.officer_id = o.officer_id
where incident_date BETWEEN start_timestamp AND end_timestamp AND present_for_duty
GROUP BY o.unit, d.officer_id, EXTRACT(year FROM incident_date AT TIME ZONE 'America/Chicago');

SELECT *
FROM o_alleg_count;

-- Combining the tables from above
DROP TABLE IF EXISTS hrs_worked_and_alleg;
CREATE TEMP TABLE hrs_worked_and_alleg AS
SELECT hw.officer_id, oac.unit, start_year AS year, hours_worked_by_oid_in_yr, total_num_shifts, case_counts
FROM hours_worked_by_OID hw
   FULL OUTER JOIN o_alleg_count oac on hw.officer_id = oac.officer_id AND hw.start_year = oac.incident_yr;

SELECT *
FROM hrs_worked_and_alleg;

-- Cleaning the allegation counts
DROP TABLE IF EXISTS hrs_worked_and_alleg_clean;
CREATE TEMP TABLE hrs_worked_and_alleg_clean AS
SELECT officer_id, unit, year, hours_worked_by_oid_in_yr, total_num_shifts, CASE
    WHEN case_counts IS NULL THEN 0
    ELSE case_counts end AS case_counts_clean
FROM hrs_worked_and_alleg;

SELECT *
FROM hrs_worked_and_alleg_clean;

-- Combining the final data sets.
DROP TABLE IF EXISTS officer_hrs_alleg;
CREATE TEMP TABLE officer_hrs_alleg AS
SELECT hwaac.*, race, gender, birth_year,allegation_count, trr_count
FROM hrs_worked_and_alleg_clean hwaac JOIN data_officer d_o ON hwaac.officer_id = d_o.id;

-- FINAL OUTPUT TABLE TO DOWNLOAD AS A CSV FOR THE COLAB NOTEBOOK
select *
from officer_hrs_alleg;


