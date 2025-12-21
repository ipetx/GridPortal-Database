CREATE OR REPLACE FUNCTION public.sp_Grid_Bus_Transformers(
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
    
    -- Extract filter parameters
    IF p_FilterJson IS NOT NULL AND p_FilterJson != '' THEN
        v_BusNumber := ((p_FilterJson::jsonb)->>'BusNumber')::INT;
        v_CaseNumber := ((p_FilterJson::jsonb)->>'CaseNumber')::INT;
    END IF;
    
    -- Get total count
    SELECT COUNT(*)
    INTO v_TotalCount
    FROM "Transformer" t
    WHERE (v_BusNumber IS NULL OR (t.ibus = v_BusNumber OR t.jbus = v_BusNumber OR t.kbus = v_BusNumber))
      AND (v_CaseNumber IS NULL OR t."CaseNumber" = v_CaseNumber)
      AND (p_SearchTerm IS NULL OR 
           t.name ILIKE '%' || p_SearchTerm || '%' OR
           t.ckt ILIKE '%' || p_SearchTerm || '%' OR
           CAST(t.ibus AS TEXT) ILIKE '%' || p_SearchTerm || '%' OR
           CAST(t.jbus AS TEXT) ILIKE '%' || p_SearchTerm || '%' OR
           CAST(t.kbus AS TEXT) ILIKE '%' || p_SearchTerm || '%');
    
    -- Get data rows
    SELECT jsonb_agg(row_to_json(t))
    INTO v_Data
    FROM (
        SELECT 
            (t.ckt || '_' || t.ibus::TEXT || '_' || t.jbus::TEXT || '_' || t.kbus::TEXT || '_' || t."CaseNumber"::TEXT) AS "Id",
            t.ckt,
            t.ibus,
            t.jbus,
            t.kbus,
            t."CaseNumber",
            t.name,
            t.r1_2,
            t.x1_2,
            t.sbase1_2,
            t.windv1,
            t.windv2,
            t.ang1,
            t.stat,
            t.nomv1,
            t.nomv2,
            t.mag1,
            t.mag2,
            t.o1,
            t.o2,
            t.o3,
            t.o4,
            bi.name AS "fromBusName",
            bj.name AS "toBusName",
            bk.name AS "auxBusName"
        FROM "Transformer" t
        LEFT JOIN "Bus" bi ON bi.ibus = t.ibus AND bi."CaseNumber" = t."CaseNumber"
        LEFT JOIN "Bus" bj ON bj.ibus = t.jbus AND bj."CaseNumber" = t."CaseNumber"
        LEFT JOIN "Bus" bk ON bk.ibus = t.kbus AND bk."CaseNumber" = t."CaseNumber"
        WHERE (v_BusNumber IS NULL OR (t.ibus = v_BusNumber OR t.jbus = v_BusNumber OR t.kbus = v_BusNumber))
          AND (v_CaseNumber IS NULL OR t."CaseNumber" = v_CaseNumber)
          AND (p_SearchTerm IS NULL OR 
               t.name ILIKE '%' || p_SearchTerm || '%' OR
               t.ckt ILIKE '%' || p_SearchTerm || '%' OR
               CAST(t.ibus AS TEXT) ILIKE '%' || p_SearchTerm || '%' OR
               CAST(t.jbus AS TEXT) ILIKE '%' || p_SearchTerm || '%' OR
               CAST(t.kbus AS TEXT) ILIKE '%' || p_SearchTerm || '%' OR
               bi.name ILIKE '%' || p_SearchTerm || '%' OR
               bj.name ILIKE '%' || p_SearchTerm || '%' OR
               bk.name ILIKE '%' || p_SearchTerm || '%')
        ORDER BY t.ckt, t.ibus, t.jbus, t.kbus
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
        {"field": "kbus", "headerName": "Aux Bus", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": false},
        {"field": "auxBusName", "headerName": "Aux Bus Name", "type": "text", "width": 150, "sortable": true, "filter": true, "editable": false},
        {"field": "name", "headerName": "Name", "type": "text", "width": 200, "sortable": true, "filter": true, "editable": true, "cellEditor": "agTextCellEditor"},
        {"field": "r1_2", "headerName": "R 1-2 (pu)", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "x1_2", "headerName": "X 1-2 (pu)", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "sbase1_2", "headerName": "S Base 1-2", "type": "number", "width": 120, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "windv1", "headerName": "Winding V1", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "windv2", "headerName": "Winding V2", "type": "number", "width": 110, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "ang1", "headerName": "Angle 1", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "nomv1", "headerName": "Nom V1", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
        {"field": "nomv2", "headerName": "Nom V2", "type": "number", "width": 100, "sortable": true, "filter": true, "editable": true, "cellEditor": "agNumberCellEditor"},
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
    WHERE cm."ProcedureName" = 'sp_Grid_Bus_Transformers'
      AND cm."IsActive" = true
      AND cm."CellEditor" = 'dropdown';
    
    -- Get link configurations (if any)
    SELECT jsonb_object_agg(
        cm."ColumnName",
        cm."LinkConfig"
    )
    INTO v_LinkConfigs
    FROM "ColumnMetadata" cm
    WHERE cm."ProcedureName" = 'sp_Grid_Bus_Transformers'
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

GRANT EXECUTE ON FUNCTION sp_Grid_Bus_Transformers TO PUBLIC;
