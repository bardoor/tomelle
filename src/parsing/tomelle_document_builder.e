note
    description: "Builds a TOML document from statements and validates definition conflicts."

class
    TOMELLE_DOCUMENT_BUILDER

create
    make

feature {NONE} -- Initialization

    make (a_errors: TOMELLE_ERROR_COLLECTOR)
        do
            errors := a_errors
            create definitions.make
        end

feature -- Building

    build (a_source: STRING_32; a_document: TOMELLE_DOCUMENT)
        local
            l_lines: ARRAYED_LIST [TOMELLE_LOGICAL_LINE]
            l_line: TOMELLE_LOGICAL_LINE
            l_statement: detachable TOMELLE_STATEMENT
            l_current_table: TOMELLE_TABLE
            l_section: STRING_32
        do
            definitions.reset
            l_lines := scanner.scan (a_source)
            create l_section.make_empty
            l_current_table := a_document.root
            from l_lines.start until l_lines.after or else errors.has_error loop
                l_line := l_lines.item
                l_statement := statement_parser.parse (l_line)
                if attached {TOMELLE_ARRAY_TABLE_HEADER} l_statement as h then
                    l_section := h.expression
                    if attached open_array_table (a_document.root, h) as l_opened then
                        l_current_table := l_opened
                    end
                elseif attached {TOMELLE_TABLE_HEADER} l_statement as h then
                    l_section := h.expression
                    if attached open_table (a_document.root, h) as l_opened then
                        l_current_table := l_opened
                    end
                elseif attached {TOMELLE_KEY_VALUE_STATEMENT} l_statement as s then
                    put_statement (l_current_table, l_section, s)
                elseif not lexical.trimmed (lexical.without_comment (l_line.text)).is_empty then
                    report_invalid_statement (l_line)
                end
                l_lines.forth
            end
        end

feature {NONE} -- Statements

    open_table (a_root: TOMELLE_TABLE; a_header: TOMELLE_TABLE_HEADER): detachable TOMELLE_TABLE
        local l_key: STRING_32
        do
            l_key := canonical_expression (a_header.expression)
            if definitions.is_explicit (l_key) or else definitions.is_dotted (l_key) or else
                definitions.is_array (l_key) or else definitions.is_sealed (l_key) or else
                has_sealed_prefix ((create {STRING_32}.make_empty), a_header.expression)
            then
                errors.add (error_codes.duplicate_key, "Duplicate table", Void, a_header.position.line, 1)
            elseif attached table_for_header (a_root, a_header.expression) as l_table then
                definitions.mark_explicit (l_key)
                Result := l_table
            else
                errors.add (error_codes.duplicate_key, "Table conflicts with an existing value", Void,
                    a_header.position.line, 1)
            end
        end

    open_array_table (a_root: TOMELLE_TABLE; a_header: TOMELLE_ARRAY_TABLE_HEADER): detachable TOMELLE_TABLE
        local
            l_array: TOMELLE_ARRAY
            l_table: TOMELLE_TABLE
            l_key: STRING_32
        do
            if attached array_for_header (a_root, a_header.expression) as l_header_array then
                l_array := l_header_array
                l_key := canonical_expression (a_header.expression)
                definitions.mark_array (l_key)
                definitions.reset_explicit_descendants (l_key)
                create l_table.make
                l_array.extend_table (l_table)
                Result := l_array.last.as_table
            else
                errors.add (error_codes.duplicate_key, "Array-of-tables conflicts with an existing value", Void,
                    a_header.position.line, 1)
            end
        end

    put_statement (a_current_table: TOMELLE_TABLE; a_section: STRING_32; a_statement: TOMELLE_KEY_VALUE_STATEMENT)
        local
            l_context: TOMELLE_DOCUMENT
            l_value: detachable TOMELLE_VALUE
        do
            l_value := value_parser.parse (a_statement.value_text)
            if attached l_value as v then
                create l_context.make
                l_context.set_root (a_current_table)
                put_value (l_context, a_section, a_statement.key_expression, v, a_statement.position.line)
            else
                errors.add (error_codes.invalid_syntax, "Invalid TOML value", Void,
                    a_statement.position.line, 1)
            end
        end

    report_invalid_statement (a_line: TOMELLE_LOGICAL_LINE)
        local l_content: STRING_32; l_equal: INTEGER
        do
            l_content := lexical.trimmed (lexical.without_comment (a_line.text))
            if l_content.count >= 2 and then l_content.substring (1, 2).same_string ("[[") then
                errors.add (error_codes.invalid_key, "Invalid array-of-tables key", Void, a_line.position.line, 1)
            elseif l_content [1] = '[' then
                if l_content [l_content.count] = ']' then
                    errors.add (error_codes.invalid_key, "Invalid table key", Void, a_line.position.line, 1)
                else
                    errors.add (error_codes.invalid_syntax, "Invalid table header", Void, a_line.position.line, 1)
                end
            else
                l_equal := lexical.top_level_equal (l_content)
                if l_equal > 1 then
                    errors.add (error_codes.invalid_key, "Invalid key", Void, a_line.position.line, 1)
                else
                    errors.add (error_codes.invalid_syntax, "Expected key/value pair", Void, a_line.position.line, 1)
                end
            end
        end

feature {NONE} -- Tree navigation

    table_for_header (a_root: TOMELLE_TABLE; a_expression: STRING_32): detachable TOMELLE_TABLE
        local
            i: INTEGER
            l_path: TOMELLE_PATH
            l_table, l_new_table: TOMELLE_TABLE
            l_value: detachable TOMELLE_VALUE
            l_valid: BOOLEAN
        do
            create l_path.make_from_key_expression (a_expression)
            l_table := a_root
            l_valid := True
            from i := 1 until i > l_path.count or else not l_valid loop
                l_value := l_table [l_path [i]]
                if attached l_value as v then
                    if v.is_table then l_table := v.as_table
                    elseif v.is_array and then definitions.is_array (canonical_prefix (a_expression, i)) and then
                        not v.as_array.is_empty and then v.as_array.last.is_table
                    then l_table := v.as_array.last.as_table
                    else l_valid := False end
                else
                    create l_new_table.make
                    l_table.put_table (l_new_table, l_path [i])
                    check attached l_table [l_path [i]] as l_stored then l_table := l_stored.as_table end
                end
                i := i + 1
            end
            if l_valid then Result := l_table end
        end

    array_for_header (a_root: TOMELLE_TABLE; a_expression: STRING_32): detachable TOMELLE_ARRAY
        local
            i: INTEGER
            l_path: TOMELLE_PATH
            l_table, l_new_table: TOMELLE_TABLE
            l_array: TOMELLE_ARRAY
            l_value: detachable TOMELLE_VALUE
            l_valid: BOOLEAN
        do
            create l_path.make_from_key_expression (a_expression)
            l_table := a_root
            l_valid := True
            from i := 1 until i >= l_path.count or else not l_valid loop
                l_value := l_table [l_path [i]]
                if attached l_value as v then
                    if v.is_table then l_table := v.as_table
                    elseif v.is_array and then definitions.is_array (canonical_prefix (a_expression, i)) and then
                        not v.as_array.is_empty and then v.as_array.last.is_table
                    then l_table := v.as_array.last.as_table
                    else l_valid := False end
                else
                    create l_new_table.make
                    l_table.put_table (l_new_table, l_path [i])
                    check attached l_table [l_path [i]] as l_stored then l_table := l_stored.as_table end
                end
                i := i + 1
            end
            if l_valid then
                l_value := l_table [l_path [l_path.count]]
                if attached l_value as v then
                    if v.is_array and then definitions.is_array (canonical_expression (a_expression)) then Result := v.as_array end
                else
                    create l_array.make
                    l_table.put_array (l_array, l_path [l_path.count])
                    check attached l_table [l_path [l_path.count]] as l_stored then Result := l_stored.as_array end
                end
            end
        end

feature {NONE} -- Definition validation

    put_value (a_document: TOMELLE_DOCUMENT; a_section, a_expression: STRING_32;
        a_value: TOMELLE_VALUE; a_line: INTEGER)
        local l_expression: STRING_32
        do
            l_expression := lexical.trimmed (a_expression)
            if has_sealed_prefix (a_section, l_expression) then
                errors.add (error_codes.duplicate_key, "Cannot extend an inline table", Void, a_line, 1)
            elseif has_explicit_descendant_prefix (a_section, l_expression) then
                errors.add (error_codes.duplicate_key, "Cannot extend an explicitly defined table", Void, a_line, 1)
            elseif a_document.has_at (l_expression) then
                errors.add (error_codes.duplicate_key, "Duplicate key", Void, a_line, 1)
            elseif a_document.can_put_at (l_expression) then
                a_document.put_at (a_value, l_expression)
                mark_dotted_tables (a_section, l_expression)
                if a_value.is_table then
                    definitions.mark_sealed (canonical_joined_prefix (a_section, l_expression,
                        joined_path_count (a_section, l_expression)))
                end
            else
                errors.add (error_codes.duplicate_key, "Key conflicts with an existing value", Void, a_line, 1)
            end
        end

    has_explicit_descendant_prefix (a_section, a_expression: STRING_32): BOOLEAN
        local i, l_section_count, l_count: INTEGER
        do
            if not a_section.is_empty then l_section_count := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count end
            l_count := joined_path_count (a_section, a_expression)
            from i := l_section_count + 1 until i >= l_count or else Result loop
                Result := definitions.is_explicit (canonical_joined_prefix (a_section, a_expression, i))
                i := i + 1
            end
        end

    mark_dotted_tables (a_section, a_expression: STRING_32)
        local i, l_section_count, l_count: INTEGER; l_key: STRING_32
        do
            if not a_section.is_empty then l_section_count := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count end
            l_count := joined_path_count (a_section, a_expression)
            from i := l_section_count + 1 until i >= l_count loop
                l_key := canonical_joined_prefix (a_section, a_expression, i)
                if not definitions.is_explicit (l_key) and not definitions.is_dotted (l_key) then definitions.mark_dotted (l_key) end
                i := i + 1
            end
        end

    has_sealed_prefix (a_section, a_expression: STRING_32): BOOLEAN
        local i, l_count: INTEGER
        do
            l_count := joined_path_count (a_section, a_expression)
            from i := 1 until i >= l_count or else Result loop
                Result := definitions.is_sealed (canonical_joined_prefix (a_section, a_expression, i))
                i := i + 1
            end
        end

    joined_path_count (a_section, a_expression: STRING_32): INTEGER
        do
            if not a_section.is_empty then Result := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count end
            Result := Result + (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count
        end

    canonical_expression (a_expression: STRING_32): STRING_32
        do
            Result := canonical_prefix (a_expression,
                (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count)
        end

    canonical_prefix (a_expression: STRING_32; a_count: INTEGER): STRING_32
        do
            Result := canonical_joined_prefix ((create {STRING_32}.make_empty), a_expression, a_count)
        end

    canonical_joined_prefix (a_section, a_expression: STRING_32; a_count: INTEGER): STRING_32
        local
            i, l_added: INTEGER
            l_section_path, l_expression_path: TOMELLE_PATH
            l_key: READABLE_STRING_32
        do
            create Result.make_empty
            if not a_section.is_empty then
                create l_section_path.make_from_key_expression (a_section)
                from i := 1 until i > l_section_path.count or else l_added = a_count loop
                    l_key := l_section_path [i]
                    Result.append (l_key.count.out); Result.extend (':'); Result.append (l_key); Result.extend (';')
                    l_added := l_added + 1; i := i + 1
                end
            end
            create l_expression_path.make_from_key_expression (a_expression)
            from i := 1 until i > l_expression_path.count or else l_added = a_count loop
                l_key := l_expression_path [i]
                Result.append (l_key.count.out); Result.extend (':'); Result.append (l_key); Result.extend (';')
                l_added := l_added + 1; i := i + 1
            end
        end

feature {NONE} -- Dependencies

    errors: TOMELLE_ERROR_COLLECTOR
    definitions: TOMELLE_DEFINITION_REGISTRY
    scanner: TOMELLE_LOGICAL_LINE_SCANNER once create Result end
    statement_parser: TOMELLE_STATEMENT_PARSER once create Result end
    value_parser: TOMELLE_VALUE_PARSER once create Result.make end
    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    error_codes: TOMELLE_ERROR_CODE once create Result.default_create end

end
