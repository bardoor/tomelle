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
            -- Compatibility query; prefer `parse_result` when diagnostics matter.
        local
            l_result: TOMELLE_VALUE_PARSE_RESULT
        do
            l_result := parse_result (a_source)
            Result := l_result.value
        end

    parse_result (a_source: STRING_32): TOMELLE_VALUE_PARSE_RESULT
        local l_text: STRING_32
            l_value: detachable TOMELLE_VALUE
        do
            l_text := lexical.trimmed (a_source)
            if l_text.is_empty then
                create Result.make_failure (error_codes.unexpected_end_of_input,
                    "Expected TOML value", 1)
            elseif l_text [1] = '%"' or l_text [1] = '%'' then
                l_value := string_parser.parse (l_text)
                if attached l_value as v then
                    create Result.make_success (v)
                elseif not has_matching_string_delimiter (l_text) then
                    create Result.make_failure (error_codes.unexpected_end_of_input,
                        "Unterminated TOML string", l_text.count.max (1))
                else
                    create Result.make_failure (error_codes.invalid_string,
                        "Invalid TOML string", 1)
                end
            elseif l_text.same_string ("true") then
                create Result.make_success (value_factory.new_boolean (True))
            elseif l_text.same_string ("false") then
                create Result.make_success (value_factory.new_boolean (False))
            elseif l_text [1] = '[' then
                if l_text.count < 2 or else l_text [l_text.count] /= ']' then
                    create Result.make_failure (error_codes.unexpected_end_of_input,
                        "Unterminated TOML array", l_text.count.max (1))
                else
                    l_value := container_parser.parse_array (l_text)
                    if attached l_value as v then
                        create Result.make_success (v)
                    else
                        create Result.make_failure (error_codes.invalid_syntax,
                            "Invalid TOML array", 1)
                    end
                end
            elseif l_text [1] = '{' then
                if l_text.count < 2 or else l_text [l_text.count] /= '}' then
                    create Result.make_failure (error_codes.unexpected_end_of_input,
                        "Unterminated inline table", l_text.count.max (1))
                else
                    l_value := container_parser.parse_inline_table (l_text)
                    if attached l_value as v then
                        create Result.make_success (v)
                    else
                        create Result.make_failure (error_codes.invalid_syntax,
                            "Invalid inline table", 1)
                    end
                end
            elseif attached temporal_parser.parse (l_text) as l_temporal then
                create Result.make_success (l_temporal)
            else
                l_value := number_parser.parse (l_text)
                if attached l_value as v then
                    create Result.make_success (v)
                elseif number_parser.is_integer_out_of_range (l_text) then
                    create Result.make_failure (error_codes.integer_out_of_range,
                        "TOML integer is outside the signed 64-bit range", 1)
                elseif looks_temporal (l_text) then
                    create Result.make_failure (error_codes.invalid_date_time,
                        "Invalid TOML date or time", 1)
                else
                    create Result.make_failure (error_codes.invalid_number,
                        "Invalid TOML number or value", 1)
                end
            end
        end

feature {NONE} -- Classification

    has_matching_string_delimiter (a_text: STRING_32): BOOLEAN
        do
            if a_text.count >= 6 and then
                ((a_text.substring (1, 3).same_string ("%"%"%"") and then
                    a_text.substring (a_text.count - 2, a_text.count).same_string ("%"%"%"")) or else
                 (a_text.substring (1, 3).same_string ("%'%'%'") and then
                    a_text.substring (a_text.count - 2, a_text.count).same_string ("%'%'%'")))
            then
                Result := True
            elseif a_text.count >= 2 then
                Result := a_text [a_text.count] = a_text [1]
            end
        end

    looks_temporal (a_text: STRING_32): BOOLEAN
        do
            Result := a_text.has (':') or else
                (a_text.count >= 5 and then a_text [5] = '-')
        end

feature {NONE} -- Parsers

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    string_parser: TOMELLE_STRING_PARSER once create Result.make end
    number_parser: TOMELLE_NUMBER_PARSER once create Result.make end
    temporal_parser: TOMELLE_TEMPORAL_PARSER once create Result.make end
    container_parser: TOMELLE_CONTAINER_PARSER once create Result.make end
    value_factory: TOMELLE_VALUE_FACTORY
    error_codes: TOMELLE_ERROR_CODE once create Result.default_create end

end
