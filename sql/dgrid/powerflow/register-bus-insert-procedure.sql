-- =============================================
-- Register sp_grid_insert_bus in StoredProcedureRegistry
-- This allows the DynamicGrid service to discover and use the insert procedure
-- =============================================

-- Insert the procedure into the registry
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
    "DatabaseName",
    "CreatedAt",
    "UpdatedAt"
)
VALUES (
    'sp_grid_insert_bus',
    'Insert Bus',
    'Insert a new bus record into the Bus table',
    'Power System',
    true,
    true,
    '["Admin", "Manager", "User"]'::json,  -- Adjust roles as needed
    15,
    1000,
    'PowerSystemDB',  -- Same database as sp_Grid_Buses
    NOW(),
    NOW()
)
ON CONFLICT ("ProcedureName") 
DO UPDATE SET
    "IsActive" = EXCLUDED."IsActive",
    "AllowedRoles" = EXCLUDED."AllowedRoles",
    "UpdatedAt" = NOW();

-- Verify the registration
SELECT 
    "Id",
    "ProcedureName",
    "DisplayName",
    "IsActive",
    "AllowedRoles"
FROM "StoredProcedureRegistry"
WHERE "ProcedureName" = 'sp_grid_insert_bus';
