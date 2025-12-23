-- =============================================
-- Remove Column-Level maxDepth and allowMultipleLevels
-- These are now controlled globally via appsettings.json
-- =============================================

-- Update Bus grid drill-down configurations
UPDATE "ColumnMetadata"
SET "LinkConfig" = jsonb_set(
    jsonb_set(
        "LinkConfig",
        '{drillDown}',
        "LinkConfig"->'drillDown' - 'maxDepth' - 'allowMultipleLevels'
    ),
    '{drillDown}',
    "LinkConfig"->'drillDown'
)
WHERE "ProcedureName" = 'sp_Grid_Buses'
  AND "ColumnName" IN ('aclineCount', 'transformerCount')
  AND "LinkConfig"->'drillDown' IS NOT NULL;

-- Update Transformer grid drill-down configurations  
UPDATE "ColumnMetadata"
SET "LinkConfig" = jsonb_set(
    jsonb_set(
        "LinkConfig",
        '{drillDown}',
        "LinkConfig"->'drillDown' - 'maxDepth' - 'allowMultipleLevels'
    ),
    '{drillDown}',
    "LinkConfig"->'drillDown'
)
WHERE "ProcedureName" = 'sp_Grid_Bus_Transformers'
  AND "ColumnName" IN ('ibus', 'jbus')
  AND "LinkConfig"->'drillDown' IS NOT NULL;

-- Verify the changes
SELECT 
    "ProcedureName",
    "ColumnName",
    "LinkConfig"->'drillDown' as "DrillDownConfig"
FROM "ColumnMetadata"
WHERE "ProcedureName" IN ('sp_Grid_Buses', 'sp_Grid_Bus_Transformers')
  AND "LinkConfig"->'drillDown' IS NOT NULL;

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Successfully removed column-level maxDepth and allowMultipleLevels';
    RAISE NOTICE 'Drill-down depth is now controlled globally via appsettings.json';
END $$;
