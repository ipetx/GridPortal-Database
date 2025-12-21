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
