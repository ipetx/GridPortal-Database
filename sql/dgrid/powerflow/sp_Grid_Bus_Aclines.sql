CREATE OR REPLACE FUNCTION public.sp_Grid_Bus_Aclines(
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
    v_DropdownConfigs JSONB;
    v_LinkConfigs JSONB;
    v_TotalCount INT;
    v_BusNumber INT;
    v_CaseNumber INT;
BEGIN
    -- Determine offset and fetch size
    IF p_StartRow IS NOT NULL AND p_EndRow IS NOT NULL THEN
        v_Offset := p_StartRow - 1;
        v_FetchSize := p_EndRow - p_StartRow + 1;
    ELSE
        v_Offset := (p_PageNumber - 1) * p_PageSize;
        v_FetchSize := p_PageSize;
    END IF;
    
    -- Extract filter parameters (BusNumber and CaseNumber)
    IF p_FilterJson IS NOT NULL AND p_FilterJson != '' THEN
        v_BusNumber := ((p_FilterJson::jsonb)->>'BusNumber')::INT;
        v_CaseNumber := ((p_FilterJson::jsonb)->>'CaseNumber')::INT;
    END IF;
    
    -- Get total count
    SELECT COUNT(*)
    INTO v_TotalCount
    FROM "Acline" a
    WHERE (v_BusNumber IS NULL OR (a.ibus = v_BusNumber OR a.jbus = v_BusNumber))
      AND (v_CaseNumber IS NULL OR a."CaseNumber" = v_CaseNumber);
    
    -- Get data rows
    SELECT jsonb_agg(row_to_json(t))
    INTO v_Data
    FROM (
        SELECT 
            (a.ckt || '_' || a.ibus::TEXT || '_' || a.jbus::TEXT || '_' || a."CaseNumber"::TEXT) AS "Id",
            a.ckt,
            a.ibus,
            a.jbus,
            a."CaseNumber",
            a.name,
            a.rpu,
            a.xpu,
            a.bpu,
            a.rate1,
            a.rate2,
            a.rate3,
            a.stat,
            a.len,
            a.o1,
            a.o2,
            a.o3,
            a.o4,
            bi.name AS "fromBusName",
            bj.name AS "toBusName"
        FROM "Acline" a
        LEFT JOIN "Bus" bi ON bi.ibus = a.ibus AND bi."CaseNumber" = a."CaseNumber"
        LEFT JOIN "Bus" bj ON bj.ibus = a.jbus AND bj."CaseNumber" = a."CaseNumber"
        WHERE (v_BusNumber IS NULL OR (a.ibus = v_BusNumber OR a.jbus = v_BusNumber))
          AND (v_CaseNumber IS NULL OR a."CaseNumber" = v_CaseNumber)
        ORDER BY a.ckt, a.ibus, a.jbus
        LIMIT v_FetchSize OFFSET v_Offset
    ) t;
    
    -- Define base columns
    v_BaseColumns := '[
        {"field": "actions", "headerName": "Actions", "width": 120, "sortable": false, "filter": false, "pinned": true},
        {"field": "ckt", "headerName": "Circuit", "type": "text", "width": 120, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},
        {"field": "ibus", "headerName": "From Bus", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": false},
        {"field": "fromBusName", "headerName": "From Bus Name", "type": "text", "width": 150, "sortable": true, "filter": true, "editable": false},
        {"field": "jbus", "headerName": "To Bus", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": false},
        {"field": "toBusName", "headerName": "To Bus Name", "type": "text", "width": 150, "sortable": true, "filter": true, "editable": false},
        {"field": "name", "headerName": "Name", "type": "text", "width": 200, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},
        {"field": "rpu", "headerName": "R (pu)", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "xpu", "headerName": "X (pu)", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "bpu", "headerName": "B (pu)", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "rate1", "headerName": "Rate 1", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "rate2", "headerName": "Rate 2", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "rate3", "headerName": "Rate 3", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "len", "headerName": "Length", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "stat", "headerName": "Status", "type": "number", "width": 80, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"}
    ]'::JSONB;
    
    -- Get dropdown configurations (if any)
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
    WHERE cm."ProcedureName" = 'sp_Grid_Bus_Aclines'
      AND cm."IsActive" = true
      AND cm."CellEditor" = 'dropdown';
    
    -- Get link configurations (if any)
    SELECT jsonb_object_agg(
        cm."ColumnName",
        cm."LinkConfig"
    )
    INTO v_LinkConfigs
    FROM "ColumnMetadata" cm
    WHERE cm."ProcedureName" = 'sp_Grid_Bus_Aclines'
      AND cm."IsActive" = true
      AND cm."LinkConfig" IS NOT NULL
      AND (cm."LinkConfig"->>'enabled')::boolean = true;
    
    -- Merge dropdown and link configs into base columns
    SELECT jsonb_agg(
        CASE 
            WHEN v_DropdownConfigs ? (col->>'field') AND v_LinkConfigs ? (col->>'field') THEN
                col || jsonb_build_object('dropdownConfig', v_DropdownConfigs->(col->>'field'))
                    || jsonb_build_object('linkConfig', v_LinkConfigs->(col->>'field'))
            WHEN v_DropdownConfigs ? (col->>'field') THEN
                col || jsonb_build_object('dropdownConfig', v_DropdownConfigs->(col->>'field'))
            WHEN v_LinkConfigs ? (col->>'field') THEN
                col || jsonb_build_object('linkConfig', v_LinkConfigs->(col->>'field'))
            ELSE
                col
        END
    )
    INTO v_Columns
    FROM jsonb_array_elements(v_BaseColumns) AS col;
    
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

GRANT EXECUTE ON FUNCTION sp_Grid_Bus_Aclines TO PUBLIC;
