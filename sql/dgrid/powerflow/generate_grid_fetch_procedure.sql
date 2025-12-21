-- FUNCTION: public.generate_grid_fetch_procedure(text, text, text[], text[])

-- DROP FUNCTION IF EXISTS public.generate_grid_fetch_procedure(text, text, text[], text[]);

CREATE OR REPLACE FUNCTION public.generate_grid_fetch_procedure(
	p_table_name text,
	p_entity_name text,
	p_primary_key_cols text[],
	p_display_cols text[])
    RETURNS text
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_proc_name TEXT;
    v_id_construction TEXT := '';
    v_select_fields TEXT := '';
    v_column_defs TEXT := '';
    v_col TEXT;
    v_idx INT := 1;
BEGIN
    v_proc_name := 'sp_Grid_' || p_entity_name;
    
    -- Build ID construction (concatenate all PK columns)
    v_id_construction := '(';
    FOREACH v_col IN ARRAY p_primary_key_cols LOOP
        IF v_idx > 1 THEN
            v_id_construction := v_id_construction || ' || ''_'' || ';
        END IF;
        v_id_construction := v_id_construction || 'a.' || v_col || '::TEXT';
        v_idx := v_idx + 1;
    END LOOP;
    v_id_construction := v_id_construction || ') AS "Id"';
    
    -- Build SELECT fields
    FOREACH v_col IN ARRAY p_display_cols LOOP
        v_select_fields := v_select_fields || format('            a.%s,%s', v_col, E'\n');
    END LOOP;
    v_select_fields := rtrim(v_select_fields, ',' || E'\n');
    
    -- Build column definitions (basic - user can customize)
    FOREACH v_col IN ARRAY p_display_cols LOOP
        v_column_defs := v_column_defs || format('        {"field": "%s", "headerName": "%s", "type": "text", "width": 120, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},%s',
            v_col,
            initcap(replace(v_col, '_', ' ')),  -- Convert snake_case to Title Case
            E'\n'
        );
    END LOOP;
    v_column_defs := rtrim(v_column_defs, ',' || E'\n');
    
    -- Generate the procedure SQL
    RETURN format($PROC$

-- Auto-generated FETCH procedure for %s
-- CUSTOMIZE: Add JOINs, filters, and adjust column definitions as needed
CREATE OR REPLACE FUNCTION public.%s(
    p_PageNumber INTEGER DEFAULT 1,
    p_PageSize INTEGER DEFAULT 15,
    p_StartRow INTEGER DEFAULT NULL,
    p_EndRow INTEGER DEFAULT NULL,
    p_SortColumn VARCHAR DEFAULT NULL,
    p_SortDirection VARCHAR DEFAULT 'ASC',
    p_FilterJson TEXT DEFAULT NULL,
    p_SearchTerm VARCHAR DEFAULT NULL)
	RETURNS JSONB
	LANGUAGE 'plpgsql'

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
        p_primary_key_cols[1],           -- ORDER BY (first PK)
        v_column_defs,                   -- Column definitions
        v_proc_name                      -- GRANT statement
    );
END;
$BODY$;

ALTER FUNCTION public.generate_grid_fetch_procedure(text, text, text[], text[])
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.generate_grid_fetch_procedure(text, text, text[], text[]) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.generate_grid_fetch_procedure(text, text, text[], text[]) TO postgres;

