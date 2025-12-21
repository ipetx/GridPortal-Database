-- =============================================
-- Grid Procedure Scaffolder (Procedures Only)
-- =============================================
-- Generates all 3 procedures and returns registration SQL
-- to run in the main database separately
--
-- Usage Example:
--   SELECT Scaffold_Grid_Procedures(
--       p_table_name := 'Adjust',
--       p_entity_name := 'Bus_Adjusts',
--       p_display_name := 'Bus Adjustments',
--       p_primary_keys := ARRAY['acctap', 'casenumber'],
--       p_display_columns := ARRAY['acctap', 'casenumber', 'adjthr', 'mxswim', 'mxtpss', 'swvbnd'],
--       p_editable_columns := ARRAY['adjthr', 'mxswim', 'mxtpss', 'swvbnd'],
--       p_allowed_roles := ARRAY['Admin', 'Manager', 'User']
--   );
-- =============================================

CREATE OR REPLACE FUNCTION Scaffold_Grid_Procedures(
    p_table_name TEXT,              -- Database table name
    p_entity_name TEXT,             -- Entity name for procedures (e.g., 'Bus_Adjusts')
    p_display_name TEXT,            -- Display name for UI (e.g., 'Bus Adjustments')
    p_primary_keys TEXT[],          -- Primary key columns (case-insensitive)
    p_display_columns TEXT[],       -- All columns to display in grid
    p_editable_columns TEXT[],      -- Columns that can be edited
    p_allowed_roles TEXT[] DEFAULT ARRAY['Admin', 'Manager', 'User']  -- Roles with access
)
RETURNS TEXT AS $$
DECLARE
    v_fetch_proc_name TEXT;
    v_update_proc_name TEXT;
    v_delete_proc_name TEXT;
    v_fetch_sql TEXT;
    v_result TEXT := '';
BEGIN
    -- Build procedure names
    v_fetch_proc_name := 'sp_Grid_' || p_entity_name;
    v_update_proc_name := 'sp_Grid_Update_' || p_entity_name;
    v_delete_proc_name := 'sp_Grid_Delete_' || p_entity_name;
    
    v_result := format('🚀 Generating complete grid for %s...%s%s', p_table_name, E'\n', E'\n');
    
    -- ========================================
    -- 1. Generate FETCH procedure
    -- ========================================
    BEGIN
        v_fetch_sql := Generate_Grid_Fetch(
            p_table_name,
            p_entity_name,
            p_primary_keys,
            p_display_columns
        );
        
        -- Execute to create the procedure
        EXECUTE v_fetch_sql;
        
        v_result := v_result || format('✅ Created: %s%s', v_fetch_proc_name, E'\n');
    EXCEPTION
        WHEN OTHERS THEN
            v_result := v_result || format('❌ Failed to create %s: %s%s', v_fetch_proc_name, SQLERRM, E'\n');
            RAISE;
    END;
    
    -- ========================================
    -- 2. Generate UPDATE & DELETE procedures
    -- ========================================
    BEGIN
        PERFORM Generate_CRUD_Procedures(
            p_table_name,
            p_entity_name,
            p_primary_keys,
            p_editable_columns
        );
        
        v_result := v_result || format('✅ Created: %s%s', v_update_proc_name, E'\n');
        v_result := v_result || format('✅ Created: %s%s', v_delete_proc_name, E'\n');
    EXCEPTION
        WHEN OTHERS THEN
            v_result := v_result || format('❌ Failed to create UPDATE/DELETE: %s%s', SQLERRM, E'\n');
            RAISE;
    END;
    
    -- ========================================
    -- 3. Generate registration SQL
    -- ========================================
    v_result := v_result || E'\n' || format('
╔══════════════════════════════════════════════════════════════╗
║                    ✅ SUCCESS!                               ║
╠══════════════════════════════════════════════════════════════╣
║  Table: %s
║  Entity: %s
║
║  Created Procedures:
║    📊 %s
║    ✏️  %s
║    🗑️  %s
║
║  Next Steps:
║    1. Run the registration SQL below in your MAIN database
║    2. Customize %s (add JOINs, filters)
║    3. Restart backend
║    4. Test in UI!
╚══════════════════════════════════════════════════════════════╝

📝 REGISTRATION SQL (Run this in your MAIN database):
────────────────────────────────────────────────────────────────

%s

────────────────────────────────────────────────────────────────
',
        p_table_name,
        p_entity_name,
        v_fetch_proc_name,
        v_update_proc_name,
        v_delete_proc_name,
        v_fetch_proc_name,
        Generate_Registration_SQL(
            v_fetch_proc_name,
            v_update_proc_name,
            v_delete_proc_name,
            p_display_name,
            p_allowed_roles
        )
    );
    
    RETURN v_result;
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('❌ ERROR: %s%s%sPartial result:%s%s', 
            SQLERRM, E'\n', E'\n', E'\n', v_result);
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- Generate Registration SQL
-- =============================================
CREATE OR REPLACE FUNCTION Generate_Registration_SQL(
    p_fetch_proc_name TEXT,
    p_update_proc_name TEXT,
    p_delete_proc_name TEXT,
    p_display_name TEXT,
    p_allowed_roles TEXT[]
)
RETURNS TEXT AS $$
DECLARE
    v_roles_json TEXT;
BEGIN
    -- Format roles as JSON array: ["Admin","Manager","User"]
    v_roles_json := '[' || array_to_string(
        ARRAY(SELECT '"' || r || '"' FROM unnest(p_allowed_roles) r),
        ','
    ) || ']';
    
    RETURN format($SQL$-- Delete existing entries
DELETE FROM "StoredProcedureRegistry"
WHERE "ProcedureName" IN ('%s', '%s', '%s');

-- Register procedures
INSERT INTO "StoredProcedureRegistry" (
    "ProcedureName", "DisplayName", "Description", "Category", "DatabaseName",
    "IsActive", "RequiresAuth", "AllowedRoles", "DefaultPageSize", "MaxPageSize",
    "CacheDurationSeconds", "CreatedAt"
)
VALUES
    -- Fetch procedure
    ('%s', '%s', 'Displays %s data', 'Grid', 'Powerflow', 
     true, true, '%s', 15, 100, 0, NOW()),
    
    -- Update procedure (Admin/Manager only)
    ('%s', 'Update %s', 'Updates a single %s record', 'Grid', 'Powerflow',
     true, true, '["Admin","Manager"]', 15, 100, 0, NOW()),
    
    -- Delete procedure (Admin/Manager only)
    ('%s', 'Delete %s', 'Deletes a single %s record', 'Grid', 'Powerflow',
     true, true, '["Admin","Manager"]', 15, 100, 0, NOW())
ON CONFLICT ("ProcedureName")
DO UPDATE SET
    "DisplayName" = EXCLUDED."DisplayName",
    "Description" = EXCLUDED."Description",
    "IsActive" = EXCLUDED."IsActive",
    "AllowedRoles" = EXCLUDED."AllowedRoles",
    "UpdatedAt" = NOW();

-- Verify
SELECT "ProcedureName", "DisplayName", "IsActive", "AllowedRoles"
FROM "StoredProcedureRegistry"
WHERE "ProcedureName" IN ('%s', '%s', '%s');
$SQL$,
        p_fetch_proc_name, p_update_proc_name, p_delete_proc_name,  -- DELETE
        p_fetch_proc_name, p_display_name, p_display_name, v_roles_json,  -- Fetch (now JSON)
        p_update_proc_name, p_display_name, p_display_name,  -- Update
        p_delete_proc_name, p_display_name, p_display_name,  -- Delete
        p_fetch_proc_name, p_update_proc_name, p_delete_proc_name  -- Verify
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION Scaffold_Grid_Procedures TO PUBLIC;
GRANT EXECUTE ON FUNCTION Generate_Registration_SQL TO PUBLIC;

-- =============================================
-- Success Message
-- =============================================
DO $$
BEGIN
    RAISE NOTICE '╔══════════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║            Grid Procedure Scaffolder Ready!                  ║';
    RAISE NOTICE '╠══════════════════════════════════════════════════════════════╣';
    RAISE NOTICE '║  Creates all 3 procedures + returns registration SQL!        ║';
    RAISE NOTICE '╚══════════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage:';
    RAISE NOTICE '  SELECT Scaffold_Grid_Procedures(';
    RAISE NOTICE '      p_table_name := ''Adjust'',';
    RAISE NOTICE '      p_entity_name := ''Bus_Adjusts'',';
    RAISE NOTICE '      p_display_name := ''Bus Adjustments'',';
    RAISE NOTICE '      p_primary_keys := ARRAY[''acctap'', ''casenumber''],';
    RAISE NOTICE '      p_display_columns := ARRAY[''acctap'', ''casenumber'', ''adjthr''],';
    RAISE NOTICE '      p_editable_columns := ARRAY[''adjthr'', ''mxswim''],';
    RAISE NOTICE '      p_allowed_roles := ARRAY[''Admin'', ''Manager'', ''User'']';
    RAISE NOTICE '  );';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Result includes ready-to-run registration SQL!';
END $$;


-- =============================================
-- Enhanced Grid Fetch Procedure Generator
-- =============================================
-- Automatically detects correct column name casing from database schema
-- to prevent case sensitivity errors in PostgreSQL
--
-- Usage Example:
--   SELECT generate_grid_fetch_procedure(
--       'Acline',                                          -- table name
--       'Bus_Aclines',                                     -- entity name for procedure
--       ARRAY['ckt', 'ibus', 'jbus', 'CaseNumber'],       -- primary key columns (case-insensitive)
--       ARRAY['ckt', 'ibus', 'jbus', 'CaseNumber', 'name', 'rpu', 'xpu', 'bpu']  -- display columns (case-insensitive)
--   );
-- =============================================

CREATE OR REPLACE FUNCTION Generate_Grid_Fetch(
    p_table_name TEXT,           -- Actual table name (e.g., 'Acline')
    p_entity_name TEXT,          -- Entity name for procedure (e.g., 'Bus_Aclines')
    p_primary_key_cols TEXT[],   -- Array of primary key column names (case-insensitive)
    p_display_cols TEXT[]        -- Array of columns to display in grid (case-insensitive)
)
RETURNS TEXT AS $$
DECLARE
    v_proc_name TEXT;
    v_id_construction TEXT := '';
    v_select_fields TEXT := '';
    v_column_defs TEXT := '';
    v_col TEXT;
    v_actual_col_name TEXT;
    v_idx INT := 1;
    v_needs_quotes BOOLEAN;
BEGIN
    v_proc_name := 'sp_Grid_' || p_entity_name;
    
    -- Build ID construction (concatenate all PK columns with correct case)
    v_id_construction := '(';
    FOREACH v_col IN ARRAY p_primary_key_cols LOOP
        -- Get actual column name with correct case from database
        SELECT 
            column_name,
            column_name != lower(column_name)  -- Check if needs quotes
        INTO v_actual_col_name, v_needs_quotes
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        IF v_actual_col_name IS NULL THEN
            RAISE EXCEPTION 'Column % not found in table %', v_col, p_table_name;
        END IF;
        
        IF v_idx > 1 THEN
            v_id_construction := v_id_construction || ' || ''_'' || ';
        END IF;
        
        -- Add quotes if column has mixed case
        IF v_needs_quotes THEN
            v_id_construction := v_id_construction || 'a."' || v_actual_col_name || '"::TEXT';
        ELSE
            v_id_construction := v_id_construction || 'a.' || v_actual_col_name || '::TEXT';
        END IF;
        
        v_idx := v_idx + 1;
    END LOOP;
    v_id_construction := v_id_construction || ') AS "Id"';
    
    -- Build SELECT fields with correct case
    FOREACH v_col IN ARRAY p_display_cols LOOP
        -- Get actual column name with correct case
        SELECT 
            column_name,
            column_name != lower(column_name)
        INTO v_actual_col_name, v_needs_quotes
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        IF v_actual_col_name IS NULL THEN
            RAISE WARNING 'Column % not found in table %, skipping', v_col, p_table_name;
            CONTINUE;
        END IF;
        
        -- Add quotes if needed
        IF v_needs_quotes THEN
            v_select_fields := v_select_fields || format('            a."%s",%s', v_actual_col_name, E'\n');
        ELSE
            v_select_fields := v_select_fields || format('            a.%s,%s', v_actual_col_name, E'\n');
        END IF;
    END LOOP;
    v_select_fields := rtrim(v_select_fields, ',' || E'\n');
    
    -- Build column definitions (basic - user can customize)
    FOREACH v_col IN ARRAY p_display_cols LOOP
        -- Get actual column name
        SELECT column_name INTO v_actual_col_name
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        IF v_actual_col_name IS NULL THEN
            CONTINUE;
        END IF;
        
        v_column_defs := v_column_defs || format('        {"field": "%s", "headerName": "%s", "type": "text", "width": 120, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},%s',
            v_actual_col_name,
            initcap(replace(v_actual_col_name, '_', ' ')),  -- Convert snake_case to Title Case
            E'\n'
        );
    END LOOP;
    v_column_defs := rtrim(v_column_defs, ',' || E'\n');
    
    -- Get first PK column with correct case for ORDER BY
    SELECT column_name INTO v_actual_col_name
    FROM information_schema.columns
    WHERE table_name = p_table_name
      AND table_schema = 'public'
      AND lower(column_name) = lower(p_primary_key_cols[1])
    LIMIT 1;
    
    -- Check if ORDER BY column needs quotes
    SELECT column_name != lower(column_name) INTO v_needs_quotes
    FROM information_schema.columns
    WHERE table_name = p_table_name
      AND table_schema = 'public'
      AND lower(column_name) = lower(p_primary_key_cols[1])
    LIMIT 1;
    
    -- Generate the procedure SQL
    RETURN format($PROC$
-- Auto-generated FETCH procedure for %s
-- CUSTOMIZE: Add JOINs, filters, and adjust column definitions as needed
-- NOTE: Column names have been auto-detected with correct casing from database schema
CREATE OR REPLACE FUNCTION public.%s(
    p_PageNumber INTEGER DEFAULT 1,
    p_PageSize INTEGER DEFAULT 15,
    p_StartRow INTEGER DEFAULT NULL,
    p_EndRow INTEGER DEFAULT NULL,
    p_SortColumn VARCHAR DEFAULT NULL,
    p_SortDirection VARCHAR DEFAULT 'ASC',
    p_FilterJson TEXT DEFAULT NULL,
    p_SearchTerm VARCHAR DEFAULT NULL
)
RETURNS JSONB
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_Offset INT;
    v_FetchSize INT;
    v_Data JSONB;
    v_Columns JSONB;
    v_BaseColumns JSONB;
    v_TotalCount INT;
    -- TODO: Add filter parameter variables here (e.g., v_BusNumber INT;)
BEGIN
    -- Determine offset and fetch size
    IF p_StartRow IS NOT NULL AND p_EndRow IS NOT NULL THEN
        v_Offset := p_StartRow - 1;
        v_FetchSize := p_EndRow - p_StartRow + 1;
    ELSE
        v_Offset := (p_PageNumber - 1) * p_PageSize;
        v_FetchSize := p_PageSize;
    END IF;
    
    -- TODO: Extract filter parameters from p_FilterJson
    -- Example:
    -- IF p_FilterJson IS NOT NULL AND p_FilterJson != '' THEN
    --     v_BusNumber := ((p_FilterJson::jsonb)->>'BusNumber')::INT;
    -- END IF;
    
    -- Get total count
    SELECT COUNT(*)
    INTO v_TotalCount
    FROM "%s" a;
    -- TODO: Add WHERE clause for filters
    -- WHERE (v_BusNumber IS NULL OR a.ibus = v_BusNumber)
    
    -- Get data rows
    SELECT jsonb_agg(row_to_json(t))
    INTO v_Data
    FROM (
        SELECT 
            %s,
%s
        FROM "%s" a
        -- TODO: Add JOIN clauses here
        -- LEFT JOIN "OtherTable" ot ON ot.id = a.other_id
        -- TODO: Add WHERE clause for filters
        ORDER BY a.%s
        LIMIT v_FetchSize OFFSET v_Offset
    ) t;
    
    -- Define base columns
    -- TODO: Customize column types, widths, and editability
    v_BaseColumns := '[
        {"field": "actions", "headerName": "Actions", "width": 120, "sortable": false, "filter": false, "pinned": true},
%s
    ]'::JSONB;
    
    v_Columns := v_BaseColumns;
    
    -- Return result
    RETURN jsonb_build_object(
        'rows', COALESCE(v_Data, '[]'::JSONB),
        'columns', COALESCE(v_Columns, '[]'::JSONB),
        'totalCount', v_TotalCount,
        'pageNumber', p_PageNumber,
        'pageSize', p_PageSize,
        'totalPages', CEIL(v_TotalCount::NUMERIC / p_PageSize)
    );
END;
$BODY$;

GRANT EXECUTE ON FUNCTION %s TO PUBLIC;

-- TODO: Customize this procedure by:
-- 1. Adding JOIN clauses for related tables
-- 2. Adding filter parameter declarations and extraction
-- 3. Adding WHERE clauses for filtering
-- 4. Adjusting column types (number, text, date, etc.)
-- 5. Setting correct widths and editability
-- 6. Adding dropdown configurations if needed
$PROC$,
        p_table_name,                    -- Comment
        v_proc_name,                     -- Function name
        p_table_name,                    -- Table name for COUNT
        v_id_construction,               -- ID construction
        v_select_fields,                 -- SELECT fields
        p_table_name,                    -- Table name for SELECT
        CASE WHEN v_needs_quotes THEN '"' || v_actual_col_name || '"' ELSE v_actual_col_name END,  -- ORDER BY with quotes if needed
        v_column_defs,                   -- Column definitions
        v_proc_name                      -- GRANT statement
    );
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION Generate_Grid_Fetch TO PUBLIC;

-- =============================================
-- Success Message
-- =============================================
DO $$
BEGIN
    RAISE NOTICE '✅ Enhanced Grid Fetch Procedure Generator created successfully!';
    RAISE NOTICE '';
    RAISE NOTICE '✨ NEW: Automatically detects correct column name casing!';
    RAISE NOTICE '';
    RAISE NOTICE 'Usage Example:';
    RAISE NOTICE '  SELECT Generate_Grid_Fetch(';
    RAISE NOTICE '      ''Adjust'',';
    RAISE NOTICE '      ''Bus_Adjusts'',';
    RAISE NOTICE '      ARRAY[''acctap'', ''casenumber''],  -- Case-insensitive!';
    RAISE NOTICE '      ARRAY[''acctap'', ''casenumber'', ''adjthr'', ''mxswim'']';
    RAISE NOTICE '  );';
    RAISE NOTICE '';
    RAISE NOTICE 'The generator will automatically use the correct case from your database!';
END $$;


-- =============================================
-- CRUD Procedure Generator with Full Type Casting
-- =============================================
-- Generates UPDATE and DELETE procedures with proper type handling
-- =============================================

CREATE OR REPLACE FUNCTION Generate_CRUD_Procedures(
    p_table_name TEXT,
    p_entity_name TEXT,
    p_primary_key_cols TEXT[],
    p_editable_cols TEXT[]
)
RETURNS TEXT AS $$
DECLARE
    v_update_proc_name TEXT;
    v_delete_proc_name TEXT;
    v_update_sql TEXT;
    v_delete_sql TEXT;
    v_pk_parse TEXT := '';
    v_pk_where TEXT := '';
    v_update_sets TEXT := '';
    v_declare_vars TEXT := '';
    v_extract_vars TEXT := '';
    v_col TEXT;
    v_pk_col TEXT;
    v_col_type TEXT;
    v_idx INT;
    v_id_format TEXT := '';
BEGIN
    v_update_proc_name := 'sp_Grid_Update_' || p_entity_name;
    v_delete_proc_name := 'sp_Grid_Delete_' || p_entity_name;
    v_id_format := array_to_string(p_primary_key_cols, '_');
    
    -- Build primary key parsing with type detection
    v_idx := 1;
    FOREACH v_pk_col IN ARRAY p_primary_key_cols LOOP
        SELECT data_type INTO v_col_type
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_pk_col)
        LIMIT 1;
        
        v_declare_vars := v_declare_vars || format('    v_%s TEXT;%s', v_pk_col, E'\n');
        v_pk_parse := v_pk_parse || format('    v_%s := v_Parts[%s];%s', v_pk_col, v_idx, E'\n');
        
        IF v_idx > 1 THEN
            v_pk_where := v_pk_where || E'\n      AND ';
        END IF;
        
        IF v_col_type IN ('integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision') THEN
            v_pk_where := v_pk_where || format('"%s" = v_%s::INTEGER', v_pk_col, v_pk_col);
        ELSE
            v_pk_where := v_pk_where || format('"%s" = v_%s', v_pk_col, v_pk_col);
        END IF;
        
        v_idx := v_idx + 1;
    END LOOP;
    
    -- Build UPDATE SET clause with type detection
    FOREACH v_col IN ARRAY p_editable_cols LOOP
        SELECT data_type INTO v_col_type
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        v_declare_vars := v_declare_vars || format('    v_%s TEXT;%s', v_col, E'\n');
        -- FIX: Use ->> instead of -> to extract as TEXT (removes quotes)
        v_extract_vars := v_extract_vars || format('        v_%s := (p_ChangesJson::jsonb)->>''%s'';%s', v_col, v_col, E'\n');
        
        IF v_update_sets != '' THEN
            v_update_sets := v_update_sets || ',' || E'\n        ';
        END IF;
        
        -- Cast based on column type
        IF v_col_type IN ('integer', 'bigint', 'smallint') THEN
            v_update_sets := v_update_sets || format('"%s" = CASE WHEN v_%s IS NULL OR v_%s = '''' THEN "%s" ELSE v_%s::INTEGER END', 
                v_col, v_col, v_col, v_col, v_col);
        ELSIF v_col_type IN ('numeric', 'decimal', 'real', 'double precision') THEN
            v_update_sets := v_update_sets || format('"%s" = CASE WHEN v_%s IS NULL OR v_%s = '''' THEN "%s" ELSE v_%s::NUMERIC END', 
                v_col, v_col, v_col, v_col, v_col);
        ELSIF v_col_type = 'boolean' THEN
            v_update_sets := v_update_sets || format('"%s" = CASE WHEN v_%s IS NULL OR v_%s = '''' THEN "%s" ELSE v_%s::BOOLEAN END', 
                v_col, v_col, v_col, v_col, v_col);
        ELSIF v_col_type = 'date' THEN
            v_update_sets := v_update_sets || format('"%s" = CASE WHEN v_%s IS NULL OR v_%s = '''' THEN "%s" ELSE v_%s::DATE END', 
                v_col, v_col, v_col, v_col, v_col);
        ELSIF v_col_type IN ('timestamp without time zone', 'timestamp with time zone') THEN
            v_update_sets := v_update_sets || format('"%s" = CASE WHEN v_%s IS NULL OR v_%s = '''' THEN "%s" ELSE v_%s::TIMESTAMP END', 
                v_col, v_col, v_col, v_col, v_col);
        ELSE
            -- Text types
            v_update_sets := v_update_sets || format('"%s" = COALESCE(NULLIF(v_%s, ''''), "%s")', 
                v_col, v_col, v_col);
        END IF;
    END LOOP;
    
    -- Generate UPDATE Procedure
    v_update_sql := format($PROC$
CREATE OR REPLACE FUNCTION %s(
    p_RowId TEXT,
    p_ChangesJson TEXT,
    p_UserId INT DEFAULT NULL
)
RETURNS JSONB AS $BODY$
DECLARE
    v_Parts TEXT[];
%s    v_UpdateCount INT := 0;
BEGIN
    IF p_RowId IS NULL OR p_RowId = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Row ID is required', 'errorCode', 'INVALID_INPUT');
    END IF;
    
    v_Parts := string_to_array(p_RowId, '_');
    
    IF array_length(v_Parts, 1) != %s THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid ID format. Expected: %s', 'errorCode', 'INVALID_KEY_FORMAT');
    END IF;
    
%s    
    IF p_ChangesJson IS NOT NULL AND p_ChangesJson != '' THEN
%s    END IF;
    
    UPDATE "%s"
    SET %s
    WHERE %s;
    
    GET DIAGNOSTICS v_UpdateCount = ROW_COUNT;
    
    IF v_UpdateCount = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Record not found', 'errorCode', 'NOT_FOUND');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Record updated successfully', 'rowsAffected', v_UpdateCount);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'Error updating record: ' || SQLERRM, 'errorCode', 'UPDATE_ERROR');
END;
$BODY$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION %s TO PUBLIC;
$PROC$,
        v_update_proc_name, v_declare_vars, array_length(p_primary_key_cols, 1), v_id_format,
        v_pk_parse, v_extract_vars, p_table_name, v_update_sets, v_pk_where, v_update_proc_name
    );
    
    -- Generate DELETE Procedure
    v_delete_sql := format($PROC$
CREATE OR REPLACE FUNCTION %s(
    p_RowId TEXT,
    p_UserId INT DEFAULT NULL
)
RETURNS JSONB AS $BODY$
DECLARE
    v_Parts TEXT[];
%s    v_DeleteCount INT := 0;
BEGIN
    IF p_RowId IS NULL OR p_RowId = '' THEN
        RETURN jsonb_build_object('success', false, 'message', 'Row ID is required', 'errorCode', 'INVALID_INPUT');
    END IF;
    
    v_Parts := string_to_array(p_RowId, '_');
    
    IF array_length(v_Parts, 1) != %s THEN
        RETURN jsonb_build_object('success', false, 'message', 'Invalid ID format. Expected: %s', 'errorCode', 'INVALID_KEY_FORMAT');
    END IF;
    
%s    
    DELETE FROM "%s"
    WHERE %s;
    
    GET DIAGNOSTICS v_DeleteCount = ROW_COUNT;
    
    IF v_DeleteCount = 0 THEN
        RETURN jsonb_build_object('success', false, 'message', 'Record not found', 'errorCode', 'NOT_FOUND');
    END IF;
    
    RETURN jsonb_build_object('success', true, 'message', 'Record deleted successfully', 'rowsAffected', v_DeleteCount);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object('success', false, 'message', 'Error deleting record: ' || SQLERRM, 'errorCode', 'DELETE_ERROR');
END;
$BODY$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION %s TO PUBLIC;
$PROC$,
        v_delete_proc_name, v_declare_vars, array_length(p_primary_key_cols, 1), v_id_format,
        v_pk_parse, p_table_name, v_pk_where, v_delete_proc_name
    );
    
    EXECUTE v_update_sql;
    EXECUTE v_delete_sql;
    
    RETURN format('✅ Successfully created procedures: %s and %s', v_update_proc_name, v_delete_proc_name);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('❌ Error generating procedures: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION Generate_CRUD_Procedures TO PUBLIC;

DO $$
BEGIN
    RAISE NOTICE '✅ CRUD Generator updated with full type casting support!';
END $$;
