note
    description: "Immutable sequence of literal TOML keys."

class
    TOMELLE_PATH

create
    make,
    make_from_key,
    make_from_key_expression

feature {NONE} -- Initialization

    make (a_keys: ITERABLE [READABLE_STRING_GENERAL])
        do
            create internal_keys.make (0)
            across a_keys as l_key loop
                internal_keys.extend (l_key.as_string_32.twin)
            end
        end

    make_from_key (a_key: READABLE_STRING_GENERAL)
        do
            create internal_keys.make (1)
            internal_keys.extend (a_key.as_string_32.twin)
        ensure
            one_component: count = 1
            key_preserved: item (1).same_string_general (a_key)
        end

    make_from_key_expression (a_key_expression: READABLE_STRING_GENERAL)
        require
            valid_expression: key_syntax.is_valid_expression (a_key_expression)
        do
            create internal_keys.make (1)
            parse_expression (a_key_expression.as_string_32)
        ensure
            not_empty: count > 0
        end

feature -- Access

    item alias "[]" (a_index: INTEGER): READABLE_STRING_32
        require
            valid_index: 1 <= a_index and a_index <= count
        do
            Result := internal_keys [a_index]
        end

    keys: ITERABLE [READABLE_STRING_32]
        do
            Result := internal_keys
        end

feature -- Measurement

    count: INTEGER
        do
            Result := internal_keys.count
        ensure
            non_negative: Result >= 0
        end

feature -- Element change

    extended (a_key: READABLE_STRING_GENERAL): TOMELLE_PATH
        local
            l_keys: ARRAYED_LIST [READABLE_STRING_GENERAL]
        do
            create l_keys.make (count + 1)
            across internal_keys as l_key loop
                l_keys.extend (l_key)
            end
            l_keys.extend (a_key)
            create Result.make (l_keys)
        ensure
            new_object: Result /= Current
            one_more: Result.count = count + 1
            appended: Result.item (Result.count).same_string_general (a_key)
        end

feature {NONE} -- Implementation

    internal_keys: ARRAYED_LIST [STRING_32]

    key_syntax: TOMELLE_KEY_SYNTAX
        once
            create Result.make
        end

    parse_expression (a_expression: STRING_32)
        local
            i, n: INTEGER
            l_key: STRING_32
            l_quote, l_character: CHARACTER_32
            l_digits, j, l_code: INTEGER
        do
            n := a_expression.count
            from i := 1 until i > n loop
                from until i > n or else not a_expression [i].is_space loop
                    i := i + 1
                end
                create l_key.make_empty
                if a_expression [i] = '%"' or else a_expression [i] = '%'' then
                    l_quote := a_expression [i]
                    from i := i + 1 until a_expression [i] = l_quote loop
                        l_character := a_expression [i]
                        if l_quote = '%"' and then l_character = '\' then
                            i := i + 1
                            inspect a_expression [i]
                            when 'b' then l_key.extend ('%B')
                            when 't' then l_key.extend ('%T')
                            when 'n' then l_key.extend ('%N')
                            when 'f' then l_key.extend ('%F')
                            when 'r' then l_key.extend ('%R')
                            when 'u', 'U' then
                                if a_expression [i] = 'u' then l_digits := 4 else l_digits := 8 end
                                l_code := 0
                                from j := 1 until j > l_digits loop
                                    l_code := l_code * 16 + hex_value (a_expression [i + j])
                                    j := j + 1
                                end
                                l_key.append_code (l_code.to_natural_32)
                                i := i + l_digits
                            else l_key.extend (a_expression [i])
                            end
                        else
                            l_key.extend (l_character)
                        end
                        i := i + 1
                    end
                    i := i + 1
                else
                    from until i > n or else not key_syntax.is_bare_key_character (a_expression [i]) loop
                        l_key.extend (a_expression [i])
                        i := i + 1
                    end
                end
                internal_keys.extend (l_key)
                from until i > n or else not a_expression [i].is_space loop
                    i := i + 1
                end
                if i <= n then
                    i := i + 1
                end
            end
    end

    hex_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then Result := 10 + a_character.code - ('a').code
            else Result := 10 + a_character.code - ('A').code end
        end

end
