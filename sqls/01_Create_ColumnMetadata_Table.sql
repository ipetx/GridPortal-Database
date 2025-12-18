-- =============================================
-- ColumnMetadata Table Creation
-- Run this on your DEFAULT/CENTRAL database
-- This table stores dropdown configuration for all grids
-- =============================================

-- Create ColumnMetadata table
CREATE TABLE IF NOT EXISTS "ColumnMetadata" (
    "Id" SERIAL PRIMARY KEY,
    "ProcedureName" VARCHAR(255) NOT NULL,
    "ColumnName" VARCHAR(255) NOT NULL,
    "CellEditor" VARCHAR(50),
    "DropdownType" VARCHAR(20), -- 'static' or 'dynamic'
    "StaticValuesJson" TEXT, -- JSON array for static dropdowns
    "MasterTable" VARCHAR(255), -- Table name for dynamic dropdowns
    "ValueField" VARCHAR(255), -- Column name for value
    "LabelField" VARCHAR(255), -- Column name for label
    "FilterCondition" TEXT, -- WHERE clause with placeholders
    "DependsOnJson" TEXT, -- JSON array of column names this dropdown depends on
    "IsActive" BOOLEAN DEFAULT true,
    "CreatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "UpdatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "UQ_ColumnMetadata_Proc_Column" UNIQUE ("ProcedureName", "ColumnName")
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS "IDX_ColumnMetadata_Procedure" 
ON "ColumnMetadata" ("ProcedureName", "IsActive");

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'ColumnMetadata table created successfully!';
END $$;
