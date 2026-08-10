note
    description: "Recursively parses TOML arrays and inline tables."

class
    TOMELLE_CONTAINER_PARSER

create
    make

feature {NONE} -- Initialization

    make do create value_factory.make end

feature -- Parsing

    parse_array (a_text: STRING_32): detachable TOMELLE_VALUE
        require
            delimited: a_text.count >= 2 and then a_text [1] = '[' and then a_text [a_text.count] = ']'
        local
            l_inner, l_part: STRING_32
            l_parts: ARRAYED_LIST [STRING_32]
            l_array: TOMELLE_ARRAY
            l_value: detachable TOMELLE_VALUE
            i: INTEGER
            l_valid: BOOLEAN
        do
            create l_array.make
            l_valid := True
            l_inner := lexical.substring (a_text, 2, a_text.count - 1)
            if l_inner.is_empty then
                Result := value_factory.new_array (l_array)
            elseif not lexical.is_only_separator (l_inner, ',') then
                l_parts := lexical.split_top_level (l_inner, ',')
                from i := 1 until i > l_parts.count loop
                    l_part := lexical.trimmed (l_parts [i])
                    if not l_part.is_empty then
                        l_value := value_parser.parse (l_part)
                        if attached l_value as v then l_array.extend (v) else l_valid := False end
                    elseif i < l_parts.count or else lexical.has_repeated_trailing_separator (l_inner, ',') then
                        l_valid := False
                    end
                    i := i + 1
                end
                if l_valid then Result := value_factory.new_array (l_array) end
            end
        end

    parse_inline_table (a_text: STRING_32): detachable TOMELLE_VALUE
        require
            delimited: a_text.count >= 2 and then a_text [1] = '{' and then a_text [a_text.count] = '}'
        local
            l_inner, l_part, l_expression: STRING_32
            l_parts: ARRAYED_LIST [STRING_32]
            l_table: TOMELLE_TABLE
            l_document: TOMELLE_DOCUMENT
            l_sealed: ARRAYED_LIST [STRING_32]
            l_value: detachable TOMELLE_VALUE
            l_equal, i: INTEGER
            l_valid: BOOLEAN
        do
            create l_table.make
            create l_sealed.make (0)
            l_sealed.compare_objects
            l_valid := True
            l_inner := lexical.substring (a_text, 2, a_text.count - 1)
            if l_inner.is_empty then
                Result := value_factory.new_table (l_table)
            elseif not lexical.is_only_separator (l_inner, ',') then
                l_parts := lexical.split_top_level (l_inner, ',')
                from i := 1 until i > l_parts.count loop
                    l_part := lexical.trimmed (l_parts [i])
                    l_equal := lexical.top_level_equal (l_part)
                    if l_part.is_empty then
                        if i < l_parts.count or else lexical.has_repeated_trailing_separator (l_inner, ',') then l_valid := False end
                    elseif l_equal > 1 then
                        l_value := value_parser.parse (l_part.substring (l_equal + 1, l_part.count))
                        if attached l_value as v then
                            l_expression := lexical.trimmed (lexical.substring (l_part, 1, l_equal - 1))
                            if key_syntax.is_valid_expression (l_expression) then
                                create l_document.make
                                l_document.set_root (l_table)
                                if l_document.can_put_at (l_expression) and then not l_document.has_at (l_expression) and then
                                    not has_sealed_prefix (l_sealed, l_expression)
                                then
                                    l_document.put_at (v, l_expression)
                                    if v.is_table then l_sealed.extend (canonical_expression (l_expression)) end
                                else l_valid := False end
                            else l_valid := False end
                        else l_valid := False end
                    else l_valid := False end
                    i := i + 1
                end
                if l_valid then Result := value_factory.new_table (l_table) end
            end
        end

feature {NONE} -- Inline table state

    has_sealed_prefix (a_sealed: ARRAYED_LIST [STRING_32]; a_expression: STRING_32): BOOLEAN
        local i, l_count: INTEGER
        do
            l_count := (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count
            from i := 1 until i >= l_count or else Result loop
                Result := a_sealed.has (canonical_prefix (a_expression, i))
                i := i + 1
            end
        end

    canonical_expression (a_expression: STRING_32): STRING_32
        do
            Result := canonical_prefix (a_expression,
                (create {TOMELLE_PATH}.make_from_key_expression (a_expression)).count)
        end

    canonical_prefix (a_expression: STRING_32; a_count: INTEGER): STRING_32
        local i: INTEGER; l_path: TOMELLE_PATH; l_key: READABLE_STRING_32
        do
            create Result.make_empty
            create l_path.make_from_key_expression (a_expression)
            from i := 1 until i > l_path.count or else i > a_count loop
                l_key := l_path [i]
                Result.append (l_key.count.out)
                Result.extend (':')
                Result.append (l_key)
                Result.extend (';')
                i := i + 1
            end
        end

feature {NONE} -- Parsers

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    key_syntax: TOMELLE_KEY_SYNTAX once create Result.make end
    value_parser: TOMELLE_VALUE_PARSER once create Result.make end
    value_factory: TOMELLE_VALUE_FACTORY

end
