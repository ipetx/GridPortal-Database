-- =============================================
-- Register Drill-Down Stored Procedures
-- Adds sp_Grid_Bus_Aclines and sp_Grid_Bus_Transformers to registry
-- =============================================

-- Register sp_Grid_Bus_Aclines
INSERT INTO "StoredProcedureRegistry" (
    "ProcedureName",
    "DisplayName",
    "Description",
    "Category",
    "DatabaseName",
    "IsActive",
    "RequiresAuth",
    "AllowedRoles",
    "DefaultPageSize",
    "MaxPageSize",
    "CacheDurationSeconds",
    "CreatedAt"
)
VALUES (
    'sp_Grid_Bus_Aclines',
    'Bus AClines',
    'Displays all AClines connected to a specific bus',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager', 'User'],
    15,
    100,
    0,
    NOW()
)
ON CONFLICT ("ProcedureName")
DO UPDATE SET
    "DisplayName" = EXCLUDED."DisplayName",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "UpdatedAt" = NOW();

-- Register sp_Grid_Bus_Transformers
INSERT INTO "StoredProcedureRegistry" (
    "ProcedureName",
    "DisplayName",
    "Description",
    "Category",
    "DatabaseName",
    "IsActive",
    "RequiresAuth",
    "AllowedRoles",
    "DefaultPageSize",
    "MaxPageSize",
    "CacheDurationSeconds",
    "CreatedAt"
)
VALUES (
    'sp_Grid_Bus_Transformers',
    'Bus Transformers',
    'Displays all Transformers connected to a specific bus',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager', 'User'],
    15,
    100,
    0,
    NOW()
)
ON CONFLICT ("ProcedureName")
DO UPDATE SET
    "DisplayName" = EXCLUDED."DisplayName",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "UpdatedAt" = NOW();

-- Verify registrations
SELECT 
    "ProcedureName",
    "DisplayName",
    "Description",
    "IsActive"
FROM "StoredProcedureRegistry"
WHERE "ProcedureName" IN ('sp_Grid_Bus_Aclines', 'sp_Grid_Bus_Transformers');

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Drill-down procedures registered successfully!';
END $$;
