note
    description: "Immutable TOML parse error."

class
    TOMELLE_PARSE_ERROR

create {TOMELLE_PARSER, TOMELLE_ERROR_COLLECTOR}
    make

feature {NONE} -- Initialization

    make (a_code: TOMELLE_ERROR_CODE; a_message: READABLE_STRING_GENERAL;
        a_source_name: detachable READABLE_STRING_GENERAL; a_position: TOMELLE_SOURCE_POSITION)
        require
            parse_code: a_code.is_parse_code
        do
            code := a_code
            message := a_message.as_string_32.twin
            if attached a_source_name as l_name then
                source_name := l_name.as_string_32.twin
            end
            position := a_position
        end

feature -- Access

    code: TOMELLE_ERROR_CODE
    message: STRING_32
    source_name: detachable STRING_32
    position: TOMELLE_SOURCE_POSITION

feature -- Classification

    is_syntax_error: BOOLEAN
        do
            Result := code.is_parse_code and code /= code.invalid_utf_8 and code /= code.input_unreadable
        end

    is_encoding_error: BOOLEAN
        do
            Result := code = code.invalid_utf_8
        end

    is_input_error: BOOLEAN
        do
            Result := code = code.input_unreadable
        end

invariant
    parse_code: code.is_parse_code

end
