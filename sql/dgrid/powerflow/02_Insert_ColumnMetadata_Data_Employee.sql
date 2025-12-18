-- =============================================
-- ColumnMetadata Data Insert
-- Run this AFTER creating the ColumnMetadata table
-- Inserts dropdown configuration for sp_Grid_Employee
-- =============================================

-- Insert dropdown configurations for sp_Grid_Employee

-- 1. Status - Static Dropdown
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "DropdownType",
    "StaticValuesJson",
    "IsActive"
) VALUES (
    'sp_Grid_Employee',
    'Status',
    'dropdown',
    'static',
    '[
        {"value": "Active", "label": "Active"},
        {"value": "On Leave", "label": "On Leave"},
        {"value": "Terminated", "label": "Terminated"}
    ]',
    true
)
ON CONFLICT ("ProcedureName", "ColumnName") 
DO UPDATE SET
    "DropdownType" = EXCLUDED."DropdownType",
    "StaticValuesJson" = EXCLUDED."StaticValuesJson",
    "UpdatedAt" = CURRENT_TIMESTAMP;

-- 2. GroupId - Dynamic Dropdown (Independent)
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
    'sp_Grid_Employee',
    'GroupId',
    'dropdown',
    'dynamic',
    'Groups',
    'Id',
    'Name',
    '"IsActive" = true',
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

-- 3. DepartmentId - Dynamic Dropdown (Cascading from GroupId)
INSERT INTO "ColumnMetadata" (
    "ProcedureName",
    "ColumnName",
    "CellEditor",
    "DropdownType",
    "MasterTable",
    "ValueField",
    "LabelField",
    "FilterCondition",
    "DependsOnJson",
    "IsActive"
) VALUES (
    'sp_Grid_Employee',
    'DepartmentId',
    'dropdown',
    'dynamic',
    'Departments',
    'Id',
    'Name',
    '"GroupId" = @param_GroupId AND "IsActive" = true',
    '["GroupId"]',
    true
)
ON CONFLICT ("ProcedureName", "ColumnName") 
DO UPDATE SET
    "DropdownType" = EXCLUDED."DropdownType",
    "MasterTable" = EXCLUDED."MasterTable",
    "ValueField" = EXCLUDED."ValueField",
    "LabelField" = EXCLUDED."LabelField",
    "FilterCondition" = EXCLUDED."FilterCondition",
    "DependsOnJson" = EXCLUDED."DependsOnJson",
    "UpdatedAt" = CURRENT_TIMESTAMP;

-- Verify inserts
SELECT 
    "ColumnName",
    "DropdownType",
    "MasterTable",
    "DependsOnJson"
FROM "ColumnMetadata"
WHERE "ProcedureName" = 'sp_Grid_Employee'
ORDER BY "ColumnName";

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Dropdown configurations inserted successfully!';
END $$;
