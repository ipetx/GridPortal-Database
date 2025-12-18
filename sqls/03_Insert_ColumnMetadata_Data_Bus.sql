-- =============================================
-- ColumnMetadata Configuration for Bus Grid
-- Add this to your ColumnMetadata table (Bus Database)
-- =============================================

-- Zone dropdown (dynamic, loads from Zone table)
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "DropdownType",
    "MasterTable",
    "ValueField",
    "LabelField",
    "FilterCondition",
    "IsActive"
) VALUES (
    'sp_Grid_Buses',
    'zone',
    'dropdown',
    'dynamic',
    'Zone',
    'izone',
    'zoname',
    '"CaseNumber" = @param_CaseNumber',
    true
)
ON CONFLICT ("ProcedureName", "ColumnName") 
DO UPDATE SET
    "DropdownType" = EXCLUDED."DropdownType",
    "MasterTable" = EXCLUDED."MasterTable",
    "ValueField" = EXCLUDED."ValueField",
    "LabelField" = EXCLUDED."LabelField",
    "FilterCondition" = EXCLUDED."FilterCondition",
    "UpdatedAt" = CURRENT_TIMESTAMP;

-- Verify insert
SELECT 
    "ColumnName",
    "DropdownType",
    "MasterTable",
    "ValueField",
    "LabelField",
    "FilterCondition"
FROM "ColumnMetadata"
WHERE "ProcedureName" = 'sp_Grid_Buses'
ORDER BY "ColumnName";

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Zone dropdown configuration added for sp_Grid_Buses!';
END $$;
