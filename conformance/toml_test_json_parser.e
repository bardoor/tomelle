note
    description: "Strict parser for the object, array, and string JSON subset used by toml-test."

class
    TOML_TEST_JSON_PARSER

create
    make

feature {NONE} -- Initialization

    make
        do
            create source.make_empty
        end

feature -- Parsing

    parse (a_source: READABLE_STRING_GENERAL)
        do
            source := a_source.as_string_32.twin
            index := 1
            error_message := Void
            root := parsed_value
            skip_whitespace
            if not has_error and then index <= source.count then
                set_error ("Unexpected content after JSON value")
            end
            if has_error then
                root := Void
            end
        end

feature -- Result

    root: detachable TOML_TEST_JSON_VALUE
    error_message: detachable STRING_32

    has_error: BOOLEAN
        do
            Result := error_message /= Void
        end

feature {NONE} -- Grammar

    parsed_value: detachable TOML_TEST_JSON_VALUE
        do
            skip_whitespace
            if index > source.count then
                set_error ("Expected JSON value")
            elseif source [index] = '%"' then
                if attached parsed_string as l_string then
                    create Result.make_string (l_string)
                end
            elseif source [index] = '[' then
                Result := parsed_array
            elseif source [index] = '{' then
                Result := parsed_object
            else
                set_error ("toml-test JSON may contain only objects, arrays, and strings")
            end
        end

    parsed_array: detachable TOML_TEST_JSON_VALUE
        local
            l_done: BOOLEAN
            l_value: detachable TOML_TEST_JSON_VALUE
        do
            create Result.make_array
            index := index + 1
            skip_whitespace
            if index <= source.count and then source [index] = ']' then
                index := index + 1
            else
                from until l_done or else has_error loop
                    l_value := parsed_value
                    if attached l_value as v then Result.extend_array (v) end
                    skip_whitespace
                    if index > source.count then
                        set_error ("Unterminated JSON array")
                    elseif source [index] = ',' then
                        index := index + 1
                    elseif source [index] = ']' then
                        index := index + 1
                        l_done := True
                    else
                        set_error ("Expected comma or closing bracket")
                    end
                end
            end
        end

    parsed_object: detachable TOML_TEST_JSON_VALUE
        local
            l_done: BOOLEAN
            l_key: detachable STRING_32
            l_value: detachable TOML_TEST_JSON_VALUE
        do
            create Result.make_object
            index := index + 1
            skip_whitespace
            if index <= source.count and then source [index] = '}' then
                index := index + 1
            else
                from until l_done or else has_error loop
                    skip_whitespace
                    if index > source.count or else source [index] /= '%"' then
                        set_error ("Expected JSON object key")
                    else
                        l_key := parsed_string
                        skip_whitespace
                        if index > source.count or else source [index] /= ':' then
                            set_error ("Expected colon after JSON object key")
                        else
                            index := index + 1
                            l_value := parsed_value
                            if attached l_key as k and attached l_value as v then
                                if Result.object_value (k) = Void then
                                    Result.put_object (v, k)
                                else
                                    set_error ("Duplicate JSON object key")
                                end
                            end
                        end
                    end
                    skip_whitespace
                    if not has_error then
                        if index > source.count then
                            set_error ("Unterminated JSON object")
                        elseif source [index] = ',' then
                            index := index + 1
                        elseif source [index] = '}' then
                            index := index + 1
                            l_done := True
                        else
                            set_error ("Expected comma or closing brace")
                        end
                    end
                end
            end
        end

    parsed_string: detachable STRING_32
        local
            l_done: BOOLEAN
            l_code, l_low: NATURAL_32
            l_character: CHARACTER_32
        do
            create Result.make_empty
            index := index + 1
            from until l_done or else has_error loop
                if index > source.count then
                    set_error ("Unterminated JSON string")
                else
                    l_character := source [index]
                    index := index + 1
                    if l_character = '%"' then
                        l_done := True
                    elseif l_character = '\' then
                        if index > source.count then
                            set_error ("Unterminated JSON escape")
                        else
                            l_character := source [index]
                            index := index + 1
                            inspect l_character
                            when '%"', '\', '/' then Result.extend (l_character)
                            when 'b' then Result.extend ('%/8/')
                            when 'f' then Result.extend ('%/12/')
                            when 'n' then Result.extend ('%N')
                            when 'r' then Result.extend ('%R')
                            when 't' then Result.extend ('%T')
                            when 'u' then
                                l_code := parsed_hex_quad
                                if not has_error then
                                    if 0xD800 <= l_code and l_code <= 0xDBFF then
                                        if index + 1 <= source.count and then source [index] = '\' and then source [index + 1] = 'u' then
                                            index := index + 2
                                            l_low := parsed_hex_quad
                                            if 0xDC00 <= l_low and l_low <= 0xDFFF then
                                                l_code := 0x10000 + (l_code - 0xD800) * 0x400 + l_low - 0xDC00
                                            else
                                                set_error ("Invalid low surrogate in JSON string")
                                            end
                                        else
                                            set_error ("Missing low surrogate in JSON string")
                                        end
                                    elseif 0xDC00 <= l_code and l_code <= 0xDFFF then
                                        set_error ("Unexpected low surrogate in JSON string")
                                    end
                                    if not has_error then Result.append_code (l_code) end
                                end
                            else set_error ("Invalid JSON escape")
                            end
                        end
                    elseif l_character.code < 32 then
                        set_error ("Control character in JSON string")
                    else
                        Result.extend (l_character)
                    end
                end
            end
        end

    parsed_hex_quad: NATURAL_32
        local
            i, l_digit: INTEGER
        do
            if index + 3 > source.count then
                set_error ("Incomplete Unicode escape")
            else
                from i := 0 until i = 4 or else has_error loop
                    l_digit := hex_value (source [index + i])
                    if l_digit < 0 then
                        set_error ("Invalid Unicode escape")
                    else
                        Result := Result * 16 + l_digit.to_natural_32
                    end
                    i := i + 1
                end
                index := index + 4
            end
        end

feature {NONE} -- Helpers

    skip_whitespace
        do
            from until index > source.count or else not source [index].is_space loop
                index := index + 1
            end
        end

    hex_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then Result := 10 + a_character.code - ('a').code
            elseif 'A' <= a_character and a_character <= 'F' then Result := 10 + a_character.code - ('A').code
            else Result := -1 end
        end

    set_error (a_message: READABLE_STRING_GENERAL)
        do
            if error_message = Void then
                error_message := a_message.as_string_32.twin + " at character " + index.out
            end
        end

    source: STRING_32
    index: INTEGER

end
