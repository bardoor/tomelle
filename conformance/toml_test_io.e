note
    description: "UTF-8 and standard-stream support shared by toml-test adapters."

class
    TOML_TEST_IO

feature -- Input

    stdin_bytes: STRING_8
        local
            l_input: PLAIN_TEXT_FILE
        do
            create Result.make (4096)
            l_input := streams.input
            from until l_input.end_of_file loop
                l_input.read_stream (4096)
                Result.append (l_input.last_string)
            end
        end

    decoded_utf_8 (a_bytes: STRING_8): detachable STRING_32
        do
            if is_valid_utf_8 (a_bytes) then
                Result := {UTF_CONVERTER}.utf_8_string_8_to_string_32 (a_bytes)
            end
        end

feature -- Output

    encoded_utf_8 (a_text: READABLE_STRING_GENERAL): STRING_8
        do
            Result := {UTF_CONVERTER}.string_32_to_utf_8_string_8 (a_text.as_string_32)
        end

    write_stdout (a_text: READABLE_STRING_GENERAL)
        do
            streams.output.put_string (encoded_utf_8 (a_text))
        end

    write_stderr (a_text: READABLE_STRING_GENERAL)
        do
            streams.error.put_string (encoded_utf_8 (a_text))
            streams.error.put_new_line
        end

feature {NONE} -- Streams

    is_valid_utf_8 (a_bytes: STRING_8): BOOLEAN
            -- Does `a_bytes` contain only well-formed Unicode scalar values?
        local
            i, l_count, l_first, l_second: INTEGER
        do
            Result := True
            l_count := a_bytes.count
            from i := 1 until i > l_count or else not Result loop
                l_first := a_bytes [i].code
                if l_first <= 0x7F then
                    i := i + 1
                elseif l_first >= 0xC2 and l_first <= 0xDF then
                    Result := i + 1 <= l_count and then is_continuation_byte (a_bytes [i + 1].code)
                    i := i + 2
                elseif l_first >= 0xE0 and l_first <= 0xEF then
                    if i + 2 <= l_count then
                        l_second := a_bytes [i + 1].code
                        Result := is_continuation_byte (a_bytes [i + 2].code) and then
                            ((l_first = 0xE0 and l_second >= 0xA0 and l_second <= 0xBF) or else
                             (l_first = 0xED and l_second >= 0x80 and l_second <= 0x9F) or else
                             (l_first /= 0xE0 and l_first /= 0xED and is_continuation_byte (l_second)))
                    else
                        Result := False
                    end
                    i := i + 3
                elseif l_first >= 0xF0 and l_first <= 0xF4 then
                    if i + 3 <= l_count then
                        l_second := a_bytes [i + 1].code
                        Result := is_continuation_byte (a_bytes [i + 2].code) and then
                            is_continuation_byte (a_bytes [i + 3].code) and then
                            ((l_first = 0xF0 and l_second >= 0x90 and l_second <= 0xBF) or else
                             (l_first = 0xF4 and l_second >= 0x80 and l_second <= 0x8F) or else
                             (l_first > 0xF0 and l_first < 0xF4 and is_continuation_byte (l_second)))
                    else
                        Result := False
                    end
                    i := i + 4
                else
                    Result := False
                end
            end
        end

    is_continuation_byte (a_byte: INTEGER): BOOLEAN
        do
            Result := a_byte >= 0x80 and a_byte <= 0xBF
        end

    streams: STD_FILES
        once
            create Result
        end

end
