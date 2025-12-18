-- =============================================
-- Updated sp_grid_buses with Zone Name JOIN
-- Includes zoneName in results to display labels immediately
-- =============================================

CREATE OR REPLACE FUNCTION public.sp_grid_buses(
	p_pagenumber integer DEFAULT 1,
	p_pagesize integer DEFAULT 15,
	p_startrow integer DEFAULT NULL::integer,
	p_endrow integer DEFAULT NULL::integer,
	p_sortcolumn character varying DEFAULT NULL::character varying,
	p_sortdirection character varying DEFAULT 'ASC'::character varying,
	p_filterjson text DEFAULT NULL::text,
	p_searchterm character varying DEFAULT NULL::character varying)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
AS $BODY$
DECLARE
    v_Offset INT;
    v_FetchSize INT;
    v_Data JSONB;
    v_Columns JSONB;
    v_BaseColumns JSONB;
    v_DropdownConfigs JSONB;
    v_TotalCount INT;
    v_FilterWhere TEXT := '';
    v_FilterJson JSONB;
    v_FilterKeys TEXT[];
    v_FilterKey TEXT;
    v_FilterValue JSONB;
    v_FilterType TEXT;
    v_FilterText TEXT;
    v_FilterNumber NUMERIC;
    v_Condition TEXT;
BEGIN
    -- Determine offset and fetch size
    IF p_StartRow IS NOT NULL AND p_EndRow IS NOT NULL THEN
        v_Offset := p_StartRow - 1;
        v_FetchSize := p_EndRow - p_StartRow + 1;
    ELSE
        v_Offset := (p_PageNumber - 1) * p_PageSize;
        v_FetchSize := p_PageSize;
    END IF;
    
    -- Parse filter JSON if provided
    IF p_FilterJson IS NOT NULL AND p_FilterJson != '' THEN
        v_FilterJson := p_FilterJson::JSONB;
        v_FilterKeys := ARRAY(SELECT jsonb_object_keys(v_FilterJson));
        
        FOREACH v_FilterKey IN ARRAY v_FilterKeys
        LOOP
            v_FilterValue := v_FilterJson->v_FilterKey;
            
            IF v_FilterValue ? 'filterType' THEN
                DECLARE
                    v_ColumnType TEXT;
                BEGIN
                    v_FilterType := v_FilterValue->>'filterType';
                    
                    -- Determine column type
                    v_ColumnType := CASE v_FilterKey
                        WHEN 'ibus' THEN 'number'
                        WHEN 'CaseNumber' THEN 'number'
                        WHEN 'iarea' THEN 'number'
                        WHEN 'baskv' THEN 'number'
                        WHEN 'evhi' THEN 'number'
                        WHEN 'evlo' THEN 'number'
                        WHEN 'ide' THEN 'number'
                        WHEN 'nvhi' THEN 'number'
                        WHEN 'nvlo' THEN 'number'
                        WHEN 'iowner' THEN 'number'
                        WHEN 'va' THEN 'number'
                        WHEN 'vm' THEN 'number'
                        WHEN 'zone' THEN 'number'
                        WHEN 'Izone' THEN 'number'
                        WHEN 'AreaCaseNumber' THEN 'number'
                        WHEN 'OwnerCaseNumber' THEN 'number'
                        WHEN 'ZoneCaseNumber' THEN 'number'
                        ELSE 'text'
                    END;
                    
                    IF v_ColumnType = 'text' THEN
                        v_FilterText := v_FilterValue->>'filter';
                        CASE v_FilterType
                            WHEN 'contains' THEN
                                v_Condition := format('b.%I ILIKE %L', v_FilterKey, '%' || v_FilterText || '%');
                            WHEN 'notContains' THEN
                                v_Condition := format('b.%I NOT ILIKE %L', v_FilterKey, '%' || v_FilterText || '%');
                            WHEN 'equals' THEN
                                v_Condition := format('b.%I ILIKE %L', v_FilterKey, v_FilterText);
                            WHEN 'notEqual' THEN
                                v_Condition := format('b.%I NOT ILIKE %L', v_FilterKey, v_FilterText);
                            WHEN 'startsWith' THEN
                                v_Condition := format('b.%I ILIKE %L', v_FilterKey, v_FilterText || '%');
                            WHEN 'endsWith' THEN
                                v_Condition := format('b.%I ILIKE %L', v_FilterKey, '%' || v_FilterText);
                            ELSE
                                v_Condition := format('b.%I ILIKE %L', v_FilterKey, '%' || v_FilterText || '%');
                        END CASE;
                    ELSIF v_ColumnType = 'number' THEN
                        v_FilterNumber := (v_FilterValue->>'filter')::NUMERIC;
                        CASE v_FilterType
                            WHEN 'equals' THEN
                                v_Condition := format('b.%I = %s', v_FilterKey, v_FilterNumber);
                            WHEN 'notEqual' THEN
                                v_Condition := format('b.%I != %s', v_FilterKey, v_FilterNumber);
                            WHEN 'lessThan' THEN
                                v_Condition := format('b.%I < %s', v_FilterKey, v_FilterNumber);
                            WHEN 'lessThanOrEqual' THEN
                                v_Condition := format('b.%I <= %s', v_FilterKey, v_FilterNumber);
                            WHEN 'greaterThan' THEN
                                v_Condition := format('b.%I > %s', v_FilterKey, v_FilterNumber);
                            WHEN 'greaterThanOrEqual' THEN
                                v_Condition := format('b.%I >= %s', v_FilterKey, v_FilterNumber);
                            ELSE
                                v_Condition := format('b.%I = %s', v_FilterKey, v_FilterNumber);
                        END CASE;
                    END IF;
                    
                    IF v_FilterWhere != '' THEN
                        v_FilterWhere := v_FilterWhere || ' AND ';
                    END IF;
                    
                    v_FilterWhere := v_FilterWhere || v_Condition;
                END;
            END IF;
        END LOOP;
    END IF;
    
    -- Get total count with filters and search
    EXECUTE format('
        SELECT COUNT(*) 
        FROM "Bus" b
        WHERE (1=1)
            AND ($1 IS NULL OR 
                 b."name" ILIKE ''%%'' || $1 || ''%%'' OR
                 CAST(b."ibus" AS TEXT) ILIKE ''%%'' || $1 || ''%%'' OR
                 CAST(b."CaseNumber" AS TEXT) ILIKE ''%%'' || $1 || ''%%'' OR
                 CAST(b."baskv" AS TEXT) ILIKE ''%%'' || $1 || ''%%'')
            %s',
        CASE WHEN v_FilterWhere != '' THEN 'AND ' || v_FilterWhere ELSE '' END
    ) INTO v_TotalCount USING p_SearchTerm;
    
    -- Get data rows with filters and search (includes zoneName via JOIN)
    EXECUTE format('
        SELECT jsonb_agg(row_to_json(t))
        FROM (
            SELECT 
                (b.ibus::TEXT || ''_'' || b."CaseNumber"::TEXT) AS "Id",
                b.ibus,
                b."CaseNumber",
                b.iarea,
                b.baskv,
                b.evhi,
                b.evlo,
                b.ide,
                b.name,
                b.nvhi,
                b.nvlo,
                b.iowner,
                b.va,
                b.vm,
				z.zoname AS "zone",
                b."Izone",
                b."AreaCaseNumber",
                b."OwnerCaseNumber",
                b."ZoneCaseNumber"
            FROM "Bus" b
            LEFT JOIN "Zone" z ON z.izone = b.zone AND z."CaseNumber" = b."CaseNumber"
            WHERE (1=1)
                AND ($1 IS NULL OR 
                     b.name ILIKE ''%%%%'' || $1 || ''%%%%'' OR
                     CAST(b.ibus AS TEXT) ILIKE ''%%%%'' || $1 || ''%%%%'' OR
                     CAST(b."CaseNumber" AS TEXT) ILIKE ''%%%%'' || $1 || ''%%%%'' OR
                     CAST(b.baskv AS TEXT) ILIKE ''%%%%'' || $1 || ''%%%%'')
                %s
            ORDER BY 
                CASE WHEN $2 = ''ibus'' AND $3 = ''ASC'' THEN b.ibus END ASC,
                CASE WHEN $2 = ''ibus'' AND $3 = ''DESC'' THEN b.ibus END DESC,
                CASE WHEN $2 = ''CaseNumber'' AND $3 = ''ASC'' THEN b."CaseNumber" END ASC,
                CASE WHEN $2 = ''CaseNumber'' AND $3 = ''DESC'' THEN b."CaseNumber" END DESC,
                CASE WHEN $2 = ''name'' AND $3 = ''ASC'' THEN b.name END ASC,
                CASE WHEN $2 = ''name'' AND $3 = ''DESC'' THEN b.name END DESC,
                CASE WHEN $2 = ''baskv'' AND $3 = ''ASC'' THEN b.baskv END ASC,
                CASE WHEN $2 = ''baskv'' AND $3 = ''DESC'' THEN b.baskv END DESC,
                b.ibus ASC
            LIMIT $4 OFFSET $5
        ) t',
        CASE WHEN v_FilterWhere != '' THEN 'AND ' || v_FilterWhere ELSE '' END
    ) INTO v_Data USING p_SearchTerm, p_SortColumn, p_SortDirection, v_FetchSize, v_Offset;
    
    -- Define base column metadata (zoneName added as display column)
    v_BaseColumns := '[
        {"field": "actions", "headerName": "Actions", "width": 120, "sortable": false, "filter": false, "pinned": true},
        {"field": "ibus", "headerName": "Bus Number", "type": "number", "width": 120, "sortable": true, "filter": true, "editable": false},
        {"field": "CaseNumber", "headerName": "Case Number", "type": "number", "width": 130, "sortable": true, "filter": true, "editable": false},
        {"field": "name", "headerName": "Name", "type": "text", "width": 200, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},
        {"field": "baskv", "headerName": "Base KV", "type": "number", "width": 120, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "iarea", "headerName": "Area", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "dropdown"},
        {"field": "zone", "headerName": "Zone", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "dropdown"},
        {"field": "iowner", "headerName": "Owner", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "ide", "headerName": "IDE", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "vm", "headerName": "VM", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "va", "headerName": "VA", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "nvhi", "headerName": "NV High", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "nvlo", "headerName": "NV Low", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "evhi", "headerName": "EV High", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "evlo", "headerName": "EV Low", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "Izone", "headerName": "I Zone", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "AreaCaseNumber", "headerName": "Area Case #", "type": "number", "width": 130, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "OwnerCaseNumber", "headerName": "Owner Case #", "type": "number", "width": 140, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "ZoneCaseNumber", "headerName": "Zone Case #", "type": "number", "width": 130, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"}
    ]'::JSONB;
    
    -- Get dropdown configurations from ColumnMetadata
    SELECT jsonb_object_agg(
        cm."ColumnName",
        jsonb_build_object(
            'type', cm."DropdownType",
            'staticValues', CASE 
                WHEN cm."StaticValuesJson" IS NOT NULL 
                THEN cm."StaticValuesJson"::jsonb 
                ELSE NULL 
            END,
            'masterTable', cm."MasterTable",
            'valueField', cm."ValueField",
            'labelField', cm."LabelField",
            'filterCondition', cm."FilterCondition",
            'dependsOn', CASE 
                WHEN cm."DependsOnJson" IS NOT NULL 
                THEN cm."DependsOnJson"::jsonb 
                ELSE NULL 
            END
        )
    )
    INTO v_DropdownConfigs
    FROM "ColumnMetadata" cm
    WHERE cm."ProcedureName" = 'sp_Grid_Buses'
      AND cm."IsActive" = true
      AND cm."CellEditor" = 'dropdown';
    
    -- Merge dropdown configs into base columns
    SELECT jsonb_agg(
        CASE 
            WHEN v_DropdownConfigs ? (col->>'field') THEN
                col || jsonb_build_object('dropdownConfig', v_DropdownConfigs->(col->>'field'))
            ELSE
                col
        END
    )
    INTO v_Columns
    FROM jsonb_array_elements(v_BaseColumns) AS col;
    
    -- Return combined result
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

ALTER FUNCTION public.sp_grid_buses(integer, integer, integer, integer, character varying, character varying, text, character varying)
    OWNER TO postgres;

GRANT EXECUTE ON FUNCTION public.sp_grid_buses(integer, integer, integer, integer, character varying, character varying, text, character varying) TO PUBLIC;

GRANT EXECUTE ON FUNCTION public.sp_grid_buses(integer, integer, integer, integer, character varying, character varying, text, character varying) TO postgres;


-- =============================================
-- PostgreSQL Function: sp_Grid_Delete_Bus
-- Description: Delete a bus record from the Bus table
-- Parameters: p_BusId - Composite key in format "ibus_CaseNumber"
-- Returns: JSONB with success status and message
-- =============================================

CREATE OR REPLACE FUNCTION sp_Grid_Delete_Bus(
    p_BusId TEXT
)
RETURNS JSONB AS $$
DECLARE
    v_Ibus INT;
    v_CaseNumber INT;
    v_Parts TEXT[];
    v_RowCount INT;
BEGIN
    -- Validate input
    IF p_BusId IS NULL OR p_BusId = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bus ID is required',
            'errorCode', 'INVALID_INPUT'
        );
    END IF;
    
    -- Parse composite key (format: "ibus_CaseNumber")
    v_Parts := string_to_array(p_BusId, '_');
    
    IF array_length(v_Parts, 1) != 2 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid Bus ID format. Expected format: ibus_CaseNumber',
            'errorCode', 'INVALID_FORMAT'
        );
    END IF;
    
    -- Extract ibus and CaseNumber
    BEGIN
        v_Ibus := v_Parts[1]::INT;
        v_CaseNumber := v_Parts[2]::INT;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid Bus ID values. Both ibus and CaseNumber must be integers',
            'errorCode', 'INVALID_TYPE'
        );
    END;
    
    -- Check if bus exists
    SELECT COUNT(*) INTO v_RowCount
    FROM "Bus"
    WHERE ibus = v_Ibus AND "CaseNumber" = v_CaseNumber;
    
    IF v_RowCount = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bus not found',
            'errorCode', 'NOT_FOUND'
        );
    END IF;
    
    -- Delete the bus
    BEGIN
        DELETE FROM "Bus"
        WHERE ibus = v_Ibus AND "CaseNumber" = v_CaseNumber;
        
        GET DIAGNOSTICS v_RowCount = ROW_COUNT;
        
        IF v_RowCount > 0 THEN
            RETURN jsonb_build_object(
                'success', true,
                'message', 'Bus deleted successfully'
            );
        ELSE
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Failed to delete bus',
                'errorCode', 'DELETE_FAILED'
            );
        END IF;
        
    EXCEPTION
        WHEN foreign_key_violation THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Cannot delete bus: referenced by other records',
                'errorCode', 'FOREIGN_KEY_VIOLATION'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Database error: ' || SQLERRM,
                'errorCode', 'DATABASE_ERROR'
            );
    END;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sp_Grid_Delete_Bus(TEXT) TO PUBLIC;



-- =============================================
-- PostgreSQL Function: sp_Grid_Update_Bus
-- Description: Row-level update function for bus data
-- Parameters: p_BusId (composite key format: "ibus_CaseNumber"), p_ChangesJson, p_UserId
-- Returns: JSONB with success status and message
-- =============================================

CREATE OR REPLACE FUNCTION sp_Grid_Update_Bus(
    p_BusId TEXT,
    p_ChangesJson TEXT,
    p_UserId INT
)
RETURNS JSONB AS $$
DECLARE
    v_Ibus INT;
    v_CaseNumber INT;
    v_Parts TEXT[];
    v_Name TEXT;
    v_BaseKV DECIMAL;
    v_Area INT;
    v_Zone INT;
    v_Owner INT;
    v_IDE INT;
    v_VM DECIMAL;
    v_VA DECIMAL;
    v_NVHi DECIMAL;
    v_NVLo DECIMAL;
    v_EVHi DECIMAL;
    v_EVLo DECIMAL;
    v_Izone INT;
    v_AreaCaseNumber INT;
    v_OwnerCaseNumber INT;
    v_ZoneCaseNumber INT;
    v_UpdateCount INT := 0;
BEGIN
    -- Validate input
    IF p_BusId IS NULL OR p_BusId = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bus ID is required',
            'errorCode', 'INVALID_INPUT'
        );
    END IF;
    
    -- Parse composite key (format: "ibus_CaseNumber")
    v_Parts := string_to_array(p_BusId, '_');
    
    IF array_length(v_Parts, 1) != 2 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid Bus ID format. Expected format: ibus_CaseNumber',
            'errorCode', 'INVALID_FORMAT'
        );
    END IF;
    
    -- Extract ibus and CaseNumber
    BEGIN
        v_Ibus := v_Parts[1]::INT;
        v_CaseNumber := v_Parts[2]::INT;
    EXCEPTION WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Invalid Bus ID values. Both ibus and CaseNumber must be integers',
            'errorCode', 'INVALID_TYPE'
        );
    END;
    
    -- Parse JSON changes
    v_Name := (p_ChangesJson::jsonb)->>'name';
    v_BaseKV := ((p_ChangesJson::jsonb)->>'baskv')::DECIMAL;
    v_Area := ((p_ChangesJson::jsonb)->>'iarea')::INT;
    v_Zone := ((p_ChangesJson::jsonb)->>'zone')::INT;
    v_Owner := ((p_ChangesJson::jsonb)->>'iowner')::INT;
    v_IDE := ((p_ChangesJson::jsonb)->>'ide')::INT;
    v_VM := ((p_ChangesJson::jsonb)->>'vm')::DECIMAL;
    v_VA := ((p_ChangesJson::jsonb)->>'va')::DECIMAL;
    v_NVHi := ((p_ChangesJson::jsonb)->>'nvhi')::DECIMAL;
    v_NVLo := ((p_ChangesJson::jsonb)->>'nvlo')::DECIMAL;
    v_EVHi := ((p_ChangesJson::jsonb)->>'evhi')::DECIMAL;
    v_EVLo := ((p_ChangesJson::jsonb)->>'evlo')::DECIMAL;
    v_Izone := ((p_ChangesJson::jsonb)->>'Izone')::INT;
    v_AreaCaseNumber := ((p_ChangesJson::jsonb)->>'AreaCaseNumber')::INT;
    v_OwnerCaseNumber := ((p_ChangesJson::jsonb)->>'OwnerCaseNumber')::INT;
    v_ZoneCaseNumber := ((p_ChangesJson::jsonb)->>'ZoneCaseNumber')::INT;
    
    -- Validate BaseKV if provided
    IF v_BaseKV IS NOT NULL AND (v_BaseKV < 0 OR v_BaseKV > 1000) THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Base KV must be between 0 and 1000'
        );
    END IF;
    
    -- Validate voltage limits if provided
    IF v_NVHi IS NOT NULL AND v_NVLo IS NOT NULL AND v_NVHi < v_NVLo THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Normal voltage high must be greater than normal voltage low'
        );
    END IF;
    
    IF v_EVHi IS NOT NULL AND v_EVLo IS NOT NULL AND v_EVHi < v_EVLo THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Emergency voltage high must be greater than emergency voltage low'
        );
    END IF;
    
    -- Perform update
    UPDATE "Bus"
    SET 
        name = COALESCE(v_Name, name),
        baskv = COALESCE(v_BaseKV, baskv),
        iarea = COALESCE(v_Area, iarea),
        zone = COALESCE(v_Zone, zone),
        iowner = COALESCE(v_Owner, iowner),
        ide = COALESCE(v_IDE, ide),
        vm = COALESCE(v_VM, vm),
        va = COALESCE(v_VA, va),
        nvhi = COALESCE(v_NVHi, nvhi),
        nvlo = COALESCE(v_NVLo, nvlo),
        evhi = COALESCE(v_EVHi, evhi),
        evlo = COALESCE(v_EVLo, evlo),
        "Izone" = COALESCE(v_Izone, "Izone"),
        "AreaCaseNumber" = COALESCE(v_AreaCaseNumber, "AreaCaseNumber"),
        "OwnerCaseNumber" = COALESCE(v_OwnerCaseNumber, "OwnerCaseNumber"),
        "ZoneCaseNumber" = COALESCE(v_ZoneCaseNumber, "ZoneCaseNumber")
    WHERE ibus = v_Ibus AND "CaseNumber" = v_CaseNumber;
    
    GET DIAGNOSTICS v_UpdateCount = ROW_COUNT;
    
    IF v_UpdateCount = 0 THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Bus not found with ID: ' || p_BusId
        );
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Bus updated successfully'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Error: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION sp_Grid_Update_Bus(TEXT, TEXT, INT) TO PUBLIC;
