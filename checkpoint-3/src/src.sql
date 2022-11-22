--- ASHLEY QUITERIO
--- VISUALIZATIONS HERE: https://observablehq.com/d/739623968cf9599f

---For each Chicago police district, calculate officers per capita.
DROP TABLE IF EXISTS officers_per_capita;
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
SELECT *
FROM officers_per_capita;


--- Finding the racial distribution of officers in a district in percentages
DROP TABLE IF EXISTS racial_breakdown_per_district;
CREATE TEMP TABLE racial_breakdown_per_district AS
    ( WITH
          raw_counts AS
            (SELECT dp.id unit_id, dp.description, race, COUNT(*) officer_count
             FROM data_officer o JOIN data_policeunit dp on o.last_unit_id = dp.id
             WHERE resignation_date IS NOT NULL AND last_unit_id < 27
             GROUP BY dp.id, unit_name, description, race
             ORDER BY dp.id),
          officer_races AS
             (SELECT DISTINCT race
              FROM data_officer),
          officers_per_district AS
              (SELECT DISTINCT unit_id,
                               CASE WHEN o.race = r.race THEN r.race ELSE o.race END race,
                               CASE WHEN o.race = r.race THEN officer_count ELSE 0 END officer_count
               FROM raw_counts r, officer_races o
               WHERE (r.race = o.race) OR o.race NOT IN
                                          (SELECT r2.race
                                           FROM raw_counts r2
                                           where r2.description = r.description)
               ORDER BY unit_id, race),
          officers_all_district AS
              (SELECT last_unit_id, COUNT(*) all_district_officers
               FROM data_officer
               WHERE resignation_date IS NOT NULL AND last_unit_id < 27
               GROUP BY last_unit_id),
          officer_race_pctage AS
              (SELECT unit_id, description, race, (officer_count::float / all_district_officers) * 100.0 pct_officers
               FROM officers_per_district o
                   JOIN officers_all_district a ON a.last_unit_id = o.unit_id
                   JOIN data_policeunit dp ON dp.id = o.unit_id)
      SELECT * FROM officer_race_pctage);

SELECT unit_id-1 as unit_number, race, pct_officers
FROM racial_breakdown_per_district;

--- add the polygons
DROP TABLE IF EXISTS district_polygons;
CREATE TEMP TABLE district_polygons AS
    (SELECT dp.id unit_id, ST_AsGeoJSON(a.polygon, 4)::json polygon
     FROM data_policeunit dp JOIN data_area a ON left(name, -2)::INT = unit_name::INT
     WHERE area_type = 'police-districts');

--- joining the two tables so that the polygons overlap with the officers racial distributions
DROP TABLE IF EXISTS district_officer_racial_makeup;
CREATE TEMP TABLE district_officer_racial_makeup AS
    ( SELECT r.*, d.polygon
      FROM racial_breakdown_per_district r
          JOIN district_polygons d ON d.unit_id = r.unit_id);

SELECT *
FROM district_officer_racial_makeup;

--- Pivot table for the data to go into the map
DROP TABLE IF EXISTS pivot_officer_racial_makeup;
CREATE TEMP TABLE pivot_officer_racial_makeup AS
SELECT description,
       SUM(CASE race WHEN 'White' THEN pct_officers END) AS pct_white, --here you pivot each status value as a separate column explicitly
       SUM(CASE race WHEN 'Black' THEN pct_officers END) AS pct_black, --here you pivot each status  value as a separate column explicitly
       SUM(CASE race WHEN 'Hispanic' THEN pct_officers END) AS pct_hispanic,
       SUM(CASE race WHEN 'Asian/Pacific' THEN pct_officers END) AS pct_asian,
       SUM(CASE race WHEN 'Native American/Alaskan Native' THEN pct_officers END) AS pct_native,
       SUM(CASE race WHEN 'Unknown' THEN pct_officers END) AS pct_other

FROM district_officer_racial_makeup
GROUP BY description;

select *
from pivot_officer_racial_makeup;

--- Create the Geojson file for download
SELECT row_to_json(fc) as data_geometry
FROM (SELECT 'FeatureCollection' As type, array_to_json(array_agg(f)) As features
      FROM (SELECT 'Feature' As type
                 ,dorm.polygon As geometry
                 , row_to_json((SELECT l
                                FROM (SELECT DISTINCT lg.description, opc.name,
                                                      round(pct_white::decimal,2) as pct_white,
                                                      round(pct_asian::decimal,2) as pct_asian,
                                                      round(pct_black::decimal,2) as pct_black,
                                                      round(pct_hispanic::decimal,2) as pct_hispanic,
                                                      round(pct_native::decimal,2) as pct_native,
                                                      round(pct_other::decimal,2) as pct_other,
                                                      opc.population,
                                                      round(opc.officers_per_capita::decimal,2) as officers_per_capita,
                                                      round(opc.officers_per_10k_civ::decimal,2) as officers_per_10k_civ) As l
          )) As properties
            FROM pivot_officer_racial_makeup As lg
                JOIN district_officer_racial_makeup dorm on lg.description = dorm.description
                JOIN officers_per_capita opc on dorm.unit_id = opc.unit_id
            ) As f) As fc;


-- ----- PART 2
--- Update the names of the racial categories
--- Address some of the messiness of the data since officer races were
-- differently labelled than resident races
DROP TABLE IF EXISTS racial_breakdown_officers_2;
CREATE TEMP TABLE racial_breakdown_officers_2 AS
    SELECT unit_id-1 as unit_number, race, pct_officers,
    (CASE race
           WHEN 'White' THEN 'White'
           WHEN 'Black' THEN 'Black'
           WHEN 'Hispanic' THEN 'Hispanic'
           WHEN 'Native American/Alaskan Native' THEN 'Native American/Alaskan Native'
           WHEN 'Asian/Pacific' THEN 'Asian/Pacific Islander'
           WHEN 'Unknown' THEN 'Other/Unknown'
           END) AS race_2
    FROM racial_breakdown_per_district
    GROUP BY unit_id, race, description, pct_officers;

select *
from racial_breakdown_officers_2;


--- Finding the population racial distribution of each Chicago district
DROP TABLE IF EXISTS pop_race_distr;
CREATE TEMP TABLE pop_race_distr AS
(SELECT description, name, pop_per_cap.race, population
FROM (SELECT u.description, u.id unit_id, area_id, name, SUM(count) population, p.race
         FROM data_racepopulation p
            JOIN data_area a ON a.id = p.area_id
            JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
         WHERE area_type = 'police-districts'
         GROUP BY u.id, area_id, name, p.race) AS pop_per_cap);

SELECT *
FROM pop_race_distr;

--- calculated percentages of the population and
-- ensure that all racial categories are accounted for
DROP TABLE IF EXISTS racial_breakdown_residents;
CREATE TEMP TABLE racial_breakdown_residents AS
    ( WITH
          raw_counts_pop AS
            (SELECT description, name, pop_per_cap.race, population
            FROM (SELECT u.description, u.id unit_id, area_id, name, SUM(count) population, p.race
                    FROM data_racepopulation p
                    JOIN data_area a ON a.id = p.area_id
                    JOIN data_policeunit u ON left(name, -2)::INT = u.unit_name::INT
                    WHERE area_type = 'police-districts'
                    GROUP BY u.id, area_id, name, p.race)
                AS pop_per_cap),
          resident_races AS
             (SELECT DISTINCT race
              FROM data_racepopulation),
          pop_per_district AS
              (SELECT DISTINCT name,
                               CASE WHEN r.race = p.race THEN p.race ELSE r.race END race,
                               CASE WHEN r.race = p.race THEN population ELSE 0 END pop_count
               FROM raw_counts_pop p, resident_races r
               WHERE (p.race = r.race) OR r.race NOT IN
                                          (SELECT p2.race
                                           FROM raw_counts_pop p2
                                           where p2.name = p.name)
               ORDER BY name, race),
          pop_all_district AS
              (SELECT name, population as all_district_pop
               FROM officers_per_capita),
          pop_race_pctage AS
              (SELECT o.name, race, (pop_count::float / all_district_pop) * 100.0 pct_pop
               FROM pop_per_district o
                   JOIN pop_all_district a ON a.name = o.name)
      SELECT * FROM pop_race_pctage);

SELECT *
FROM racial_breakdown_residents;


--- Combine between work from part 1 and part 2 to create the final table needed for part 2
--- This produces the table of which each combination of district name and race has the percentage
-- of officers and residents that belong to that intersection.
SELECT a.name, rbr.race, pct_officers,pct_pop
FROM racial_breakdown_officers_2 ro
    JOIN data_area a ON ro.unit_number::INT = left(a.name, -2)::INT
    JOIN racial_breakdown_residents rbr on a.name = rbr.name and rbr.race=ro.race_2
WHERE a.area_type='police-districts'
ORDER BY name;