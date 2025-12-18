-- =============================================
-- Add LinkConfig column to ColumnMetadata table
-- Enables configurable clickable column links
-- =============================================

-- Add LinkConfig column
ALTER TABLE "ColumnMetadata" 
ADD COLUMN IF NOT EXISTS "LinkConfig" JSONB;

-- Add column comment
COMMENT ON COLUMN "ColumnMetadata"."LinkConfig" IS 
'Configuration for clickable column links. JSON structure:
{
  "enabled": boolean,
  "routePath": string,
  "openInNewTab": boolean,
  "params": [
    {
      "name": string,
      "fields": string[],
      "separator": string (optional)
    }
  ]
}';

-- Example: Configure Name column in Bus grid as clickable
UPDATE "ColumnMetadata"
SET "LinkConfig" = '{
  "enabled": true,
  "routePath": "/bus-details",
  "openInNewTab": false,
  "params": [
    {
      "name": "busId",
      "fields": ["ibus", "CaseNumber"],
      "separator": "_"
    },
    {
      "name": "areaCode",
      "fields": ["iarea"]
    },
    {
      "name": "zoneId",
      "fields": ["zone"]
    }
  ]
}'::JSONB
WHERE "ProcedureName" = 'sp_Grid_Buses' 
  AND "ColumnName" = 'name';

-- Verify the configuration
SELECT 
    "ProcedureName",
    "ColumnName",
    "LinkConfig"
FROM "ColumnMetadata"
WHERE "LinkConfig" IS NOT NULL
ORDER BY "ProcedureName", "ColumnName";

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'LinkConfig column added successfully to ColumnMetadata table!';
    RAISE NOTICE 'Name column configured with clickable link for sp_Grid_Buses';
END $$;
