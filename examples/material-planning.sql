-- Material planning demonstration. All records below are synthetic.
-- SQLite 3.25+; run: sqlite3 :memory: < examples/material-planning.sql
PRAGMA foreign_keys = ON;
CREATE TABLE projects(project_id INTEGER PRIMARY KEY, project_name TEXT NOT NULL);
CREATE TABLE materials(material_id INTEGER PRIMARY KEY, material_name TEXT NOT NULL, unit TEXT NOT NULL);
CREATE TABLE requirements(project_id INTEGER REFERENCES projects, material_id INTEGER REFERENCES materials,
 required_qty REAL NOT NULL CHECK(required_qty>=0), PRIMARY KEY(project_id,material_id));
CREATE TABLE inventory(material_id INTEGER PRIMARY KEY REFERENCES materials, available_qty REAL NOT NULL CHECK(available_qty>=0));
INSERT INTO projects VALUES (1,'Courtyard Residence'),(2,'Studio Renovation'),(3,'Office Fit-out');
INSERT INTO materials VALUES (1,'Cement','bags'),(2,'Floor tile','m2'),(3,'Steel','kg'),(4,'Paint','litres');
INSERT INTO requirements VALUES (1,1,120),(1,2,180),(1,3,950),(1,4,60),(2,1,35),(2,2,85),(2,3,150),(2,4,40),(3,1,45),(3,2,135),(3,3,300),(3,4,90);
INSERT INTO inventory VALUES (1,160),(2,275),(3,1600),(4,110);

-- Aggregate demand before joining inventory so stock is not double-counted.
CREATE VIEW material_plan AS
WITH demand AS (
 SELECT material_id,SUM(required_qty) AS required_qty,COUNT(DISTINCT project_id) AS project_count
 FROM requirements GROUP BY material_id
), comparison AS (
 SELECT m.material_id,m.material_name,m.unit,d.project_count,d.required_qty,
 COALESCE(i.available_qty,0) AS available_qty,
 MAX(d.required_qty-COALESCE(i.available_qty,0),0) AS shortage_qty
 FROM demand d JOIN materials m USING(material_id) LEFT JOIN inventory i USING(material_id)
)
SELECT *,ROUND(100.0*shortage_qty/NULLIF(required_qty,0),1) AS shortage_pct,
 DENSE_RANK() OVER(ORDER BY 1.0*shortage_qty/NULLIF(required_qty,0) DESC) AS priority_rank
FROM comparison;
SELECT * FROM material_plan ORDER BY priority_rank,material_name;

-- Drill down without summing incompatible units across different materials.
SELECT p.project_name,m.material_name,m.unit,r.required_qty,
 ROUND(100.0*r.required_qty/SUM(r.required_qty) OVER(PARTITION BY r.material_id),1) AS share_of_material_demand_pct
FROM requirements r JOIN projects p USING(project_id) JOIN materials m USING(material_id)
ORDER BY m.material_name,p.project_name;
