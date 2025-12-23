-- =============================================
-- Configure Drill-Down Links for Transformer Grid
-- Enables clickable From Bus and To Bus columns
-- =============================================

-- Configure From Bus (ibus) column for drill-down to Bus grid
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "LinkConfig",
    "IsActive"
)
VALUES (
    'sp_Grid_Bus_Transformers',
    'ibus',
    NULL,
    '{
      "enabled": true,
      "routePath": null,
      "drillDown": {
        "enabled": true,
        "targetProcedure": "sp_Grid_Buses",
        "filterParams": [
          {
            "targetColumn": "ibus",
            "sourceFields": ["ibus"]
          },
          {
            "targetColumn": "CaseNumber",
            "sourceFields": ["CaseNumber"]
          }
        ],
        "breadcrumbLabel": "Bus {ibus}"
      }
    }'::JSONB,
    true
)
ON CONFLICT ("ProcedureName", "ColumnName")
DO UPDATE SET
    "LinkConfig" = EXCLUDED."LinkConfig",
    "IsActive" = EXCLUDED."IsActive";

-- Configure To Bus (jbus) column for drill-down to Bus grid
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "LinkConfig",
    "IsActive"
)
VALUES (
    'sp_Grid_Bus_Transformers',
    'jbus',
    NULL,
    '{
      "enabled": true,
      "routePath": null,
      "drillDown": {
        "enabled": true,
        "targetProcedure": "sp_Grid_Buses",
        "filterParams": [
          {
            "targetColumn": "ibus",
            "sourceFields": ["jbus"]
          },
          {
            "targetColumn": "CaseNumber",
            "sourceFields": ["CaseNumber"]
          }
        ],
        "breadcrumbLabel": "Bus {jbus}"
      }
    }'::JSONB,
    true
)
ON CONFLICT ("ProcedureName", "ColumnName")
DO UPDATE SET
    "LinkConfig" = EXCLUDED."LinkConfig",
    "IsActive" = EXCLUDED."IsActive";

-- Verify configurations
SELECT 
    "Id",
    "ProcedureName",
    "ColumnName",
    "LinkConfig"
FROM "ColumnMetadata"
WHERE "ProcedureName" = 'sp_Grid_Bus_Transformers' 
  AND "ColumnName" IN ('ibus', 'jbus');

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Transformer drill-down configuration completed successfully!';
    RAISE NOTICE 'From Bus (ibus) and To Bus (jbus) columns are now clickable';
    RAISE NOTICE 'Clicking these columns will drill down to the Bus grid filtered by that bus number';
END $$;
