note
    description: "toml-test decoder command for Tomelle."

class
    TOML_TEST_DECODER

create
    make

feature {NONE} -- Entry point

    make
        local
            l_parser: TOMELLE_PARSER
            l_parse_result: TOMELLE_PARSE_RESULT
            l_io: TOML_TEST_IO
            l_exceptions: EXCEPTIONS
        do
            create l_io
            if attached l_io.decoded_utf_8 (l_io.stdin_bytes) as l_source then
                create l_parser.make
                l_parse_result := l_parser.parsed_string (l_source)
                if attached l_parse_result.document as l_document then
                    l_io.write_stdout (serialized_table (l_document.root))
                    l_io.write_stdout ("%N")
                else
                    if l_parse_result.error_count > 0 then l_io.write_stderr (l_parse_result.error (1).message)
                    else l_io.write_stderr ("Unable to parse TOML") end
                    create l_exceptions
                    l_exceptions.die (1)
                end
            else
                l_io.write_stderr ("Input is not valid UTF-8")
                create l_exceptions
                l_exceptions.die (1)
            end
        end

feature {NONE} -- Tagged JSON

    serialized_table (a_table: TOMELLE_TABLE): STRING_32
        local l_first: BOOLEAN
        do
            create Result.make_from_string ("{")
            l_first := True
            across a_table.keys as l_key loop
                if l_first then l_first := False else Result.extend (',') end
                Result.append (json_string (l_key))
                Result.extend (':')
                check attached a_table [l_key] as l_value then Result.append (serialized_value (l_value)) end
            end
            Result.extend ('}')
        end

    serialized_array (a_array: TOMELLE_ARRAY): STRING_32
        local i: INTEGER
        do
            create Result.make_from_string ("[")
            from i := 1 until i > a_array.count loop
                if i > 1 then Result.extend (',') end
                Result.append (serialized_value (a_array [i]))
                i := i + 1
            end
            Result.extend (']')
        end

    serialized_value (a_value: TOMELLE_VALUE): STRING_32
        local
            l_type, l_text: STRING_32
            l_date_time: TOMELLE_LOCAL_DATE_TIME
        do
            if attached {TOMELLE_TABLE} a_value as l_table then
                Result := serialized_table (l_table)
            elseif attached {TOMELLE_ARRAY} a_value as l_array then
                Result := serialized_array (l_array)
            elseif attached {TOMELLE_STRING} a_value as l_string then
                Result := "{%"type%":%"string%",%"value%":" + json_string (l_string.value) + "}"
            else
                if attached {TOMELLE_INTEGER} a_value as l_integer then
                    l_type := "integer"
                    l_text := l_integer.value.out
                elseif attached {TOMELLE_FLOAT} a_value as l_float then
                    l_type := "float"
                    l_text := l_float.canonical_text.twin
                elseif attached {TOMELLE_BOOLEAN} a_value as l_boolean then
                    l_type := "bool"
                    if l_boolean.value then l_text := "true" else l_text := "false" end
                elseif attached {TOMELLE_LOCAL_DATE_VALUE} a_value as l_date then
                    l_type := "date-local"
                    l_text := date_text (l_date.value)
                elseif attached {TOMELLE_LOCAL_TIME_VALUE} a_value as l_time then
                    l_type := "time-local"
                    l_text := time_text (l_time.value)
                elseif attached {TOMELLE_LOCAL_DATE_TIME_VALUE} a_value as l_local_date_time then
                    l_type := "datetime-local"
                    l_date_time := l_local_date_time.value
                    l_text := date_text (l_date_time.date) + "T" + time_text (l_date_time.time)
                else
                    l_type := "datetime"
                    check attached {TOMELLE_OFFSET_DATE_TIME_VALUE} a_value as l_offset then
                        l_date_time := l_offset.value.local_date_time
                        l_text := date_text (l_date_time.date) + "T" + time_text (l_date_time.time) +
                            offset_text (l_offset.value.offset_minutes)
                    end
                end
                Result := "{%"type%":" + json_string (l_type) + ",%"value%":" + json_string (l_text) + "}"
            end
        end

    json_string (a_text: READABLE_STRING_GENERAL): STRING_32
        local
            l_text: STRING_32
            i: INTEGER
            l_code: NATURAL_32
        do
            if attached {STRING_32} a_text as l_exact then l_text := l_exact
            else l_text := a_text.as_string_32 end
            create Result.make (l_text.count + 2)
            Result.extend ('%"')
            from i := 1 until i > l_text.count loop
                inspect l_text [i]
                when '%"' then Result.append ("\%"")
                when '\' then Result.append ("\\")
                when '%/8/' then Result.append ("\b")
                when '%/12/' then Result.append ("\f")
                when '%N' then Result.append ("\n")
                when '%R' then Result.append ("\r")
                when '%T' then Result.append ("\t")
                else
                    l_code := l_text [i].code.to_natural_32
                    if l_code < 32 then
                        Result.append ("\u00")
                        Result.extend (hex_digit ((l_code // 16).to_integer_32))
                        Result.extend (hex_digit ((l_code \\ 16).to_integer_32))
                    elseif l_code > 126 then
                        append_json_unicode_escape (Result, l_code)
                    else Result.extend (l_text [i]) end
                end
                i := i + 1
            end
            Result.extend ('%"')
        end

    append_json_unicode_escape (a_target: STRING_32; a_code: NATURAL_32)
        local
            l_high, l_low: NATURAL_32
        do
            if a_code <= 0xFFFF then
                a_target.append ("\u")
                append_hex_quad (a_target, a_code)
            else
                l_high := 0xD800 + ((a_code - 0x10000) |>> 10)
                l_low := 0xDC00 + ((a_code - 0x10000) & 0x3FF)
                a_target.append ("\u")
                append_hex_quad (a_target, l_high)
                a_target.append ("\u")
                append_hex_quad (a_target, l_low)
            end
        end

    append_hex_quad (a_target: STRING_32; a_code: NATURAL_32)
        local l_shift: INTEGER
        do
            from l_shift := 12 until l_shift < 0 loop
                a_target.extend (hex_digit (((a_code |>> l_shift) & 15).to_integer_32))
                l_shift := l_shift - 4
            end
        end

    float_text (a_value: REAL_64): STRING_32
        do
            if a_value.is_nan then Result := "nan"
            elseif a_value.is_positive_infinity then Result := "inf"
            elseif a_value.is_negative_infinity then Result := "-inf"
            else Result := a_value.out end
        end

    date_text (a_date: TOMELLE_LOCAL_DATE): STRING_32
        do
            Result := padded (a_date.year, 4) + "-" + padded (a_date.month, 2) + "-" + padded (a_date.day, 2)
        end

    time_text (a_time: TOMELLE_LOCAL_TIME): STRING_32
        do
            Result := padded (a_time.hour, 2) + ":" + padded (a_time.minute, 2) + ":" + padded (a_time.second, 2)
            if a_time.fractional_digit_count > 0 then
                Result.extend ('.')
                Result.append (padded (a_time.nanosecond, 9).substring (1, a_time.fractional_digit_count))
            end
        end

    offset_text (a_offset_minutes: INTEGER): STRING_32
        local l_absolute: INTEGER
        do
            if a_offset_minutes = 0 then Result := "Z"
            else
                l_absolute := a_offset_minutes.abs
                if a_offset_minutes < 0 then Result := "-" else Result := "+" end
                Result.append (padded (l_absolute // 60, 2))
                Result.extend (':')
                Result.append (padded (l_absolute \\ 60, 2))
            end
        end

    padded (a_value, a_width: INTEGER): STRING_32
        do
            Result := a_value.out
            from until Result.count >= a_width loop Result.prepend_character ('0') end
        end

    hex_digit (a_value: INTEGER): CHARACTER_32
        require valid: 0 <= a_value and a_value <= 15
        do
            if a_value < 10 then Result := (('0').code + a_value).to_character_32
            else Result := (('A').code + a_value - 10).to_character_32 end
        end

end
