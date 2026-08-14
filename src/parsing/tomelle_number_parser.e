note
    description: "Parses TOML integer and floating-point values."

class
    TOMELLE_NUMBER_PARSER

create
    make

feature {NONE} -- Initialization

    make
        do
            create value_factory.make
        end

feature -- Parsing

    parse (a_source: STRING_32): detachable TOMELLE_VALUE
        local l_text: STRING_32
        do
            l_text := a_source.twin
            if valid_numeric_underscores (l_text) then
                l_text.replace_substring_all ("_", "")
                if l_text.same_string ("inf") or l_text.same_string ("+inf") then
                    Result := value_factory.new_float ((0.0).positive_infinity)
                elseif l_text.same_string ("-inf") then
                    Result := value_factory.new_float ((0.0).negative_infinity)
                elseif l_text.same_string ("nan") or l_text.same_string ("+nan") then
                    Result := value_factory.new_float ((0.0).nan)
                elseif l_text.same_string ("-nan") then
                    Result := value_factory.new_float (-(0.0).nan)
                elseif is_based_integer (l_text) and then is_based_integer_in_range (l_text) then
                    Result := value_factory.new_integer (based_integer (l_text))
                elseif is_decimal_integer (l_text) and then l_text.is_integer_64 then
                    Result := value_factory.new_integer (l_text.to_integer_64)
                elseif is_decimal_float (l_text) and then l_text.is_real_64 then
                    Result := value_factory.new_float_from_text (l_text)
                end
            end
        end

feature -- Validation

    valid_numeric_underscores (a_text: STRING_32): BOOLEAN
        local
            i, l_prefix_end, l_base: INTEGER
        do
            Result := not a_text.is_empty and then a_text [1] /= '_' and then a_text [a_text.count] /= '_'
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
            if i + 1 <= a_text.count and then a_text [i] = '0' then
                inspect a_text [i + 1]
                when 'x' then l_base := 16
                when 'o' then l_base := 8
                when 'b' then l_base := 2
                else end
                if l_base > 0 then l_prefix_end := i + 1 end
            end
            from i := 2 until i >= a_text.count or else not Result loop
                if a_text [i] = '_' then
                    if l_base > 0 then
                        Result := i > l_prefix_end + 1 and then digit_value (a_text [i - 1]) < l_base and then
                            digit_value (a_text [i + 1]) < l_base
                    else
                        Result := a_text [i - 1].is_digit and then a_text [i + 1].is_digit
                    end
                end
                i := i + 1
            end
        end

    is_integer_out_of_range (a_source: STRING_32): BOOLEAN
            -- Is `a_source` a syntactically valid integer outside TOML's signed 64-bit range?
        local
            l_text: STRING_32
        do
            l_text := a_source.twin
            if valid_numeric_underscores (l_text) then
                l_text.replace_substring_all ("_", "")
                Result := (is_decimal_integer (l_text) and then not l_text.is_integer_64) or else
                    (is_based_integer (l_text) and then not is_based_integer_in_range (l_text))
            end
        end

feature {NONE} -- Formats

    is_decimal_integer (a_text: STRING_32): BOOLEAN
        local i, l_digit_count: INTEGER
        do
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
            l_digit_count := a_text.count - i + 1
            Result := l_digit_count > 0 and then is_decimal (a_text.substring (i, a_text.count)) and then
                (l_digit_count = 1 or else a_text [i] /= '0')
        end

    is_decimal_float (a_text: STRING_32): BOOLEAN
        local
            i, l_start, l_integer_digits, l_fraction_digits, l_exponent_digits: INTEGER
            l_has_dot, l_has_exponent: BOOLEAN
        do
            i := 1
            if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
            l_start := i
            from until i > a_text.count or else not a_text [i].is_digit loop l_integer_digits := l_integer_digits + 1; i := i + 1 end
            if i <= a_text.count and then a_text [i] = '.' then
                l_has_dot := True
                i := i + 1
                from until i > a_text.count or else not a_text [i].is_digit loop l_fraction_digits := l_fraction_digits + 1; i := i + 1 end
            end
            if i <= a_text.count and then (a_text [i] = 'e' or a_text [i] = 'E') then
                l_has_exponent := True
                i := i + 1
                if i <= a_text.count and then (a_text [i] = '+' or a_text [i] = '-') then i := i + 1 end
                from until i > a_text.count or else not a_text [i].is_digit loop l_exponent_digits := l_exponent_digits + 1; i := i + 1 end
            end
            Result := i > a_text.count and l_integer_digits > 0 and
                (l_integer_digits = 1 or else a_text [l_start] /= '0') and
                (l_has_dot or l_has_exponent) and (not l_has_dot or l_fraction_digits > 0) and
                (not l_has_exponent or l_exponent_digits > 0)
        end

    is_based_integer (a_text: STRING_32): BOOLEAN
        local i, l_base: INTEGER; l_valid: BOOLEAN
        do
            i := 1
            if i + 2 <= a_text.count and then a_text [i] = '0' then
                inspect a_text [i + 1]
                when 'x' then l_base := 16
                when 'o' then l_base := 8
                when 'b' then l_base := 2
                else end
                i := i + 2
            end
            l_valid := l_base > 0 and i <= a_text.count
            from until i > a_text.count or else not l_valid loop l_valid := digit_value (a_text [i]) < l_base; i := i + 1 end
            Result := l_valid
        end

    based_integer (a_text: STRING_32): INTEGER_64
        require based: is_based_integer (a_text)
        local i, l_base, l_sign: INTEGER
        do
            i := 1
            l_sign := 1
            if a_text [i] = '-' then l_sign := -1; i := i + 1 elseif a_text [i] = '+' then i := i + 1 end
            inspect a_text [i + 1]
            when 'x' then l_base := 16
            when 'o' then l_base := 8
            when 'b' then l_base := 2
            else end
            from i := i + 2 until i > a_text.count loop Result := Result * l_base + digit_value (a_text [i]); i := i + 1 end
            Result := Result * l_sign
        end

    is_based_integer_in_range (a_text: STRING_32): BOOLEAN
        require
            based: is_based_integer (a_text)
        local
            i, l_base, l_digit: INTEGER
            l_value, l_limit: INTEGER_64
        do
            i := 1
            inspect a_text [i + 1]
            when 'x' then l_base := 16
            when 'o' then l_base := 8
            when 'b' then l_base := 2
            else end
            l_limit := {INTEGER_64}.max_value
            Result := True
            from i := i + 2 until i > a_text.count or else not Result loop
                l_digit := digit_value (a_text [i])
                Result := l_value <= (l_limit - l_digit) // l_base
                if Result then
                    l_value := l_value * l_base + l_digit
                end
                i := i + 1
            end
        end

    digit_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then Result := 10 + a_character.code - ('a').code
            elseif 'A' <= a_character and a_character <= 'F' then Result := 10 + a_character.code - ('A').code
            else Result := 99 end
        end

    is_decimal (a_text: STRING_32): BOOLEAN
        local i: INTEGER
        do
            Result := not a_text.is_empty
            from i := 1 until i > a_text.count or else not Result loop Result := a_text [i].is_digit; i := i + 1 end
        end

    value_factory: TOMELLE_VALUE_FACTORY

end
