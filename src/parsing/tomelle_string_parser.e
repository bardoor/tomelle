note
    description: "Parses and decodes TOML basic, literal, and multiline strings."

class
    TOMELLE_STRING_PARSER

create
    make

feature {NONE} -- Initialization

    make do create value_factory.make end

feature -- Parsing

    parse (a_source: STRING_32): detachable TOMELLE_VALUE
        local l_text, l_inner: STRING_32
        do
            l_text := lexical.trimmed (a_source)
            if l_text.count >= 6 and then l_text.substring (1, 3).same_string ("%"%"%"") and then
                l_text.substring (l_text.count - 2, l_text.count).same_string ("%"%"%"")
            then
                l_inner := lexical.substring (l_text, 4, l_text.count - 3)
                if not l_inner.is_empty and then l_inner [1] = '%N' then l_inner.remove (1) end
                if is_valid_basic_string (l_inner, True) then
                    Result := value_factory.new_parser_string (parser_encoded_string (decoded_basic_string (l_inner)))
                end
            elseif l_text.count >= 6 and then l_text.substring (1, 3).same_string ("%'%'%'") and then
                l_text.substring (l_text.count - 2, l_text.count).same_string ("%'%'%'")
            then
                l_inner := lexical.substring (l_text, 4, l_text.count - 3)
                if not l_inner.is_empty and then l_inner [1] = '%N' then l_inner.remove (1) end
                if is_valid_literal_string (l_inner, True) then
                    Result := value_factory.new_parser_string (parser_encoded_string (l_inner))
                end
            elseif l_text.count >= 2 and then l_text [1] = '%"' and then l_text [l_text.count] = '%"' then
                l_inner := lexical.substring (l_text, 2, l_text.count - 1)
                if is_valid_basic_string (l_inner, False) then
                    Result := value_factory.new_parser_string (parser_encoded_string (decoded_basic_string (l_inner)))
                end
            elseif l_text.count >= 2 and then l_text [1] = '%'' and then l_text [l_text.count] = '%'' then
                l_inner := lexical.substring (l_text, 2, l_text.count - 1)
                if is_valid_literal_string (l_inner, False) then
                    Result := value_factory.new_parser_string (parser_encoded_string (l_inner))
                end
            end
        end

feature -- Validation

    is_valid_basic_string (a_text: STRING_32; a_multiline: BOOLEAN): BOOLEAN
        local
            i, j, k, l_digits, l_quote_run: INTEGER
            l_code: NATURAL_64
            c: CHARACTER_32
        do
            Result := True
            from i := 1 until i > a_text.count or else not Result loop
                c := a_text [i]
                if c = '\' then
                    i := i + 1
                    Result := i <= a_text.count
                    if Result then
                        c := a_text [i]
                        k := i
                        from until k > a_text.count or else (a_text [k] /= ' ' and a_text [k] /= '%T') loop k := k + 1 end
                        if a_multiline and then k <= a_text.count and then (a_text [k] = '%N' or a_text [k] = '%R') then
                            i := k
                        else
                            Result := c = 'b' or c = 't' or c = 'n' or c = 'f' or c = 'r' or c = 'e' or
                                c = '%"' or c = '\' or c = 'x' or c = 'u' or c = 'U'
                            if Result and then (c = 'x' or c = 'u' or c = 'U') then
                                if c = 'x' then l_digits := 2 elseif c = 'u' then l_digits := 4 else l_digits := 8 end
                                Result := i + l_digits <= a_text.count
                                from j := i + 1 until j > i + l_digits or else not Result loop
                                    Result := a_text [j].is_hexa_digit
                                    j := j + 1
                                end
                                if Result then
                                    l_code := 0
                                    from j := 1 until j > l_digits loop
                                        l_code := l_code * 16 + digit_value (a_text [i + j]).to_natural_64
                                        j := j + 1
                                    end
                                    Result := l_code <= 0x10FFFF and then not (0xD800 <= l_code and l_code <= 0xDFFF)
                                end
                                i := i + l_digits
                            end
                        end
                    end
                elseif c = '%"' then
                    Result := a_multiline
                    if Result then
                        from l_quote_run := 0 until i + l_quote_run > a_text.count or else a_text [i + l_quote_run] /= '%"' loop
                            l_quote_run := l_quote_run + 1
                        end
                        Result := l_quote_run <= 2
                        i := i + l_quote_run - 1
                    end
                elseif c = '%N' or c = '%R' then Result := a_multiline
                elseif c.code < 32 and c /= '%T' or else c.code = 127 then Result := False end
                i := i + 1
            end
        end

    is_valid_literal_string (a_text: STRING_32; a_multiline: BOOLEAN): BOOLEAN
        local i, l_quote_run: INTEGER; c: CHARACTER_32
        do
            Result := True
            from i := 1 until i > a_text.count or else not Result loop
                c := a_text [i]
                if c = '%'' then
                    Result := a_multiline
                    if Result then
                        from l_quote_run := 0 until i + l_quote_run > a_text.count or else a_text [i + l_quote_run] /= '%'' loop
                            l_quote_run := l_quote_run + 1
                        end
                        Result := l_quote_run <= 2
                        i := i + l_quote_run - 1
                    end
                elseif c = '%N' or c = '%R' then Result := a_multiline
                elseif c.code < 32 and c /= '%T' or else c.code = 127 then Result := False end
                i := i + 1
            end
        end

feature {NONE} -- Decoding

    decoded_basic_string (a_text: STRING_32): STRING_32
        local
            i, j, k, l_digits: INTEGER
            l_code: NATURAL_64
        do
            create Result.make (a_text.count)
            from i := 1 until i > a_text.count loop
                if a_text [i] = '\' and then i < a_text.count then
                    i := i + 1
                    k := i
                    from until k > a_text.count or else (a_text [k] /= ' ' and a_text [k] /= '%T') loop k := k + 1 end
                    if k <= a_text.count and then (a_text [k] = '%N' or a_text [k] = '%R') then
                        i := k + 1
                        if a_text [k] = '%R' and then i <= a_text.count and then a_text [i] = '%N' then i := i + 1 end
                        from until i > a_text.count or else not a_text [i].is_space loop i := i + 1 end
                        i := i - 1
                    else
                        inspect a_text [i]
                        when 'n' then Result.extend ('%N')
                        when 'r' then Result.extend ('%R')
                        when 't' then Result.extend ('%T')
                        when 'b' then Result.extend ('%B')
                        when 'f' then Result.extend ('%F')
                        when 'e' then Result.extend ((27).to_character_32)
                        when 'x', 'u', 'U' then
                            if a_text [i] = 'x' then l_digits := 2 elseif a_text [i] = 'u' then l_digits := 4 else l_digits := 8 end
                            l_code := 0
                            from j := 1 until j > l_digits loop
                                l_code := l_code * 16 + digit_value (a_text [i + j]).to_natural_64
                                j := j + 1
                            end
                            if l_code > 255 then append_code_marker (Result, l_code.to_natural_32)
                            elseif l_code = ('~').code.to_natural_64 then Result.append ("~~")
                            else Result.append_code (l_code.to_natural_32) end
                            i := i + l_digits
                        else Result.extend (a_text [i]) end
                    end
                else Result.extend (a_text [i]) end
                i := i + 1
            end
        end

    parser_encoded_string (a_value: STRING_32): STRING_32
        local i, l_shift: INTEGER; l_code: NATURAL_32
        do
            create Result.make (a_value.count)
            from i := 1 until i > a_value.count loop
                l_code := a_value.code (i)
                if a_value [i] = '~' and then is_code_marker_at (a_value, i) then
                    Result.append (a_value.substring (i, i + 9)); i := i + 9
                elseif a_value [i] = '~' and then i < a_value.count and then a_value [i + 1] = '~' then
                    Result.append ("~~"); i := i + 1
                elseif a_value [i] = '~' then Result.append ("~~")
                elseif l_code > 255 then
                    Result.extend ('~')
                    from l_shift := 28 until l_shift < 0 loop
                        Result.extend (hex_digit (((l_code |>> l_shift) & 15).to_integer_32)); l_shift := l_shift - 4
                    end
                    Result.extend ('~')
                else Result.extend (a_value [i]) end
                i := i + 1
            end
        end

    append_code_marker (a_target: STRING_32; a_code: NATURAL_32)
        local l_shift: INTEGER
        do
            a_target.extend ('~')
            from l_shift := 28 until l_shift < 0 loop
                a_target.extend (hex_digit (((a_code |>> l_shift) & 15).to_integer_32)); l_shift := l_shift - 4
            end
            a_target.extend ('~')
        end

    is_code_marker_at (a_text: STRING_32; a_index: INTEGER): BOOLEAN
        local i: INTEGER
        do
            Result := a_index + 9 <= a_text.count and then a_text [a_index + 9] = '~'
            from i := a_index + 1 until i > a_index + 8 or else not Result loop Result := a_text [i].is_hexa_digit; i := i + 1 end
        end

    digit_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then Result := 10 + a_character.code - ('a').code
            elseif 'A' <= a_character and a_character <= 'F' then Result := 10 + a_character.code - ('A').code
            else Result := 99 end
        end

    hex_digit (a_value: INTEGER): CHARACTER_32
        do
            if a_value < 10 then Result := (('0').code + a_value).to_character_32
            else Result := (('A').code + a_value - 10).to_character_32 end
        end

    lexical: TOMELLE_LEXICAL_TOOLS once create Result end
    value_factory: TOMELLE_VALUE_FACTORY

end
