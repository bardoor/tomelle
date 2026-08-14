note
    description: "Parses a logical line into a typed TOML statement."

class
    TOMELLE_STATEMENT_PARSER

feature -- Parsing

    parse (a_line: TOMELLE_LOGICAL_LINE): detachable TOMELLE_STATEMENT
        local
            l_content, l_expression, l_value, l_source_value: STRING_32
            l_equal, l_value_column, l_value_end: INTEGER
        do
            l_content := lexical.trimmed (a_line.text)
            if l_content.count >= 4 and then l_content.substring (1, 2).same_string ("[[") and then
                l_content.substring (l_content.count - 1, l_content.count).same_string ("]]" )
            then
                l_expression := lexical.trimmed (lexical.substring (l_content, 3, l_content.count - 2))
                if key_syntax.is_valid_expression (l_expression) then
                    create {TOMELLE_ARRAY_TABLE_HEADER} Result.make (l_expression, a_line.position)
                end
            elseif not l_content.is_empty and then l_content [1] = '[' then
                if l_content.count >= 2 and then l_content [l_content.count] = ']' then
                    l_expression := lexical.trimmed (lexical.substring (l_content, 2, l_content.count - 1))
                    if key_syntax.is_valid_expression (l_expression) then
                        create {TOMELLE_TABLE_HEADER} Result.make (l_expression, a_line.position)
                    end
                end
            elseif not l_content.is_empty then
                l_equal := lexical.top_level_equal (l_content)
                if l_equal > 1 then
                    l_expression := lexical.trimmed (l_content.substring (1, l_equal - 1))
                    l_value := lexical.substring (l_content, l_equal + 1, l_content.count)
                    if key_syntax.is_valid_expression (l_expression) then
                        l_value_column := first_value_column (a_line.text)
                        from l_value_end := a_line.text.count until
                            l_value_end < l_value_column or else not a_line.text [l_value_end].is_space
                        loop
                            l_value_end := l_value_end - 1
                        end
                        l_source_value := lexical.substring (a_line.source_text, l_value_column, l_value_end)
                        create {TOMELLE_KEY_VALUE_STATEMENT} Result.make (l_expression, l_value, l_source_value,
                            a_line.position, l_value_column)
                    end
                end
            end
        end

feature {NONE} -- Implementation

    first_value_column (a_text: STRING_32): INTEGER
        local
            i: INTEGER
        do
            i := lexical.top_level_equal (a_text) + 1
            from until i > a_text.count or else not a_text [i].is_space loop
                i := i + 1
            end
            Result := i.max (1)
        end

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    key_syntax: TOMELLE_KEY_SYNTAX once create Result.make end

end
