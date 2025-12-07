
--CREATE USER kmzuser WITH PASSWORD 'openmap';
--GRANT ALL PRIVILEGES ON DATABASE mydata TO kmzuser;

CREATE OR REPLACE FUNCTION oim_max_int(txt text)
RETURNS int
LANGUAGE sql IMMUTABLE AS $$
WITH m AS (
  SELECT (mm[1])::int AS v
  FROM regexp_matches(COALESCE(txt,''), '([0-9]+)', 'g') AS mm
)
SELECT CASE WHEN EXISTS (SELECT 1 FROM m)
            THEN (SELECT MAX(v) FROM m)
            ELSE NULL END;
$$;

CREATE OR REPLACE FUNCTION oim_to_numeric(val text)
RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
           WHEN val IS NULL THEN NULL
           ELSE NULLIF( regexp_replace(val, '[^0-9\.\-]+', '', 'g'), '' )::numeric
         END;
$$;

DROP VIEW IF EXISTS 
power_switch, 
power_compensator, 
power_generator_area, 
power_generator, 
power_plant_point, 
power_plant, 
power_substation_point, 
power_substation, 
power_tower, 
power_line 
CASCADE; 

-- TLines（line）
CREATE VIEW power_line AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Multi(ST_Transform(g.way,3857))::geometry(MULTILINESTRING,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
oim_max_int(NULLIF(g.tags->'voltage','')) AS voltage, 
oim_max_int(NULLIF(g.tags->'circuits','')) AS circuits, 
oim_max_int(NULLIF(g.tags->'cables','')) AS cables, 
COALESCE(NULLIF(g."power",''), g.tags->'power') AS "power" 
FROM "tx__line" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') IN ('line','minor_line','cable'); 

-- Towers（polygon） 
CREATE VIEW power_tower AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(NULLIF(g."power",''), g.tags->'power') AS "power", 
COALESCE(g.tags->'tower:type', g.tags->'pole:type') AS tower_type 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') IN ('tower','pole','portal','mast','catenary_mast'); 

-- Substations（polygon） 
CREATE VIEW power_substation AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Multi(ST_Transform(g.way,3857))::geometry(MULTIPOLYGON,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
g.tags->'substation' AS "substation" 
FROM "tx__polygon" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'substation'; 

-- Substations（point） 
CREATE VIEW power_substation_point AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
g.tags->'substation' AS "substation" 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'substation'; 

-- Plants（polygon） 
CREATE VIEW power_plant AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Multi(ST_Transform(g.way,3857))::geometry(MULTIPOLYGON,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(g.tags->'plant:source', g.tags->'source') AS source 
FROM "tx__polygon" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'plant'; 

-- powerplant（point） 
CREATE VIEW power_plant_point AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(g.tags->'plant:source', g.tags->'source') AS source 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'plant'; 

-- generators（point） 
CREATE VIEW power_generator AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(g.tags->'generator:source', g.tags->'source') AS source, 
CASE 
WHEN NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '') IS NULL 
THEN NULL 
WHEN COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity') ILIKE '%kw%' 
THEN oim_to_numeric(NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '')) / 1000.0 
ELSE oim_to_numeric(NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '')) 
END AS mw 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'generator'; 

-- generators（polygon） 
CREATE VIEW power_generator_area AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Multi(ST_Transform(g.way,3857))::geometry(MULTIPOLYGON,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(g.tags->'generator:source', g.tags->'source') AS source, 
CASE 
WHEN NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '') IS NULL 
THEN NULL 
WHEN COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity') ILIKE '%kw%' 
THEN oim_to_numeric(NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '')) / 1000.0 
ELSE oim_to_numeric(NULLIF(COALESCE(g.tags->'generator:output:electricity', g.tags->'output:electricity'), '')) 
END AS mw 
FROM "tx__polygon" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'generator'; 

-- compensators（point） 
CREATE VIEW power_compensator AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(NULLIF(g."power",''), g.tags->'power') AS "power" 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'compensator'; 

-- Switches（point） 
CREATE VIEW power_switch AS 
SELECT 
g.osm_id::bigint AS id, 
ST_Transform(g.way,3857)::geometry(POINT,3857) AS geom, 
COALESCE(NULLIF(g."name",''), g.tags->'name') AS name, 
COALESCE(NULLIF(g."operator",''), g.tags->'operator') AS operator, 
COALESCE(NULLIF(g."power",''), g.tags->'power') AS "power" 
FROM "tx__point" g 
WHERE COALESCE(NULLIF(g."power",''), g.tags->'power') = 'switch';
