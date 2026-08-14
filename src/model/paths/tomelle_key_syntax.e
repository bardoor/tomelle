note
    description: "Validator for TOML dotted-key expressions."

class
    TOMELLE_KEY_SYNTAX

create
    make

feature {NONE} -- Initialization

    make
        do
        end

feature -- Validation

    is_valid_expression (a_expression: READABLE_STRING_GENERAL): BOOLEAN
            -- Is `a_expression` a valid TOML dotted-key expression?
        local
            l_text: STRING_32
            i, n: INTEGER
            l_expect_key, l_valid: BOOLEAN
            l_quote: CHARACTER_32
            l_digits, j: INTEGER
            l_code: NATURAL_64
        do
            l_text := a_expression.as_string_32
            n := l_text.count
            l_expect_key := True
            l_valid := n > 0
            from i := 1 until i > n or else not l_valid loop
                from until i > n or else not l_text [i].is_space loop
                    i := i + 1
                end
                if i > n then
                    l_valid := not l_expect_key
                elseif l_expect_key then
                    if l_text [i] = '%"' or else l_text [i] = '%'' then
                        l_quote := l_text [i]
                        i := i + 1
                        from until i > n or else l_text [i] = l_quote or else not l_valid loop
                            if l_quote = '%"' and then l_text [i] = '\' then
                                i := i + 1
                                l_valid := i <= n and then is_valid_escape (l_text [i])
                                if l_valid and then (l_text [i] = 'u' or else l_text [i] = 'U') then
                                    if l_text [i] = 'u' then l_digits := 4 else l_digits := 8 end
                                    l_valid := i + l_digits <= n
                                    from j := i + 1 until j > i + l_digits or else not l_valid loop
                                        l_valid := syntax_rules.is_hex_character (l_text [j])
                                        j := j + 1
                                    end
                                    if l_valid then
                                        l_code := 0
                                        from j := 1 until j > l_digits loop
                                            l_code := l_code * 16 + syntax_rules.hex_value (l_text [i + j]).to_natural_64
                                            j := j + 1
                                        end
                                        l_valid := syntax_rules.is_unicode_scalar (l_code)
                                    end
                                    i := i + l_digits
                                end
                            end
                            i := i + 1
                        end
                        l_valid := l_valid and then i <= n and then l_text [i] = l_quote
                        i := i + 1
                    else
                        l_valid := syntax_rules.is_bare_key_character (l_text [i])
                        from until i > n or else not syntax_rules.is_bare_key_character (l_text [i]) loop
                            i := i + 1
                        end
                    end
                    l_expect_key := False
                elseif l_text [i] = '.' then
                    l_expect_key := True
                    i := i + 1
                else
                    l_valid := False
                end
            end
            Result := l_valid and then not l_expect_key
        end

feature {TOMELLE_PATH} -- Implementation

    is_bare_key_character (a_character: CHARACTER_32): BOOLEAN
        do
            Result := syntax_rules.is_bare_key_character (a_character)
        end

    is_valid_escape (a_character: CHARACTER_32): BOOLEAN
        do
            Result := a_character = 'b' or else a_character = 't' or else
                a_character = 'n' or else a_character = 'f' or else
                a_character = 'r' or else a_character = '%"' or else
                a_character = '\' or else a_character = 'u' or else a_character = 'U'
        end

    is_hex_character (a_character: CHARACTER_32): BOOLEAN
        do
            Result := syntax_rules.is_hex_character (a_character)
        end

    syntax_rules: TOMELLE_SYNTAX_RULES
        once
            create Result
        end

end
