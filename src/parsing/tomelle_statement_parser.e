note
    description: "Parses a logical line into a typed TOML statement."

class
    TOMELLE_STATEMENT_PARSER

feature -- Parsing

    parse (a_line: TOMELLE_LOGICAL_LINE): detachable TOMELLE_STATEMENT
        local
            l_content, l_expression, l_value: STRING_32
            l_equal: INTEGER
        do
            l_content := lexical.trimmed (lexical.without_comment (a_line.text))
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
                        create {TOMELLE_KEY_VALUE_STATEMENT} Result.make (l_expression, l_value, a_line.position)
                    end
                end
            end
        end

feature {NONE} -- Implementation

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    key_syntax: TOMELLE_KEY_SYNTAX once create Result.make end

end
