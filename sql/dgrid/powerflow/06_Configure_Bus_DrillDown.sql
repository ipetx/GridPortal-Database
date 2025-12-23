-- =============================================
-- Configure Drill-Down Links for Bus Grid
-- Enables clickable ACline and Transformer counts
-- =============================================

-- Configure ACline Count column for drill-down
-- Use INSERT ON CONFLICT to handle existing rows
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "LinkConfig",
    "IsActive"
)
VALUES (
    'sp_Grid_Buses',
    'aclineCount',
    NULL,
    '{
      "enabled": true,
      "routePath": null,
      "drillDown": {
        "enabled": true,
        "targetProcedure": "sp_Grid_Bus_Aclines",
        "filterParams": [
          {
            "targetColumn": "BusNumber",
            "sourceFields": ["ibus"]
          },
          {
            "targetColumn": "CaseNumber",
            "sourceFields": ["CaseNumber"]
          }
        ],
        "breadcrumbLabel": "{name} - AClines"
      }
    }'::JSONB,
    true
)
ON CONFLICT ("ProcedureName", "ColumnName")
DO UPDATE SET
    "LinkConfig" = EXCLUDED."LinkConfig",
    "IsActive" = EXCLUDED."IsActive";

-- Configure Transformer Count column for drill-down
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "LinkConfig",
    "IsActive"
)
VALUES (
    'sp_Grid_Buses',
    'transformerCount',
    NULL,
    '{
      "enabled": true,
      "routePath": null,
      "drillDown": {
        "enabled": true,
        "targetProcedure": "sp_Grid_Bus_Transformers",
        "filterParams": [
          {
            "targetColumn": "BusNumber",
            "sourceFields": ["ibus"]
          },
          {
            "targetColumn": "CaseNumber",
            "sourceFields": ["CaseNumber"]
          }
        ],
        "breadcrumbLabel": "{name} - Transformers"
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
WHERE "ProcedureName" = 'sp_Grid_Buses' 
  AND "ColumnName" IN ('aclineCount', 'transformerCount');

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Drill-down configuration completed successfully!';
    RAISE NOTICE 'ACline count and Transformer count columns are now clickable';
END $$;
