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
