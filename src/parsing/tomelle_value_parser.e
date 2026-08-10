note
    description: "Dispatches TOML values to scalar and container parsers."

class
    TOMELLE_VALUE_PARSER

create
    make

feature {NONE} -- Initialization

    make do create value_factory.make end

feature -- Parsing

    parse (a_source: STRING_32): detachable TOMELLE_VALUE
        local l_text: STRING_32
        do
            l_text := lexical.trimmed (a_source)
            if not l_text.is_empty and then (l_text [1] = '%"' or l_text [1] = '%'') then
                Result := string_parser.parse (l_text)
            elseif l_text.same_string ("true") then
                Result := value_factory.new_boolean (True)
            elseif l_text.same_string ("false") then
                Result := value_factory.new_boolean (False)
            elseif l_text.count >= 2 and then l_text [1] = '[' and then l_text [l_text.count] = ']' then
                Result := container_parser.parse_array (l_text)
            elseif l_text.count >= 2 and then l_text [1] = '{' and then l_text [l_text.count] = '}' then
                Result := container_parser.parse_inline_table (l_text)
            elseif attached temporal_parser.parse (l_text) as l_temporal then
                Result := l_temporal
            else
                Result := number_parser.parse (l_text)
            end
        end

feature {NONE} -- Parsers

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    string_parser: TOMELLE_STRING_PARSER once create Result.make end
    number_parser: TOMELLE_NUMBER_PARSER once create Result.make end
    temporal_parser: TOMELLE_TEMPORAL_PARSER once create Result.make end
    container_parser: TOMELLE_CONTAINER_PARSER once create Result.make end
    value_factory: TOMELLE_VALUE_FACTORY

end
