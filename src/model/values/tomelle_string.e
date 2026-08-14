note
    description: "Lossless TOML string value."

class
    TOMELLE_STRING

inherit
    TOMELLE_VALUE
        redefine
            is_equal
        end

create
    make,
    make_parsed,
    make_parser_encoded

feature {NONE} -- Initialization

    make (a_value: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value.as_string_32.twin
            raw_text := encoded (value)
        end

    make_parsed (a_value, a_raw_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value.as_string_32.twin
            raw_text := a_raw_text.as_string_32.twin
        end

    make_parser_encoded (a_encoded_value: STRING_32)
            -- Build from the scanner's portable code-point encoding.
        do
            initialize_item
            value := decoded_parser_string (a_encoded_value)
            raw_text := encoded (value)
        end

feature -- Access

    value: STRING_32
    raw_text: STRING_32

    representation: STRING_32
        do
            Result := raw_text.twin
        end

feature -- Element change

    set_value (a_value: READABLE_STRING_GENERAL)
        local
            l_value: STRING_32
        do
            l_value := a_value.as_string_32
            if uses_literal_quotes and then can_use_literal_quotes (l_value) then
                value := l_value.twin
                create raw_text.make (value.count + 2)
                raw_text.extend ('%'')
                raw_text.append (value)
                raw_text.extend ('%'')
            else
                value := l_value.twin
                raw_text := encoded (value)
            end
        ensure
            set: value.same_string_general (a_value)
        end

feature {TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Copying

    cloned_value: TOMELLE_VALUE
        local
            l_result: TOMELLE_STRING
        do
            create l_result.make_parsed (value, raw_text)
            l_result.set_trivia (trivia)
            Result := l_result
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        do
            Result := value.same_string (other.value)
        end

feature {NONE} -- Rendering

    uses_literal_quotes: BOOLEAN
        do
            Result := raw_text.count >= 2 and then raw_text [1] = '%'' and then
                raw_text [raw_text.count] = '%'' and then
                not (raw_text.count >= 6 and then raw_text.substring (1, 3).same_string ("%'%'%'"))
        end

    can_use_literal_quotes (a_text: STRING_32): BOOLEAN
        local
            i: INTEGER
        do
            Result := True
            from i := 1 until i > a_text.count or else not Result loop
                Result := a_text [i] /= '%'' and then a_text [i] /= '%N' and then
                    a_text [i] /= '%R' and then a_text [i].code >= 32 and then a_text [i].code /= 127
                i := i + 1
            end
        end

    decoded_parser_string (a_encoded: STRING_32): STRING_32
        local
            i, j: INTEGER
            l_code: NATURAL_32
        do
            create Result.make (a_encoded.count)
            from i := 1 until i > a_encoded.count loop
                if a_encoded [i] = '~' and then i < a_encoded.count and then a_encoded [i + 1] = '~' then
                    Result.extend ('~')
                    i := i + 2
                elseif a_encoded [i] = '~' and then i + 9 <= a_encoded.count and then a_encoded [i + 9] = '~' then
                    l_code := 0
                    from j := 1 until j > 8 loop
                        l_code := l_code * 16 + hex_value (a_encoded [i + j]).to_natural_32
                        j := j + 1
                    end
                    Result.append_code (l_code)
                    i := i + 10
                else
                    Result.extend (a_encoded [i])
                    i := i + 1
                end
            end
        end

    hex_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then
                Result := a_character.code - ('0').code
            elseif 'A' <= a_character and a_character <= 'F' then
                Result := 10 + a_character.code - ('A').code
            else
                Result := 10 + a_character.code - ('a').code
            end
        end

    encoded (a_text: STRING_32): STRING_32
        local
            i: INTEGER
        do
            create Result.make (a_text.count + 2)
            Result.extend ('%"')
            from i := 1 until i > a_text.count loop
                inspect a_text [i]
                when '%"' then Result.append ("\%"")
                when '\' then Result.append ("\\")
                when '%N' then Result.append ("\n")
                when '%R' then Result.append ("\r")
                when '%T' then Result.append ("\t")
                when '%B' then Result.append ("\b")
                when '%F' then Result.append ("\f")
                else Result.extend (a_text [i])
                end
                i := i + 1
            end
            Result.extend ('%"')
        end

end
