note
    description: "Deterministic TOML text and UTF-8 file serializer."

class
    TOMELLE_WRITER

create
    make

feature {NONE} -- Initialization

    make
        do
            reset
        end

feature -- Serialization

    serialized (a_document: TOMELLE_DOCUMENT): STRING_32
        local l_value: TOMELLE_VALUE
        do
            create Result.make_empty
            across a_document.root.keys as l_key loop
                check attached a_document.root [l_key] as v then
                    l_value := v
                end
                Result.append (serialized_key (l_key))
                Result.append (" = ")
                Result.append (serialized_value (l_value))
                Result.extend ('%N')
            end
        end

    write_file (a_document: TOMELLE_DOCUMENT; a_path: PATH)
        require
            path_not_empty: not a_path.is_empty
        local
            l_file: RAW_FILE
            l_started, l_failed: BOOLEAN
            l_code: TOMELLE_ERROR_CODE
        do
            reset
            is_written := True
            if l_failed then
                if l_started then
                    l_code := error_codes.output_interrupted
                else
                    l_code := error_codes.output_unwritable
                end
                create error.make (l_code,
                    "Unable to write TOML output", a_path.name)
            else
                create l_file.make_open_temporary_with_prefix (
                    a_path.name.as_string_32 + ".tomelle.")
                l_started := True
                l_file.put_string (encoded_utf_8 (serialized (a_document)))
                l_file.close
                l_file.rename_path (a_path)
            end
        rescue
            if l_started and then attached l_file as l_opened_file then
                if not l_opened_file.is_closed then
                    l_opened_file.close
                end
                if l_opened_file.exists then
                    l_opened_file.delete
                end
            end
            l_failed := True
            retry
        end

    reset
        do
            is_written := False
            error := Void
        end

feature -- Status report

    is_written: BOOLEAN
    is_successful: BOOLEAN
        do
            Result := is_written and then error = Void
        end

feature -- Error

    error: detachable TOMELLE_WRITE_ERROR

feature {NONE} -- Serialization implementation

    serialized_value (a_value: TOMELLE_VALUE): STRING_32
        local
            l_date: TOMELLE_LOCAL_DATE
            l_time: TOMELLE_LOCAL_TIME
            l_date_time: TOMELLE_LOCAL_DATE_TIME
            l_offset: TOMELLE_OFFSET_DATE_TIME
            l_float: REAL_64
        do
            if a_value.is_string then
                Result := serialized_string (a_value.as_string)
            elseif a_value.is_integer then
                Result := a_value.as_integer.out
            elseif a_value.is_float then
                l_float := a_value.as_float
                if l_float.is_nan then Result := "nan"
                elseif l_float.is_positive_infinity then Result := "inf"
                elseif l_float.is_negative_infinity then Result := "-inf"
                else
                    Result := a_value.as_float_text.as_string_32
                end
            elseif a_value.is_boolean then
                if a_value.as_boolean then
                    Result := "true"
                else
                    Result := "false"
                end
            elseif a_value.is_local_date then
                l_date := a_value.as_local_date
                Result := serialized_date (l_date)
            elseif a_value.is_local_time then
                l_time := a_value.as_local_time
                Result := serialized_time (l_time)
            elseif a_value.is_local_date_time then
                l_date_time := a_value.as_local_date_time
                Result := serialized_date (l_date_time.date) + "T" + serialized_time (l_date_time.time)
            elseif a_value.is_offset_date_time then
                l_offset := a_value.as_offset_date_time
                l_date_time := l_offset.local_date_time
                Result := serialized_date (l_date_time.date) + "T" + serialized_time (l_date_time.time)
                if l_offset.is_utc then Result.extend ('Z')
                elseif l_offset.offset_minutes < 0 then
                    Result.extend ('-')
                    Result.append (padded (-(l_offset.offset_minutes) // 60, 2))
                    Result.extend (':')
                    Result.append (padded (-(l_offset.offset_minutes) \\ 60, 2))
                else
                    Result.extend ('+')
                    Result.append (padded (l_offset.offset_minutes // 60, 2))
                    Result.extend (':')
                    Result.append (padded (l_offset.offset_minutes \\ 60, 2))
                end
            elseif a_value.is_array then
                Result := serialized_array (a_value.as_array)
            else
                Result := serialized_table (a_value.as_table)
            end
        end

    serialized_array (a_array: TOMELLE_ARRAY): STRING_32
        local i: INTEGER
        do
            create Result.make_from_string ("[")
            from i := 1 until i > a_array.count loop
                if i > 1 then
                    Result.append (", ")
                end
                Result.append (serialized_value (a_array [i]))
                i := i + 1
            end
            Result.extend (']')
        end

    serialized_table (a_table: TOMELLE_TABLE): STRING_32
        local l_first: BOOLEAN
        do
            create Result.make_from_string ("{")
            l_first := True
            across a_table.keys as l_key loop
                if l_first then
                    l_first := False
                else
                    Result.append (", ")
                end
                Result.append (serialized_key (l_key))
                Result.append (" = ")
                check attached a_table [l_key] as v then
                    Result.append (serialized_value (v))
                end
            end
            Result.extend ('}')
        end

    serialized_key (a_key: READABLE_STRING_GENERAL): STRING_32
        local
            l_text: STRING_32
            i: INTEGER
            l_bare: BOOLEAN
        do
            l_text := a_key.as_string_32
            l_bare := not l_text.is_empty
            from i := 1 until i > l_text.count or else not l_bare loop
                l_bare := ('a' <= l_text [i] and l_text [i] <= 'z') or ('A' <= l_text [i] and l_text [i] <= 'Z') or
                    ('0' <= l_text [i] and l_text [i] <= '9') or l_text [i] = '-' or l_text [i] = '_'
                i := i + 1
            end
            if l_bare then
                Result := l_text.twin
            else
                Result := serialized_string (l_text)
            end
        end

    serialized_string (a_text: READABLE_STRING_GENERAL): STRING_32
        local
            l_text: STRING_32
            i: INTEGER
        do
            l_text := a_text.as_string_32
            create Result.make (l_text.count + 2)
            Result.extend ('%"')
            from i := 1 until i > l_text.count loop
                inspect l_text [i]
                when '%"' then Result.append ("\%"")
                when '\' then Result.append ("\\")
                when '%N' then Result.append ("\n")
                when '%R' then Result.append ("\r")
                when '%T' then Result.append ("\t")
                else
                    if l_text [i].code < 32 or else l_text [i].code = 127 then
                        Result.append ("\u00")
                        Result.extend (hex_digit ((l_text [i].code // 16).to_integer_32))
                        Result.extend (hex_digit ((l_text [i].code \\ 16).to_integer_32))
                    else
                        Result.extend (l_text [i])
                    end
                end
                i := i + 1
            end
            Result.extend ('%"')
        end

    serialized_date (a_date: TOMELLE_LOCAL_DATE): STRING_32
        do
            Result := padded (a_date.year, 4) + "-" + padded (a_date.month, 2) + "-" + padded (a_date.day, 2)
        end

    serialized_time (a_time: TOMELLE_LOCAL_TIME): STRING_32
        local l_fraction: STRING_32
        do
            Result := padded (a_time.hour, 2) + ":" + padded (a_time.minute, 2) + ":" + padded (a_time.second, 2)
            if a_time.fractional_digit_count > 0 then
                l_fraction := padded (a_time.nanosecond, 9).substring (1, a_time.fractional_digit_count)
                Result.extend ('.')
                Result.append (l_fraction)
            end
        end

    padded (a_value, a_width: INTEGER): STRING_32
        do
            Result := a_value.out
            from
            until
                Result.count >= a_width
            loop
                Result.prepend_character ('0')
            end
        end

    hex_digit (a_value: INTEGER): CHARACTER_32
        require valid_value: 0 <= a_value and a_value <= 15
        do
            if a_value <= 9 then
                Result := (('0').code + a_value).to_character_32
            else
                Result := (('A').code + a_value - 10).to_character_32
            end
        end

feature {NONE} -- UTF-8

    encoded_utf_8 (a_text: STRING_32): STRING_8
        do
            Result := {UTF_CONVERTER}.string_32_to_utf_8_string_8 (a_text)
        end

    error_codes: TOMELLE_ERROR_CODE
        once
            create Result.default_create
        end

invariant
    not_written_has_no_error: not is_written implies error = Void
    failed_has_error: is_written and then not is_successful implies attached error

end
