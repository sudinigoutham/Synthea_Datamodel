-- Databricks notebook source
DECLARE OR REPLACE VARIABLE catalog_name STRING DEFAULT "Molina_EIM_Lab_WS";
DECLARE OR REPLACE VARIABLE schema_name STRING DEFAULT "synthea";
DECLARE OR REPLACE VARIABLE drop_tables BOOLEAN DEFAULT true;

-- COMMAND ----------

SET VARIABLE catalog_name = :catalog_name; 
SET VARIABLE schema_name = :schema_name;
SET VARIABLE drop_tables = CASE WHEN :drop_tables = 'true' THEN true ELSE false END;

-- COMMAND ----------

select catalog_name, schema_name, drop_tables;

-- COMMAND ----------

USE IDENTIFIER(catalog_name || "." || schema_name);

-- COMMAND ----------

SELECT current_catalog(), current_schema();

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE landing_volume_path STRING DEFAULT "/Volumes/" || catalog_name || "/" || schema_name || "/landing/";

SELECT landing_volume_path;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## CREATE STREAMING TABLES 
-- MAGIC *** 
-- MAGIC
-- MAGIC `{ CREATE OR REFRESH STREAMING TABLE | CREATE STREAMING TABLE [ IF NOT EXISTS ] }  
-- MAGIC   table_name  
-- MAGIC   [ table_specification ]  
-- MAGIC   [ table_clauses ]  
-- MAGIC   [ AS query ]`
-- MAGIC
-- MAGIC `table_specification
-- MAGIC   ( { column_identifier column_type [column_properties] } [, ...]
-- MAGIC     [ CONSTRAINT expectation_name EXPECT (expectation_expr)
-- MAGIC       [ ON VIOLATION { FAIL UPDATE | DROP ROW } ] ] [, ...]
-- MAGIC     [ , table_constraint ] [...] )`
-- MAGIC
-- MAGIC `column_properties
-- MAGIC   { NOT NULL |
-- MAGIC     COMMENT column_comment |
-- MAGIC     column_constraint |
-- MAGIC     MASK clause } [ ... ]`
-- MAGIC
-- MAGIC `table_clauses
-- MAGIC   { PARTITIONED BY (col [, ...]) |
-- MAGIC     COMMENT table_comment |
-- MAGIC     TBLPROPERTIES clause |
-- MAGIC     SCHEDULE [ REFRESH ] schedule_clause |
-- MAGIC     WITH { ROW FILTER clause } } [...]`
-- MAGIC
-- MAGIC `schedule_clause
-- MAGIC   { EVERY number { HOUR | HOURS | DAY | DAYS | WEEK | WEEKS } |
-- MAGIC   CRON cron_string [ AT TIME ZONE timezone_id ] }`
-- MAGIC

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE table_name STRING;
DECLARE OR REPLACE VARIABLE bronze_table_name STRING; 

SET VARIABLE table_name =:table_name;
SET VARIABLE bronze_table_name = table_name || "_bronze";

SELECT table_name, bronze_table_name;

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE drop_bronze_stmnt STRING; 
DECLARE OR REPLACE VARIABLE drop_table_stmnt STRING;

SET VARIABLE drop_bronze_stmnt = CASE 
  WHEN drop_tables = true THEN "DROP TABLE IF EXISTS " || bronze_table_name || ";"
  ELSE "SELECT 'Skipping drop bronze table statement.' AS message;" 
END;

SET VARIABLE drop_table_stmnt = CASE
  WHEN drop_tables = true THEN "DROP TABLE IF EXISTS " || table_name || ";"
  ELSE "SELECT 'Skipping drop table statement.' as message;"
END;

SELECT drop_bronze_stmnt, drop_table_stmnt;

-- COMMAND ----------

EXECUTE IMMEDIATE drop_bronze_stmnt;

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE bronze_table_specification STRING;

SET VARIABLE bronze_table_specification = "
  (
    file_metadata STRUCT < file_path: STRING,
    file_name: STRING,
    file_size: BIGINT,
    file_block_start: BIGINT,
    file_block_length: BIGINT,
    file_modification_time: TIMESTAMP > NOT NULL COMMENT 'Metadata about the file ingested.',
    ingest_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP() COMMENT 'The date timestamp the file was ingested.',
    value STRING COMMENT 'The raw CSV file contents.'
  )
"

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE bronze_table_clauses STRING; 

SET VARIABLE bronze_table_clauses = "
  COMMENT 'Raw snythethic patient data CSV files ingested from the landing volume for the " || table_name || " data set.'
  TBLPROPERTIES (
    'quality' = 'bronze'
  )
"

-- COMMAND ----------

DECLARE OR REPLACE VARIABLE crst_bronze_stmnt STRING; 

SET VARIABLE crst_bronze_stmnt = "CREATE OR REFRESH STREAMING TABLE IDENTIFIER(bronze_table_name) 
" || bronze_table_specification || bronze_table_clauses || " 
AS SELECT
  _metadata as file_metadata
  ,* 
FROM STREAM read_files(
  '" || landing_volume_path || table_name || "/'
  ,format => 'csv'
  ,header => true
  ,schema => 'value STRING'
  ,delimiter => '~'
  ,multiLine => false
  ,encoding => 'UTF-8'
  ,ignoreLeadingWhiteSpace => true
  ,ignoreTrailingWhiteSpace => true
  ,mode => 'FAILFAST'
)";

SELECT crst_bronze_stmnt;

-- COMMAND ----------

EXECUTE IMMEDIATE crst_bronze_stmnt;

-- COMMAND ----------

SHOW CREATE TABLE IDENTIFIER(bronze_table_name);

-- COMMAND ----------

SELECT * FROM IDENTIFIER(bronze_table_name)
