-- =============================================
-- INSERT Procedure Generator
-- =============================================
-- Generates INSERT procedure with proper type handling
-- =============================================

CREATE OR REPLACE FUNCTION Generate_Insert_Procedure(
    p_table_name TEXT,
    p_entity_name TEXT,
    p_primary_key_cols TEXT[],
    p_insertable_cols TEXT[]  -- All columns that can be inserted (excluding auto-generated)
)
RETURNS TEXT AS $$
DECLARE
    v_insert_proc_name TEXT;
    v_insert_sql TEXT;
    v_insert_cols TEXT := '';
    v_insert_values TEXT := '';
    v_declare_vars TEXT := '';
    v_extract_vars TEXT := '';
    v_required_checks TEXT := '';
    v_col TEXT;
    v_col_type TEXT;
    v_is_nullable TEXT;
    v_has_default TEXT;
    v_select_cols TEXT := '';
    v_pk_where TEXT := '';
    v_pk_col TEXT;
    v_idx INT;
BEGIN
    v_insert_proc_name := 'sp_grid_insert_' || lower(regexp_replace(p_entity_name, 's$', ''));
    
    -- Build required field checks for NOT NULL columns without defaults
    FOREACH v_col IN ARRAY p_insertable_cols LOOP
        SELECT 
            data_type,
            is_nullable,
            CASE WHEN column_default IS NOT NULL THEN 'YES' ELSE 'NO' END
        INTO v_col_type, v_is_nullable, v_has_default
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        -- Add required check for NOT NULL columns without defaults
        -- Use lowercase for JSON field lookup
        IF v_is_nullable = 'NO' AND v_has_default = 'NO' THEN
            v_required_checks := v_required_checks || format($CHK$
    IF NOT (v_FieldValues ? '%s') THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', '%s is required',
            'errorCode', 'REQUIRED_FIELD_MISSING'
        );
    END IF;
$CHK$, lower(v_col), initcap(replace(v_col, '_', ' ')));
        END IF;
    END LOOP;
    
    -- Build INSERT columns and VALUES with type detection
    FOREACH v_col IN ARRAY p_insertable_cols LOOP
        SELECT data_type INTO v_col_type
        FROM information_schema.columns
        WHERE table_name = p_table_name
          AND table_schema = 'public'
          AND lower(column_name) = lower(v_col)
        LIMIT 1;
        
        IF v_insert_cols != '' THEN
            v_insert_cols := v_insert_cols || ',' || E'\n            ';
            v_insert_values := v_insert_values || ',' || E'\n            ';
        END IF;
        
        v_insert_cols := v_insert_cols || format('"%s"', v_col);
        
        -- Cast based on column type with NULL handling
        -- Use lowercase for JSON field lookup
        IF v_col_type IN ('integer', 'bigint', 'smallint') THEN
            v_insert_values := v_insert_values || format(
                'CASE WHEN v_FieldValues ? ''%s'' THEN (v_FieldValues->>''%s'')::INTEGER ELSE NULL END',
                lower(v_col), lower(v_col)
            );
        ELSIF v_col_type IN ('numeric', 'decimal', 'real', 'double precision') THEN
            v_insert_values := v_insert_values || format(
                'CASE WHEN v_FieldValues ? ''%s'' THEN (v_FieldValues->>''%s'')::NUMERIC ELSE NULL END',
                lower(v_col), lower(v_col)
            );
        ELSIF v_col_type = 'boolean' THEN
            v_insert_values := v_insert_values || format(
                'CASE WHEN v_FieldValues ? ''%s'' THEN (v_FieldValues->>''%s'')::BOOLEAN ELSE NULL END',
                lower(v_col), lower(v_col)
            );
        ELSIF v_col_type = 'date' THEN
            v_insert_values := v_insert_values || format(
                'CASE WHEN v_FieldValues ? ''%s'' THEN (v_FieldValues->>''%s'')::DATE ELSE NULL END',
                lower(v_col), lower(v_col)
            );
        ELSIF v_col_type IN ('timestamp without time zone', 'timestamp with time zone') THEN
            v_insert_values := v_insert_values || format(
                'CASE WHEN v_FieldValues ? ''%s'' THEN (v_FieldValues->>''%s'')::TIMESTAMP ELSE NULL END',
                lower(v_col), lower(v_col)
            );
        ELSE
            -- Text types - use lowercase for JSON field lookup
            v_insert_values := v_insert_values || format('v_FieldValues->>''%s''', lower(v_col));
        END IF;
    END LOOP;
    
    -- Build SELECT columns for result (all insertable columns)
    FOREACH v_col IN ARRAY p_insertable_cols LOOP
        IF v_select_cols != '' THEN
            v_select_cols := v_select_cols || ',' || E'\n            ';
        END IF;
        v_select_cols := v_select_cols || format('t."%s"', v_col);
    END LOOP;
    
    -- Build WHERE clause for retrieving inserted row
    v_idx := 1;
    FOREACH v_pk_col IN ARRAY p_primary_key_cols LOOP
        IF v_idx > 1 THEN
            v_pk_where := v_pk_where || E'\n          AND ';
        END IF;
        v_pk_where := v_pk_where || format('t."%s" = v_NewRecord."%s"', v_pk_col, v_pk_col);
        v_idx := v_idx + 1;
    END LOOP;
    
    -- Generate INSERT Procedure
    v_insert_sql := format($PROC$
CREATE OR REPLACE FUNCTION public.%s(
    p_fieldvaluesjson text,
    p_userid integer
)
RETURNS jsonb
LANGUAGE 'plpgsql'
AS $BODY$
DECLARE
    v_FieldValues JSONB;
    v_NewRecord RECORD;
    v_Result JSONB;
    v_ErrorMessage TEXT;
BEGIN
    -- Parse JSON input
    v_FieldValues := p_FieldValuesJson::JSONB;
    %s
    -- Insert record
    BEGIN
        INSERT INTO "%s" (
            %s
        )
        VALUES (
            %s
        )
        RETURNING * INTO v_NewRecord;
        
    EXCEPTION
        WHEN unique_violation THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'A record with this key already exists',
                'errorCode', 'DUPLICATE_VALUE'
            );
        WHEN not_null_violation THEN
            GET STACKED DIAGNOSTICS v_ErrorMessage = MESSAGE_TEXT;
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Required field is missing: ' || v_ErrorMessage,
                'errorCode', 'REQUIRED_FIELD_MISSING'
            );
        WHEN foreign_key_violation THEN
            GET STACKED DIAGNOSTICS v_ErrorMessage = MESSAGE_TEXT;
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Invalid reference to related data: ' || v_ErrorMessage,
                'errorCode', 'INVALID_REFERENCE'
            );
        WHEN OTHERS THEN
            GET STACKED DIAGNOSTICS v_ErrorMessage = MESSAGE_TEXT;
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Database error: ' || v_ErrorMessage,
                'errorCode', 'DB_ERROR'
            );
    END;
    
    -- Build result with created row
    SELECT jsonb_build_object(
        'success', true,
        'message', 'Record created successfully',
        'createdRow', row_to_json(t)
    )
    INTO v_Result
    FROM (
        SELECT 
            %s
        FROM "%s" t
        WHERE %s
    ) t;
    
    RETURN v_Result;
END;
$BODY$;

ALTER FUNCTION public.%s(text, integer)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.%s(text, integer) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.%s(text, integer) TO postgres;

COMMENT ON FUNCTION public.%s(text, integer)
    IS 'Insert a new %s record. Accepts field values as JSON and user ID. Returns success status and created row data.';
$PROC$,
        v_insert_proc_name,
        v_required_checks,
        p_table_name,
        v_insert_cols,
        v_insert_values,
        v_select_cols,
        p_table_name,
        v_pk_where,
        v_insert_proc_name,
        v_insert_proc_name,
        v_insert_proc_name,
        v_insert_proc_name,
        p_entity_name
    );
    
    EXECUTE v_insert_sql;
    
    RETURN format('✅ Successfully created procedure: %s', v_insert_proc_name);
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN format('❌ Error generating INSERT procedure: %s', SQLERRM);
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION Generate_Insert_Procedure TO PUBLIC;

DO $$
BEGIN
    RAISE NOTICE '✅ INSERT Generator created successfully!';
END $$;
