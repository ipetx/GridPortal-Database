-- Register the Bus update stored procedure in the registry
INSERT INTO "StoredProcedureRegistry" (
    "ProcedureName",
    "DisplayName",
    "Description",
    "Category",
    "IsActive",
    "RequiresAuth",
    "AllowedRoles",
    "DefaultPageSize",
    "MaxPageSize",
    "CreatedAt",
    "UpdatedAt"
)
VALUES (
    'sp_Grid_Update_Bus',
    'Update Bus',
    'Update a bus record in the Bus table',
    'Power System',
    true,
    true,
    '["Admin", "Manager"]'::jsonb,
    1,
    1,
    NOW(),
    NOW()
)
ON CONFLICT ("ProcedureName") DO UPDATE SET
    "IsActive" = true,
    "UpdatedAt" = NOW();
