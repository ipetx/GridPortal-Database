-- =============================================
-- Register Update and Delete Procedures for AClines and Transformers
-- =============================================

-- Delete existing entries if they exist (to avoid duplicate key errors)
DELETE FROM "StoredProcedureRegistry"
WHERE "ProcedureName" IN (
    'sp_Grid_Update_Bus_Aclines',
    'sp_Grid_Delete_Bus_Aclines',
    'sp_Grid_Update_Bus_Transformers',
    'sp_Grid_Delete_Bus_Transformers'
);

-- Register sp_Grid_Update_Bus_Aclines
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
    'sp_Grid_Update_Bus_Aclines',
    'Update Bus ACline',
    'Updates a single ACline record',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager'],
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

-- Register sp_Grid_Delete_Bus_Aclines
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
    'sp_Grid_Delete_Bus_Aclines',
    'Delete Bus ACline',
    'Deletes a single ACline record',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager'],
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

-- Register sp_Grid_Update_Bus_Transformers
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
    'sp_Grid_Update_Bus_Transformers',
    'Update Bus Transformer',
    'Updates a single Transformer record',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager'],
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

-- Register sp_Grid_Delete_Bus_Transformers
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
    'sp_Grid_Delete_Bus_Transformers',
    'Delete Bus Transformer',
    'Deletes a single Transformer record',
    'Grid',
    'PowerSystem',
    true,
    true,
    ARRAY['Admin', 'Manager'],
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
WHERE "ProcedureName" IN (
    'sp_Grid_Update_Bus_Aclines',
    'sp_Grid_Delete_Bus_Aclines',
    'sp_Grid_Update_Bus_Transformers',
    'sp_Grid_Delete_Bus_Transformers'
);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Update and Delete procedures registered successfully!';
END $$;
