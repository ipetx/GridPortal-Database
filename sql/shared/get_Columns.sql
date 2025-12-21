SELECT
    c.column_name,
    c.data_type,
    c.is_nullable,
    tc.constraint_type
FROM information_schema.columns c
LEFT JOIN information_schema.key_column_usage kcu
       ON c.table_name = kcu.table_name
      AND c.column_name = kcu.column_name
LEFT JOIN information_schema.table_constraints tc
       ON kcu.constraint_name = tc.constraint_name
      AND tc.constraint_type = 'PRIMARY KEY'
WHERE c.table_schema = 'public'
  AND c.table_name = 'Acline'
ORDER BY c.ordinal_position;