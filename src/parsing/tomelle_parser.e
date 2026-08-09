note
    description: "Reusable stateful TOML parser."

class
    TOMELLE_PARSER

create
    make

feature {NONE} -- Initialization

    make
        do
            create internal_errors.make (0)
            create explicit_tables.make (0)
            explicit_tables.compare_objects
            create dotted_tables.make (0)
            dotted_tables.compare_objects
            create sealed_tables.make (0)
            sealed_tables.compare_objects
            create array_tables.make (0)
            array_tables.compare_objects
            create value_factory.make
        ensure
            not_parsed: not is_parsed
            no_document: document = Void
            no_errors: error_count = 0
        end

feature -- Parsing

    parse_string (a_source: READABLE_STRING_GENERAL)
        do
            if attached {STRING_32} a_source as l_source then
                parse_text (l_source, Void)
            else
                parse_text (a_source.as_string_32, Void)
            end
        ensure
            parsed: is_parsed
            result_consistent: is_successful = attached document
        end

    parse_file (a_path: PATH)
        require
            path_not_empty: not a_path.is_empty
        local
            l_file: RAW_FILE
            l_bytes: STRING_8
            l_text: detachable STRING_32
        do
            reset
            create l_file.make_with_path (a_path)
            if l_file.exists and then l_file.is_readable then
                l_file.open_read
                l_file.read_stream (l_file.count)
                l_bytes := l_file.last_string
                l_file.close
                l_text := decoded_utf_8 (l_bytes)
                if attached l_text as t then
                    parse_text (t, a_path.name)
                else
                    is_parsed := True
                    add_error ((create {TOMELLE_ERROR_CODE}.default_create).invalid_utf_8,
                        "Input is not valid UTF-8", a_path.name, 1, 1)
                end
            else
                is_parsed := True
                add_error ((create {TOMELLE_ERROR_CODE}.default_create).input_unreadable,
                    "Input file is missing or unreadable", a_path.name, 1, 1)
            end
        rescue
            if attached l_file and then l_file.is_open_read then
                l_file.close
            end
            reset
            is_parsed := True
            add_error ((create {TOMELLE_ERROR_CODE}.default_create).input_unreadable,
                "Unable to read input file", a_path.name, 1, 1)
        end

    reset
        do
            document := Void
            internal_errors.wipe_out
            explicit_tables.wipe_out
            dotted_tables.wipe_out
            sealed_tables.wipe_out
            array_tables.wipe_out
            current_source_name := Void
            is_parsed := False
        end

feature -- Status report

    is_parsed: BOOLEAN
    is_successful: BOOLEAN
        do
            Result := is_parsed and then not has_error
        end

    has_error: BOOLEAN
        do
            Result := not internal_errors.is_empty
        end

feature -- Result

    document: detachable TOMELLE_DOCUMENT
    error_count: INTEGER
        do
            Result := internal_errors.count
        end
    error (a_index: INTEGER): TOMELLE_PARSE_ERROR
        require valid_index: 1 <= a_index and a_index <= error_count
        do
            Result := internal_errors [a_index]
        end

    errors: ITERABLE [TOMELLE_PARSE_ERROR]
        do
            Result := internal_errors
        end

feature {NONE} -- Line parsing

    parse_text (a_source: STRING_32; a_source_name: detachable READABLE_STRING_GENERAL)
        local l_candidate: TOMELLE_DOCUMENT
        do
            reset
            is_parsed := True
            if attached a_source_name as l_name then
                current_source_name := l_name.as_string_32.twin
            end
            create l_candidate.make
            if has_valid_control_characters (a_source) and then headers_close_on_same_line (a_source)
            then
                parse_lines (a_source, l_candidate)
            else
                add_error (error_codes.invalid_syntax, "Invalid control character", Void, 1, 1)
            end
            if internal_errors.is_empty then
                document := l_candidate
            end
        end

    parse_lines (a_source: STRING_32; a_document: TOMELLE_DOCUMENT)
        local
            l_lines: LIST [STRING_32]
            l_line, l_content, l_section: STRING_32
            l_equal, l_line_number: INTEGER
            l_value: detachable TOMELLE_VALUE
            l_current_table, l_new_table: TOMELLE_TABLE
            l_array: TOMELLE_ARRAY
            l_context_document: TOMELLE_DOCUMENT
        do
            l_lines := logical_lines (a_source)
            create l_section.make_empty
            l_current_table := a_document.root
            from l_lines.start until l_lines.after or else has_error loop
                l_line_number := l_line_number + 1
                l_line := l_lines.item
                l_content := safely_trimmed (without_comment (l_line))
                if not l_content.is_empty then
                    if l_content.count >= 4 and then l_content.substring (1, 2).same_string ("[[") and then
                        l_content.substring (l_content.count - 1, l_content.count).same_string ("]]" )
                    then
                        l_section := safely_trimmed (safe_substring (l_content, 3, l_content.count - 2))
                        if key_syntax.is_valid_expression (l_section) then
                            if attached array_for_header (a_document.root, l_section) as l_header_array then
                                l_array := l_header_array
                                if not array_tables.has (canonical_expression (l_section)) then
                                    array_tables.extend (canonical_expression (l_section))
                                end
                                reset_array_instance_metadata (canonical_expression (l_section))
                                create l_new_table.make
                                l_array.extend_table (l_new_table)
                                l_current_table := l_array.last.as_table
                            else
                                add_error (error_codes.duplicate_key, "Array-of-tables conflicts with an existing value", Void, l_line_number, 1)
                            end
                        else
                            add_error (error_codes.invalid_key, "Invalid array-of-tables key", Void, l_line_number, 1)
                        end
                    elseif l_content [1] = '[' then
                        if l_content.count >= 2 and then l_content [l_content.count] = ']' then
                            l_section := safely_trimmed (safe_substring (l_content, 2, l_content.count - 1))
                            if key_syntax.is_valid_expression (l_section) then
                                if explicit_tables.has (canonical_expression (l_section)) or else
                                    dotted_tables.has (canonical_expression (l_section)) or else
                                    array_tables.has (canonical_expression (l_section)) or else
                                    sealed_tables.has (canonical_expression (l_section)) or else
                                    has_sealed_prefix ((create {STRING_32}.make_empty), l_section)
                                then
                                    add_error (error_codes.duplicate_key, "Duplicate table", Void, l_line_number, 1)
                                end
                                if not has_error then
                                    if attached table_for_header (a_document.root, l_section) as l_header_table then
                                        explicit_tables.extend (canonical_expression (l_section))
                                        l_current_table := l_header_table
                                    else
                                        add_error (error_codes.duplicate_key, "Table conflicts with an existing value", Void, l_line_number, 1)
                                    end
                                end
                            else
                                add_error (error_codes.invalid_key, "Invalid table key", Void, l_line_number, 1)
                            end
                        else
                            add_error (error_codes.invalid_syntax, "Invalid table header", Void, l_line_number, 1)
                        end
                    else
                        l_equal := top_level_equal (l_content)
                        if l_equal > 1 then
                            l_value := parsed_value (safe_substring (l_content, l_equal + 1, l_content.count))
                            if attached l_value as v then
                                create l_context_document.make
                                l_context_document.set_root (l_current_table)
                                put_parsed_value (l_context_document, l_section,
                                    l_content.substring (1, l_equal - 1), v, l_line_number)
                            else
                                add_error (error_codes.invalid_syntax, "Invalid TOML value", Void, l_line_number, l_equal + 1)
                            end
                        else
                            add_error (error_codes.invalid_syntax, "Expected key/value pair", Void, l_line_number, 1)
                        end
                    end
                end
                l_lines.forth
            end
        end

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
                    if v.is_table then
                        l_table := v.as_table
                    elseif v.is_array and then array_tables.has (canonical_joined_prefix (
                        (create {STRING_32}.make_empty), a_expression, i)) and then
                        not v.as_array.is_empty and then v.as_array.last.is_table
                    then
                        l_table := v.as_array.last.as_table
                    else
                        l_valid := False
                    end
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
                    elseif v.is_array and then array_tables.has (canonical_joined_prefix (
                        (create {STRING_32}.make_empty), a_expression, i)) and then
                        not v.as_array.is_empty and then v.as_array.last.is_table
                    then
                        l_table := v.as_array.last.as_table
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
                    if v.is_array and then array_tables.has (canonical_expression (a_expression)) then
                        Result := v.as_array
                    end
                else
                    create l_array.make
                    l_table.put_array (l_array, l_path [l_path.count])
                    check attached l_table [l_path [l_path.count]] as l_stored then Result := l_stored.as_array end
                end
            end
        end

    put_parsed_value (a_document: TOMELLE_DOCUMENT; a_section, a_expression: STRING_32;
        a_value: TOMELLE_VALUE; a_line: INTEGER)
        local l_expression: STRING_32
        do
            l_expression := safely_trimmed (a_expression)
            if not key_syntax.is_valid_expression (l_expression) then
                add_error (error_codes.invalid_key, "Invalid key", Void, a_line, 1)
            elseif has_sealed_prefix (a_section, l_expression) then
                add_error (error_codes.duplicate_key, "Cannot extend an inline table", Void, a_line, 1)
            elseif has_explicit_descendant_prefix (a_section, l_expression) then
                add_error (error_codes.duplicate_key, "Cannot extend an explicitly defined table", Void, a_line, 1)
            elseif a_document.has_at (l_expression) then
                add_error (error_codes.duplicate_key, "Duplicate key", Void, a_line, 1)
            elseif a_document.can_put_at (l_expression) then
                a_document.put_at (a_value, l_expression)
                mark_dotted_tables (a_section, l_expression)
                if a_value.is_table then
                    sealed_tables.extend (canonical_joined_prefix (a_section, l_expression,
                        joined_path_count (a_section, l_expression)))
                end
            else
                add_error (error_codes.duplicate_key, "Key conflicts with an existing value", Void, a_line, 1)
            end
        end

    has_explicit_descendant_prefix (a_section, a_expression: STRING_32): BOOLEAN
        local i, l_section_count, l_count: INTEGER
        do
            if not a_section.is_empty then
                l_section_count := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count
            end
            l_count := joined_path_count (a_section, a_expression)
            from i := l_section_count + 1 until i >= l_count or else Result loop
                Result := explicit_tables.has (canonical_joined_prefix (a_section, a_expression, i))
                i := i + 1
            end
        end

    reset_array_instance_metadata (a_prefix: STRING_32)
        local i: INTEGER
        do
            from i := explicit_tables.count until i < 1 loop
                if explicit_tables [i].starts_with (a_prefix) and then
                    not explicit_tables [i].same_string (a_prefix)
                then
                    explicit_tables.go_i_th (i)
                    explicit_tables.remove
                end
                i := i - 1
            end
        end

    mark_dotted_tables (a_section, a_expression: STRING_32)
        local
            i, l_section_count, l_count: INTEGER
            l_key: STRING_32
        do
            if a_section.is_empty then l_section_count := 0
            else l_section_count := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count end
            l_count := joined_path_count (a_section, a_expression)
            from i := l_section_count + 1 until i >= l_count loop
                l_key := canonical_joined_prefix (a_section, a_expression, i)
                if not explicit_tables.has (l_key) and then not dotted_tables.has (l_key) then
                    dotted_tables.extend (l_key)
                end
                i := i + 1
            end
        end

    has_sealed_prefix (a_section, a_expression: STRING_32): BOOLEAN
        local i, l_count: INTEGER
        do
            l_count := joined_path_count (a_section, a_expression)
            from i := 1 until i >= l_count or else Result loop
                Result := sealed_tables.has (canonical_joined_prefix (a_section, a_expression, i))
                i := i + 1
            end
        end

    joined_path_count (a_section, a_expression: STRING_32): INTEGER
        do
            if not a_section.is_empty then
                Result := (create {TOMELLE_PATH}.make_from_key_expression (a_section)).count
            end
            Result := Result + (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count
        end

    canonical_expression (a_expression: STRING_32): STRING_32
        local l_empty: STRING_32
        do
            create l_empty.make_empty
            Result := canonical_joined_prefix (l_empty, a_expression,
                (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count)
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
                    Result.append (l_key.count.out)
                    Result.extend (':')
                    Result.append (l_key)
                    Result.extend (';')
                    l_added := l_added + 1
                    i := i + 1
                end
            end
            create l_expression_path.make_from_key_expression (a_expression)
            from i := 1 until i > l_expression_path.count or else l_added = a_count loop
                l_key := l_expression_path [i]
                Result.append (l_key.count.out)
                Result.extend (':')
                Result.append (l_key)
                Result.extend (';')
                l_added := l_added + 1
                i := i + 1
            end
        end

feature {NONE} -- Value parsing

    parsed_value (a_source: STRING_32): detachable TOMELLE_VALUE
        local
            l_text, l_inner, l_part: STRING_32
            l_parts: ARRAYED_LIST [STRING_32]
            l_array: TOMELLE_ARRAY
            l_table: TOMELLE_TABLE
            l_inline_document: TOMELLE_DOCUMENT
            l_inline_sealed: ARRAYED_LIST [STRING_32]
            l_value: detachable TOMELLE_VALUE
            l_equal, i: INTEGER
            l_container_valid: BOOLEAN
        do
            l_text := safely_trimmed (a_source)
            if l_text.count >= 6 and then l_text.substring (1, 3).same_string ("%"%"%"") and then
                l_text.substring (l_text.count - 2, l_text.count).same_string ("%"%"%"")
            then
                l_inner := safe_substring (l_text, 4, l_text.count - 3)
                if not l_inner.is_empty and then l_inner [1] = '%N' then
                    l_inner.remove (1)
                end
                if is_valid_basic_string (l_inner, True) then
                    Result := value_factory.new_parser_string (parser_encoded_string (decoded_basic_string (l_inner)))
                end
            elseif l_text.count >= 6 and then l_text.substring (1, 3).same_string ("%'%'%'") and then
                l_text.substring (l_text.count - 2, l_text.count).same_string ("%'%'%'")
            then
                l_inner := safe_substring (l_text, 4, l_text.count - 3)
                if not l_inner.is_empty and then l_inner [1] = '%N' then
                    l_inner.remove (1)
                end
                if is_valid_literal_string (l_inner, True) then
                    Result := value_factory.new_parser_string (parser_encoded_string (l_inner))
                end
            elseif l_text.count >= 2 and then l_text [1] = '%"' and then l_text [l_text.count] = '%"' then
                l_inner := safe_substring (l_text, 2, l_text.count - 1)
                if is_valid_basic_string (l_inner, False) then
                    Result := value_factory.new_parser_string (parser_encoded_string (decoded_basic_string (l_inner)))
                end
            elseif l_text.count >= 2 and then l_text [1] = '%'' and then l_text [l_text.count] = '%'' then
                l_inner := safe_substring (l_text, 2, l_text.count - 1)
                if is_valid_literal_string (l_inner, False) then
                    Result := value_factory.new_parser_string (parser_encoded_string (l_inner))
                end
            elseif l_text.same_string ("true") then
                Result := value_factory.new_boolean (True)
            elseif l_text.same_string ("false") then
                Result := value_factory.new_boolean (False)
            elseif l_text.count >= 2 and then l_text [1] = '[' and then l_text [l_text.count] = ']' then
                create l_array.make
                l_container_valid := True
                l_inner := safe_substring (l_text, 2, l_text.count - 1)
                if l_inner.is_empty then
                    Result := value_factory.new_array (l_array)
                elseif is_only_separator (l_inner, ',') then
                    l_container_valid := False
                else
                    l_parts := split_top_level (l_inner, ',')
                    from i := 1 until i > l_parts.count loop
                    l_part := safely_trimmed (l_parts [i])
                    if not l_part.is_empty then
                        l_value := parsed_value (l_part)
                        if attached l_value as v then
                            l_array.extend (v)
                        else
                            l_container_valid := False
                        end
                    elseif i < l_parts.count or else has_repeated_trailing_separator (l_inner, ',') then
                        l_container_valid := False
                    end
                    i := i + 1
                    end
                    if l_container_valid then
                        Result := value_factory.new_array (l_array)
                    end
                end
            elseif l_text.count >= 2 and then l_text [1] = '{' and then l_text [l_text.count] = '}' then
                create l_table.make
                create l_inline_sealed.make (0)
                l_inline_sealed.compare_objects
                l_container_valid := True
                l_inner := safe_substring (l_text, 2, l_text.count - 1)
                if l_inner.is_empty then
                    Result := value_factory.new_table (l_table)
                elseif is_only_separator (l_inner, ',') then
                    l_container_valid := False
                else
                    l_parts := split_top_level (l_inner, ',')
                    from i := 1 until i > l_parts.count loop
                        l_part := safely_trimmed (l_parts [i])
                        l_equal := top_level_equal (l_part)
                        if l_part.is_empty then
                            if i < l_parts.count or else has_repeated_trailing_separator (l_inner, ',') then
                                l_container_valid := False
                            end
                        elseif l_equal > 1 then
                        l_value := parsed_value (l_part.substring (l_equal + 1, l_part.count))
                        if attached l_value as v then
                            l_part := safely_trimmed (safe_substring (l_part, 1, l_equal - 1))
                            if key_syntax.is_valid_expression (l_part) then
                                create l_inline_document.make
                                l_inline_document.set_root (l_table)
                                if l_inline_document.can_put_at (l_part) and then not l_inline_document.has_at (l_part) and then
                                    not has_local_sealed_prefix (l_inline_sealed, l_part)
                                then
                                    l_inline_document.put_at (v, l_part)
                                    if v.is_table then l_inline_sealed.extend (canonical_expression (l_part)) end
                                else l_container_valid := False end
                            else l_container_valid := False end
                        else l_container_valid := False end
                        else l_container_valid := False end
                        i := i + 1
                    end
                    if l_container_valid then
                        Result := value_factory.new_table (l_table)
                    end
                end
            elseif attached parsed_temporal_value (l_text) as l_temporal then
                Result := l_temporal
            else
                if valid_numeric_underscores (l_text) then
                    l_text.replace_substring_all ("_", "")
                    if l_text.same_string ("inf") or l_text.same_string ("+inf") then
                        Result := value_factory.new_float ((0.0).positive_infinity)
                    elseif l_text.same_string ("-inf") then
                        Result := value_factory.new_float ((0.0).negative_infinity)
                    elseif l_text.same_string ("nan") or l_text.same_string ("+nan") then
                        Result := value_factory.new_float ((0.0).nan)
                    elseif l_text.same_string ("-nan") then
                        Result := value_factory.new_float (-(0.0).nan)
                    elseif is_based_integer (l_text) then
                        Result := value_factory.new_integer (based_integer (l_text))
                    elseif is_decimal_integer (l_text) and then l_text.is_integer_64 then
                        Result := value_factory.new_integer (l_text.to_integer_64)
                    elseif is_decimal_float (l_text) and then l_text.is_real_64 then
                        Result := value_factory.new_float_with_lexeme (l_text.to_double, l_text)
                    end
                end
            end
        end

    valid_numeric_underscores (a_text: STRING_32): BOOLEAN
        local
            i, l_prefix_end, l_base: INTEGER
        do
            Result := not a_text.is_empty and then a_text [1] /= '_' and then a_text [a_text.count] /= '_'
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
            if i + 1 <= a_text.count and then a_text [i] = '0' then
                inspect a_text [i + 1]
                when 'x' then l_base := 16
                when 'o' then l_base := 8
                when 'b' then l_base := 2
                else end
                if l_base > 0 then l_prefix_end := i + 1 end
            end
            from i := 2 until i >= a_text.count or else not Result loop
                if a_text [i] = '_' then
                    if l_base > 0 then
                        Result := i > l_prefix_end + 1 and then digit_value (a_text [i - 1]) < l_base and then
                            digit_value (a_text [i + 1]) < l_base
                    else
                        Result := a_text [i - 1].is_digit and then a_text [i + 1].is_digit
                    end
                end
                i := i + 1
            end
        end

    is_decimal_integer (a_text: STRING_32): BOOLEAN
        local i, l_digit_count: INTEGER
        do
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then
                i := i + 1
            end
            l_digit_count := a_text.count - i + 1
            Result := l_digit_count > 0 and then is_decimal (a_text.substring (i, a_text.count)) and then
                (l_digit_count = 1 or else a_text [i] /= '0')
        end

    is_decimal_float (a_text: STRING_32): BOOLEAN
        local
            i, l_start, l_integer_digits, l_fraction_digits, l_exponent_digits: INTEGER
            l_has_dot, l_has_exponent: BOOLEAN
        do
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
            l_start := i
            from until i > a_text.count or else not a_text [i].is_digit loop
                l_integer_digits := l_integer_digits + 1
                i := i + 1
            end
            if i <= a_text.count and then a_text [i] = '.' then
                l_has_dot := True
                i := i + 1
                from until i > a_text.count or else not a_text [i].is_digit loop
                    l_fraction_digits := l_fraction_digits + 1
                    i := i + 1
                end
            end
            if i <= a_text.count and then (a_text [i] = 'e' or a_text [i] = 'E') then
                l_has_exponent := True
                i := i + 1
                if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
                from until i > a_text.count or else not a_text [i].is_digit loop
                    l_exponent_digits := l_exponent_digits + 1
                    i := i + 1
                end
            end
            Result := i > a_text.count and l_integer_digits > 0 and
                (l_integer_digits = 1 or else a_text [l_start] /= '0') and
                (l_has_dot or l_has_exponent) and (not l_has_dot or l_fraction_digits > 0) and
                (not l_has_exponent or l_exponent_digits > 0)
        end

    is_based_integer (a_text: STRING_32): BOOLEAN
        local
            i, l_base: INTEGER
            l_valid: BOOLEAN
        do
            i := 1
            if i + 2 <= a_text.count and then a_text [i] = '0' then
                inspect a_text [i + 1]
                when 'x' then l_base := 16
                when 'o' then l_base := 8
                when 'b' then l_base := 2
                else end
                i := i + 2
            end
            l_valid := l_base > 0 and i <= a_text.count
            from until i > a_text.count or else not l_valid loop
                l_valid := digit_value (a_text [i]) < l_base
                i := i + 1
            end
            Result := l_valid
        end

    based_integer (a_text: STRING_32): INTEGER_64
        require based: is_based_integer (a_text)
        local i, l_base, l_sign: INTEGER
        do
            i := 1
            l_sign := 1
            if a_text [i] = '-' then
                l_sign := -1
                i := i + 1
            elseif a_text [i] = '+' then
                i := i + 1
            end
            inspect a_text [i + 1]
            when 'x' then
                l_base := 16
            when 'o' then
                l_base := 8
            when 'b' then
                l_base := 2
            else
            end
            from i := i + 2 until i > a_text.count loop
                Result := Result * l_base + digit_value (a_text [i])
                i := i + 1
            end
            Result := Result * l_sign
        end

    digit_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then Result := 10 + a_character.code - ('a').code
            elseif 'A' <= a_character and a_character <= 'F' then Result := 10 + a_character.code - ('A').code
            else Result := 99 end
        end

    parsed_temporal_value (a_text: STRING_32): detachable TOMELLE_VALUE
        local
            l_date: TOMELLE_LOCAL_DATE
            l_time: TOMELLE_LOCAL_TIME
            l_date_time: TOMELLE_LOCAL_DATE_TIME
            l_offset: TOMELLE_OFFSET_DATE_TIME
            l_year, l_month, l_day, l_hour, l_minute, l_second: INTEGER
            l_nanosecond, l_digits, l_offset_minutes, l_offset_hour, l_offset_minute, l_sign, l_offset_index, i: INTEGER
            l_fraction: STRING_32
            l_valid, l_has_date, l_has_time, l_has_offset: BOOLEAN
        do
            l_has_date := a_text.count >= 10 and then a_text [5] = '-' and then a_text [8] = '-' and then
                is_decimal (a_text.substring (1, 4)) and then is_decimal (a_text.substring (6, 7)) and then
                is_decimal (a_text.substring (9, 10))
            if l_has_date then
                l_year := a_text.substring (1, 4).to_integer
                l_month := a_text.substring (6, 7).to_integer
                l_day := a_text.substring (9, 10).to_integer
                l_valid := l_date.is_valid_date (l_year, l_month, l_day)
            end
            if a_text.count = 10 and l_valid then
                create l_date.make (l_year, l_month, l_day)
                Result := value_factory.new_local_date (l_date)
            else
                if l_has_date and a_text.count >= 16 and then
                    (a_text [11] = 'T' or a_text [11] = 't' or a_text [11] = ' ')
                then
                    i := 12
                elseif a_text.count >= 5 then
                    i := 1
                    l_valid := True
                    l_has_date := False
                else
                    l_valid := False
                end
                if l_valid and then i + 4 <= a_text.count and then a_text [i + 2] = ':' and then
                    is_decimal (a_text.substring (i, i + 1)) and then is_decimal (a_text.substring (i + 3, i + 4))
                then
                    l_hour := a_text.substring (i, i + 1).to_integer
                    l_minute := a_text.substring (i + 3, i + 4).to_integer
                    if i + 7 <= a_text.count and then a_text [i + 5] = ':' and then
                        is_decimal (a_text.substring (i + 6, i + 7))
                    then
                        l_second := a_text.substring (i + 6, i + 7).to_integer
                        i := i + 8
                    else
                        l_second := 0
                        i := i + 5
                    end
                    l_has_time := l_time.is_valid_time (l_hour, l_minute, l_second)
                    if i <= a_text.count and then a_text [i] = '.' then
                        i := i + 1
                        l_offset_index := i
                        from until i > a_text.count or else not a_text [i].is_digit loop i := i + 1 end
                        l_fraction := a_text.substring (l_offset_index, i - 1)
                        l_digits := l_fraction.count
                        if 1 <= l_digits and l_digits <= 9 then
                            from until l_fraction.count = 9 loop l_fraction.extend ('0') end
                            l_nanosecond := l_fraction.to_integer
                        else l_has_time := False end
                    end
                    if i <= a_text.count then
                        if (a_text [i] = 'Z' or a_text [i] = 'z') and i = a_text.count then
                            l_has_offset := True
                            l_offset_minutes := 0
                            i := i + 1
                        elseif (a_text [i] = '+' or a_text [i] = '-') and then i + 5 = a_text.count and then
                            a_text [i + 3] = ':' and then is_decimal (a_text.substring (i + 1, i + 2)) and then
                            is_decimal (a_text.substring (i + 4, i + 5))
                        then
                            if a_text [i] = '-' then
                                l_sign := -1
                            else
                                l_sign := 1
                            end
                            l_offset_hour := a_text.substring (i + 1, i + 2).to_integer
                            l_offset_minute := a_text.substring (i + 4, i + 5).to_integer
                            l_offset_minutes := l_sign * (l_offset_hour * 60 + l_offset_minute)
                            l_has_offset := l_offset_hour <= 23 and l_offset_minute <= 59
                            l_has_time := l_has_time and l_has_offset
                            i := a_text.count + 1
                        else l_has_time := False end
                    end
                    l_valid := l_has_time and i > a_text.count
                    if l_valid then
                        create l_time.make (l_hour, l_minute, l_second, l_nanosecond, l_digits)
                        if l_has_date then
                            create l_date.make (l_year, l_month, l_day)
                            create l_date_time.make (l_date, l_time)
                            if l_has_offset then
                                create l_offset.make (l_date_time, l_offset_minutes)
                                Result := value_factory.new_offset_date_time (l_offset)
                            else Result := value_factory.new_local_date_time (l_date_time) end
                        elseif not l_has_offset then
                            Result := value_factory.new_local_time (l_time)
                        end
                    end
                end
            end
        end

    is_decimal (a_text: STRING_32): BOOLEAN
        local i: INTEGER
        do
            Result := not a_text.is_empty
            from i := 1 until i > a_text.count or else not Result loop
                Result := a_text [i].is_digit
                i := i + 1
            end
        end

feature {NONE} -- Lexical helpers

    parser_encoded_string (a_value: STRING_32): STRING_32
        local
            i, l_shift: INTEGER
            l_code: NATURAL_32
        do
            create Result.make (a_value.count)
            from i := 1 until i > a_value.count loop
                l_code := a_value.code (i)
                if a_value [i] = '~' and then is_code_marker_at (a_value, i) then
                    Result.append (a_value.substring (i, i + 9))
                    i := i + 9
                elseif a_value [i] = '~' and then i < a_value.count and then a_value [i + 1] = '~' then
                    Result.append ("~~")
                    i := i + 1
                elseif a_value [i] = '~' then
                    Result.append ("~~")
                elseif l_code > 255 then
                    Result.extend ('~')
                    from l_shift := 28 until l_shift < 0 loop
                        Result.extend (hex_digit (((l_code |>> l_shift) & 15).to_integer_32))
                        l_shift := l_shift - 4
                    end
                    Result.extend ('~')
                else
                    Result.extend (a_value [i])
                end
                i := i + 1
            end
        end

    append_code_marker (a_target: STRING_32; a_code: NATURAL_32)
        local l_shift: INTEGER
        do
            a_target.extend ('~')
            from l_shift := 28 until l_shift < 0 loop
                a_target.extend (hex_digit (((a_code |>> l_shift) & 15).to_integer_32))
                l_shift := l_shift - 4
            end
            a_target.extend ('~')
        end

    is_code_marker_at (a_text: STRING_32; a_index: INTEGER): BOOLEAN
        local i: INTEGER
        do
            Result := a_index + 9 <= a_text.count and then a_text [a_index + 9] = '~'
            from i := a_index + 1 until i > a_index + 8 or else not Result loop
                Result := a_text [i].is_hexa_digit
                i := i + 1
            end
        end

    hex_digit (a_value: INTEGER): CHARACTER_32
        do
            if a_value < 10 then Result := (('0').code + a_value).to_character_32
            else Result := (('A').code + a_value - 10).to_character_32 end
        end

    key_syntax: TOMELLE_KEY_SYNTAX
        once
            create Result.make
        end
    value_factory: TOMELLE_VALUE_FACTORY
    error_codes: TOMELLE_ERROR_CODE
        once
            create Result.default_create
        end

    logical_lines (a_source: STRING_32): ARRAYED_LIST [STRING_32]
            -- Logical statements, joining newlines inside containers and
            -- multiline strings.
        local
            i, l_depth, l_run, j: INTEGER
            l_current: STRING_32
            l_quote: CHARACTER_32
            l_multiline, l_escaped, l_comment: BOOLEAN
        do
            create Result.make (1)
            create l_current.make_empty
            from i := 1 until i > a_source.count loop
                if l_comment then
                    if a_source [i] = '%N' then
                        l_comment := False
                        if l_depth = 0 then
                            Result.extend (l_current)
                            create l_current.make_empty
                        else
                            l_current.extend (' ')
                        end
                    end
                elseif l_quote = '%U' then
                    if i + 2 <= a_source.count and then
                        ((a_source [i] = '%"' and a_source [i + 1] = '%"' and a_source [i + 2] = '%"') or else
                         (a_source [i] = '%'' and a_source [i + 1] = '%'' and a_source [i + 2] = '%''))
                    then
                        l_quote := a_source [i]
                        l_multiline := True
                        l_current.extend (a_source [i])
                        l_current.extend (a_source [i])
                        l_current.extend (a_source [i])
                        i := i + 2
                    elseif a_source [i] = '%"' or a_source [i] = '%'' then
                        l_quote := a_source [i]
                        l_current.extend (a_source [i])
                    elseif a_source [i] = '#' then l_comment := True
                    elseif a_source [i] = '[' or a_source [i] = '{' then
                        l_depth := l_depth + 1
                        l_current.extend (a_source [i])
                    elseif a_source [i] = ']' or a_source [i] = '}' then
                        l_depth := l_depth - 1
                        l_current.extend (a_source [i])
                    elseif a_source [i] = '%N' then
                        if l_depth = 0 then
                            Result.extend (l_current)
                            create l_current.make_empty
                        else
                            l_current.extend (' ')
                        end
                    else l_current.extend (a_source [i]) end
                elseif l_multiline then
                    if a_source [i] = l_quote and then not l_escaped
                    then
                        from l_run := 0 until i + l_run > a_source.count or else
                            a_source [i + l_run] /= l_quote
                        loop
                            l_run := l_run + 1
                        end
                        if 3 <= l_run and l_run <= 5 then
                            from j := 1 until j > l_run - 3 loop
                                l_current.extend (l_quote)
                                j := j + 1
                            end
                            l_current.extend (l_quote)
                            l_current.extend (l_quote)
                            l_current.extend (l_quote)
                            i := i + l_run - 1
                            l_quote := '%U'
                            l_multiline := False
                        else
                            l_current.extend (a_source [i])
                        end
                    else
                        l_current.extend (a_source [i])
                        l_escaped := l_quote = '%"' and then a_source [i] = '\' and then not l_escaped
                        if a_source [i] /= '\' then l_escaped := False end
                    end
                else
                    l_current.extend (a_source [i])
                    if a_source [i] = l_quote and then not l_escaped then l_quote := '%U' end
                    l_escaped := l_quote = '%"' and then a_source [i] = '\' and then not l_escaped
                    if a_source [i] /= '\' then l_escaped := False end
                end
                i := i + 1
            end
            if not l_current.is_empty then Result.extend (l_current) end
        end

    safe_substring (a_text: STRING_32; a_start, a_end: INTEGER): STRING_32
        local i: INTEGER
        do
            create Result.make ((a_end - a_start + 1).max (0))
            from i := a_start until i > a_end loop
                Result.extend (a_text [i])
                i := i + 1
            end
        end

    safely_trimmed (a_text: STRING_32): STRING_32
        local l_start, l_end: INTEGER
        do
            from l_start := 1 until l_start > a_text.count or else not a_text [l_start].is_space loop
                l_start := l_start + 1
            end
            from l_end := a_text.count until l_end < l_start or else not a_text [l_end].is_space loop
                l_end := l_end - 1
            end
            Result := safe_substring (a_text, l_start, l_end)
        end

    without_comment (a_line: STRING_32): STRING_32
        local
            i: INTEGER
            l_quote: CHARACTER_32
            l_escaped: BOOLEAN
        do
            from i := 1 until i > a_line.count or else (a_line [i] = '#' and l_quote = '%U') loop
                if l_quote = '%U' and then (a_line [i] = '%"' or a_line [i] = '%'') then l_quote := a_line [i]
                elseif l_quote /= '%U' and then a_line [i] = l_quote and then not l_escaped then l_quote := '%U' end
                l_escaped := l_quote = '%"' and then a_line [i] = '\' and then not l_escaped
                if a_line [i] /= '\' then l_escaped := False end
                i := i + 1
            end
            Result := safe_substring (a_line, 1, i - 1)
        end

    top_level_equal (a_text: STRING_32): INTEGER
        local
            i, l_depth: INTEGER
            l_quote: CHARACTER_32
        do
            from i := 1 until i > a_text.count or Result > 0 loop
                if l_quote = '%U' then
                    if a_text [i] = '%"' or a_text [i] = '%'' then l_quote := a_text [i]
                    elseif a_text [i] = '[' or a_text [i] = '{' then l_depth := l_depth + 1
                    elseif a_text [i] = ']' or a_text [i] = '}' then l_depth := l_depth - 1
                    elseif a_text [i] = '=' and l_depth = 0 then Result := i end
                elseif a_text [i] = l_quote and then (i = 1 or else a_text [i - 1] /= '\') then l_quote := '%U' end
                i := i + 1
            end
        end

    split_top_level (a_text: STRING_32; a_separator: CHARACTER_32): ARRAYED_LIST [STRING_32]
        local
            i, l_start, l_depth: INTEGER
            l_quote: CHARACTER_32
        do
            create Result.make (1)
            l_start := 1
            from i := 1 until i > a_text.count loop
                if l_quote = '%U' then
                    if a_text [i] = '%"' or a_text [i] = '%'' then l_quote := a_text [i]
                    elseif a_text [i] = '[' or a_text [i] = '{' then l_depth := l_depth + 1
                    elseif a_text [i] = ']' or a_text [i] = '}' then l_depth := l_depth - 1
                    elseif a_text [i] = a_separator and l_depth = 0 then
                        Result.extend (safe_substring (a_text, l_start, i - 1))
                        l_start := i + 1
                    end
                elseif a_text [i] = l_quote and then (i = 1 or else a_text [i - 1] /= '\') then l_quote := '%U' end
                i := i + 1
            end
            if l_start <= a_text.count then Result.extend (safe_substring (a_text, l_start, a_text.count))
            elseif a_text.is_empty then Result.extend (create {STRING_32}.make_empty) end
        end

    has_repeated_trailing_separator (a_text: STRING_32; a_separator: CHARACTER_32): BOOLEAN
        local
            l_text: STRING_32
        do
            l_text := a_text.twin
            l_text.right_adjust
            Result := l_text.count >= 2 and then l_text [l_text.count] = a_separator and then
                l_text [l_text.count - 1] = a_separator
        end

    is_only_separator (a_text: STRING_32; a_separator: CHARACTER_32): BOOLEAN
        local l_text: STRING_32
        do
            l_text := a_text.twin
            l_text.left_adjust
            l_text.right_adjust
            Result := l_text.count = 1 and then l_text [1] = a_separator
        end

    has_local_sealed_prefix (a_sealed: ARRAYED_LIST [STRING_32]; a_expression: STRING_32): BOOLEAN
        local i, l_count: INTEGER
        do
            l_count := (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count
            from i := 1 until i >= l_count or else Result loop
                Result := a_sealed.has (canonical_joined_prefix ((create {STRING_32}.make_empty),
                    a_expression, i))
                i := i + 1
            end
        end

    decoded_basic_string (a_text: STRING_32): STRING_32
        local
            i, j, k, l_digits: INTEGER
            l_code: NATURAL_64
        do
            create Result.make (a_text.count)
            from i := 1 until i > a_text.count loop
                if a_text [i] = '\' and then i < a_text.count then
                    i := i + 1
                    k := i
                    from until k > a_text.count or else (a_text [k] /= ' ' and a_text [k] /= '%T') loop k := k + 1 end
                    if k <= a_text.count and then (a_text [k] = '%N' or a_text [k] = '%R') then
                        i := k + 1
                        if a_text [k] = '%R' and then i <= a_text.count and then a_text [i] = '%N' then i := i + 1 end
                        from until i > a_text.count or else not a_text [i].is_space loop i := i + 1 end
                        i := i - 1
                    else inspect a_text [i]
                    when 'n' then Result.extend ('%N')
                    when 'r' then Result.extend ('%R')
                    when 't' then Result.extend ('%T')
                    when 'b' then Result.extend ('%B')
                    when 'f' then Result.extend ('%F')
                    when 'e' then Result.extend ((27).to_character_32)
                    when 'x', 'u', 'U' then
                        if a_text [i] = 'x' then l_digits := 2 elseif a_text [i] = 'u' then l_digits := 4 else l_digits := 8 end
                        if i + l_digits <= a_text.count then
                            l_code := 0
                            from j := 1 until j > l_digits loop
                                l_code := l_code * 16 + digit_value (a_text [i + j]).to_natural_64
                                j := j + 1
                            end
                            if l_code > 255 then append_code_marker (Result, l_code.to_natural_32)
                            elseif l_code = ('~').code.to_natural_64 then Result.append ("~~")
                            else Result.append_code (l_code.to_natural_32) end
                            i := i + l_digits
                        end
                    else Result.extend (a_text [i]) end
                    end
                else Result.extend (a_text [i]) end
                i := i + 1
            end
        end

    is_valid_basic_string (a_text: STRING_32; a_multiline: BOOLEAN): BOOLEAN
        local
            i, j, k, l_digits, l_quote_run: INTEGER
            l_code: NATURAL_64
            c: CHARACTER_32
        do
            Result := True
            from i := 1 until i > a_text.count or else not Result loop
                c := a_text [i]
                if c = '\' then
                    i := i + 1
                    Result := i <= a_text.count
                    if Result then
                        c := a_text [i]
                        k := i
                        from until k > a_text.count or else (a_text [k] /= ' ' and a_text [k] /= '%T') loop k := k + 1 end
                        if a_multiline and then k <= a_text.count and then (a_text [k] = '%N' or a_text [k] = '%R') then
                            i := k
                        else
                        Result := c = 'b' or c = 't' or c = 'n' or c = 'f' or c = 'r' or c = 'e' or
                            c = '%"' or c = '\' or c = 'x' or c = 'u' or c = 'U'
                        if Result and then (c = 'x' or c = 'u' or c = 'U') then
                            if c = 'x' then l_digits := 2 elseif c = 'u' then l_digits := 4 else l_digits := 8 end
                            Result := i + l_digits <= a_text.count
                            from j := i + 1 until j > i + l_digits or else not Result loop
                                Result := a_text [j].is_hexa_digit
                                j := j + 1
                            end
                            if Result then
                                l_code := 0
                                from j := 1 until j > l_digits loop
                                    l_code := l_code * 16 + digit_value (a_text [i + j]).to_natural_64
                                    j := j + 1
                                end
                                Result := l_code <= 0x10FFFF and then not (0xD800 <= l_code and l_code <= 0xDFFF)
                            end
                            i := i + l_digits
                        end
                        end
                    end
                elseif c = '%"' then
                    Result := a_multiline
                    if Result then
                        from l_quote_run := 0 until i + l_quote_run > a_text.count or else
                            a_text [i + l_quote_run] /= '%"'
                        loop
                            l_quote_run := l_quote_run + 1
                        end
                        Result := l_quote_run <= 2
                        i := i + l_quote_run - 1
                    end
                elseif c = '%N' or c = '%R' then Result := a_multiline
                elseif c.code < 32 and c /= '%T' or else c.code = 127 then Result := False
                end
                i := i + 1
            end
        end

    is_valid_literal_string (a_text: STRING_32; a_multiline: BOOLEAN): BOOLEAN
        local
            i, l_quote_run: INTEGER
            c: CHARACTER_32
        do
            Result := True
            from i := 1 until i > a_text.count or else not Result loop
                c := a_text [i]
                if c = '%'' then
                    Result := a_multiline
                    if Result then
                        from l_quote_run := 0 until i + l_quote_run > a_text.count or else
                            a_text [i + l_quote_run] /= '%''
                        loop
                            l_quote_run := l_quote_run + 1
                        end
                        Result := l_quote_run <= 2
                        i := i + l_quote_run - 1
                    end
                elseif c = '%N' or c = '%R' then Result := a_multiline
                elseif c.code < 32 and c /= '%T' or else c.code = 127 then Result := False end
                i := i + 1
            end
        end

feature {NONE} -- UTF-8 and errors

    has_valid_control_characters (a_source: STRING_32): BOOLEAN
        local
            i: INTEGER
            c: NATURAL_32
        do
            Result := True
            from i := 1 until i > a_source.count or else not Result loop
                c := a_source.code (i)
                if c = 13 then
                    Result := i < a_source.count and then a_source.code (i + 1) = 10
                elseif c < 32 then
                    Result := c = 9 or c = 10
                else
                    Result := c /= 127 and c /= 0x2028 and c /= 0x2029 and c /= 0x3000
                end
                i := i + 1
            end
        end

    has_valid_line_boundaries (a_source: STRING_32): BOOLEAN
        local
            i: INTEGER
            l_quote: CHARACTER_32
            l_multiline, l_escaped, l_comment: BOOLEAN
        do
            Result := True
            from i := 1 until i > a_source.count or else not Result loop
                if l_comment then
                    if a_source [i] = '%N' then l_comment := False end
                elseif l_multiline then
                    if i + 2 <= a_source.count and then a_source [i] = l_quote and then
                        a_source [i + 1] = l_quote and then a_source [i + 2] = l_quote and then not l_escaped
                    then
                        l_multiline := False
                        l_quote := '%U'
                        i := i + 2
                    end
                    l_escaped := a_source [i] = '\' and then not l_escaped
                    if a_source [i] /= '\' then l_escaped := False end
                elseif l_quote /= '%U' then
                    if a_source [i] = '%N' or a_source [i] = '%R' then
                        Result := False
                    elseif a_source [i] = l_quote and then not l_escaped then
                        l_quote := '%U'
                    end
                    l_escaped := a_source [i] = '\' and then not l_escaped
                    if a_source [i] /= '\' then l_escaped := False end
                else
                    if i + 2 <= a_source.count and then
                        ((a_source [i] = '%"' and a_source [i + 1] = '%"' and a_source [i + 2] = '%"') or else
                         (a_source [i] = '%'' and a_source [i + 1] = '%'' and a_source [i + 2] = '%''))
                    then
                        l_quote := a_source [i]
                        l_multiline := True
                        i := i + 2
                    elseif a_source [i] = '%"' or a_source [i] = '%'' then
                        l_quote := a_source [i]
                    elseif a_source [i] = '#' then
                        l_comment := True
                    end
                end
                i := i + 1
            end
            Result := Result and then l_quote = '%U'
        end

    headers_close_on_same_line (a_source: STRING_32): BOOLEAN
        local
            l_lines: LIST [STRING_32]
            l_line: STRING_32
            l_depth: INTEGER
        do
            Result := True
            l_lines := a_source.split ('%N')
            from l_lines.start until l_lines.after or else not Result loop
                l_line := l_lines.item.twin
                l_line.left_adjust
                if l_depth = 0 and then not l_line.is_empty and then l_line [1] = '[' then
                    Result := l_line.has (']')
                elseif l_depth = 0 and then not l_line.is_empty and then
                    (l_line [1] = '%"' or else l_line [1] = '%'')
                then
                    Result := l_line.occurrences (l_line [1]) >= 2
                else
                    l_depth := l_depth + l_line.occurrences ('[') + l_line.occurrences ('{') -
                        l_line.occurrences (']') - l_line.occurrences ('}')
                end
                l_lines.forth
            end
        end

    decoded_utf_8 (a_bytes: STRING_8): detachable STRING_32
        local
            i, n, c, c2, c3, c4, l_code: INTEGER
            l_valid: BOOLEAN
        do
            create Result.make (a_bytes.count)
            n := a_bytes.count
            l_valid := True
            from i := 1 until i > n or else not l_valid loop
                c := a_bytes.code (i).to_integer_32
                if c <= 127 then l_code := c
                elseif 194 <= c and c <= 223 and i + 1 <= n then
                    c2 := a_bytes.code (i + 1).to_integer_32
                    l_valid := 128 <= c2 and c2 <= 191
                    l_code := (c - 192) * 64 + c2 - 128
                    i := i + 1
                elseif 224 <= c and c <= 239 and i + 2 <= n then
                    c2 := a_bytes.code (i + 1).to_integer_32
                    c3 := a_bytes.code (i + 2).to_integer_32
                    l_valid := 128 <= c2 and c2 <= 191 and 128 <= c3 and c3 <= 191 and
                        (c /= 224 or else c2 >= 160) and (c /= 237 or else c2 <= 159)
                    l_code := (c - 224) * 4096 + (c2 - 128) * 64 + c3 - 128
                    i := i + 2
                elseif 240 <= c and c <= 244 and i + 3 <= n then
                    c2 := a_bytes.code (i + 1).to_integer_32
                    c3 := a_bytes.code (i + 2).to_integer_32
                    c4 := a_bytes.code (i + 3).to_integer_32
                    l_valid := 128 <= c2 and c2 <= 191 and 128 <= c3 and c3 <= 191 and 128 <= c4 and c4 <= 191 and
                        (c /= 240 or else c2 >= 144) and (c /= 244 or else c2 <= 143)
                    l_code := (c - 240) * 262144 + (c2 - 128) * 4096 + (c3 - 128) * 64 + c4 - 128
                    i := i + 3
                else l_valid := False end
                if l_valid and then l_code <= 1114111 and then not (55296 <= l_code and l_code <= 57343) then
                    Result.append_code (l_code.to_natural_32)
                else l_valid := False end
                i := i + 1
            end
            if not l_valid then Result := Void end
        end

    add_error (a_code: TOMELLE_ERROR_CODE; a_message: READABLE_STRING_GENERAL;
        a_source: detachable READABLE_STRING_GENERAL; a_line, a_column: INTEGER)
        local
            l_error: TOMELLE_PARSE_ERROR
            l_position: TOMELLE_SOURCE_POSITION
        do
            create l_position.make (0, a_line, a_column)
            if attached a_source as l_source then
                create l_error.make (a_code, a_message, l_source, l_position)
            else
                create l_error.make (a_code, a_message, current_source_name, l_position)
            end
            internal_errors.extend (l_error)
        end

    internal_errors: ARRAYED_LIST [TOMELLE_PARSE_ERROR]
    explicit_tables: ARRAYED_LIST [STRING_32]
    dotted_tables: ARRAYED_LIST [STRING_32]
    sealed_tables: ARRAYED_LIST [STRING_32]
    array_tables: ARRAYED_LIST [STRING_32]
    current_source_name: detachable STRING_32

invariant
    not_parsed_has_no_document: not is_parsed implies document = Void
    not_parsed_has_no_errors: not is_parsed implies error_count = 0
    successful_has_document: is_successful implies attached document
    unsuccessful_has_no_document: is_parsed and then not is_successful implies document = Void

end
