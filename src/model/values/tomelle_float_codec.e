note
    description: "Compiler-independent TOML float conversion and canonical formatting."

class
    TOMELLE_FLOAT_CODEC

feature -- Conversion

    is_valid_finite_text (a_text: READABLE_STRING_GENERAL): BOOLEAN
            -- Is `a_text` a finite decimal number accepted by the exact-text API?
        local
            l_text: STRING_32
            i: INTEGER
        do
            l_text := a_text.as_string_32
            i := 1
            if i <= l_text.count and then (l_text [i] = '-' or else l_text [i] = '+') then
                i := i + 1
            end
            Result := i <= l_text.count and then l_text [i].is_digit
            from until i > l_text.count or else not l_text [i].is_digit loop
                i := i + 1
            end
            if Result and then i <= l_text.count and then l_text [i] = '.' then
                i := i + 1
                Result := i <= l_text.count and then l_text [i].is_digit
                from until i > l_text.count or else not l_text [i].is_digit loop
                    i := i + 1
                end
            end
            if Result and then i <= l_text.count and then (l_text [i] = 'e' or else l_text [i] = 'E') then
                i := i + 1
                if i <= l_text.count and then (l_text [i] = '-' or else l_text [i] = '+') then
                    i := i + 1
                end
                Result := i <= l_text.count and then l_text [i].is_digit
                from until i > l_text.count or else not l_text [i].is_digit loop
                    i := i + 1
                end
            end
            Result := Result and i > l_text.count
        end

    parsed_value (a_text: READABLE_STRING_GENERAL): REAL_64
            -- Binary64 value represented by valid finite TOML float `a_text`.
        local
            l_text, l_digits: STRING_32
            i, l_fraction_count, l_exponent, l_scale, l_digit: INTEGER
            l_negative, l_in_fraction, l_exponent_negative: BOOLEAN
            l_significand: INTEGER_64
            l_real_significand: REAL_64
            l_uses_integer: BOOLEAN
        do
            l_text := a_text.as_string_32
            create l_digits.make (l_text.count)
            i := 1
            if l_text [i] = '-' then
                l_negative := True
                i := i + 1
            elseif l_text [i] = '+' then
                i := i + 1
            end
            from until i > l_text.count or else l_text [i] = 'e' or else l_text [i] = 'E' loop
                if l_text [i] = '.' then
                    l_in_fraction := True
                elseif l_text [i].is_digit then
                    l_digits.extend (l_text [i])
                    if l_in_fraction then
                        l_fraction_count := l_fraction_count + 1
                    end
                end
                i := i + 1
            end
            if i <= l_text.count then
                i := i + 1
                if i <= l_text.count and then l_text [i] = '-' then
                    l_exponent_negative := True
                    i := i + 1
                elseif i <= l_text.count and then l_text [i] = '+' then
                    i := i + 1
                end
                from until i > l_text.count loop
                    if l_exponent < 10000 then
                        l_exponent := l_exponent * 10 + l_text [i].code - ('0').code
                    end
                    i := i + 1
                end
                if l_exponent_negative then
                    l_exponent := -l_exponent
                end
            end
            strip_insignificant_zeros (l_digits)
            l_scale := l_exponent - l_fraction_count
            l_uses_integer := l_digits.count <= 18
            if l_uses_integer then
                from i := 1 until i > l_digits.count loop
                    l_significand := l_significand * 10 + l_digits [i].code - ('0').code
                    i := i + 1
                end
                l_real_significand := l_significand.to_double
            else
                from i := 1 until i > l_digits.count loop
                    l_digit := l_digits [i].code - ('0').code
                    l_real_significand := l_real_significand * 10.0 + l_digit
                    i := i + 1
                end
            end
            Result := scaled (l_real_significand, l_scale)
            if l_negative then
                Result := -Result
            end
        end

feature -- Formatting

    canonical_source (a_text: READABLE_STRING_GENERAL): STRING_32
            -- Canonical decimal spelling of valid finite TOML float `a_text`.
        local
            l_text, l_digits: STRING_32
            i, l_fraction_count, l_exponent, l_decimal_position: INTEGER
            l_negative, l_in_fraction, l_exponent_negative: BOOLEAN
        do
            l_text := a_text.as_string_32
            create l_digits.make (l_text.count)
            i := 1
            if l_text [i] = '-' then
                l_negative := True
                i := i + 1
            elseif l_text [i] = '+' then
                i := i + 1
            end
            from until i > l_text.count or else l_text [i] = 'e' or else l_text [i] = 'E' loop
                if l_text [i] = '.' then
                    l_in_fraction := True
                elseif l_text [i].is_digit then
                    l_digits.extend (l_text [i])
                    if l_in_fraction then
                        l_fraction_count := l_fraction_count + 1
                    end
                end
                i := i + 1
            end
            if i <= l_text.count then
                i := i + 1
                if i <= l_text.count and then l_text [i] = '-' then
                    l_exponent_negative := True
                    i := i + 1
                elseif i <= l_text.count and then l_text [i] = '+' then
                    i := i + 1
                end
                from until i > l_text.count loop
                    if l_exponent < 10000 then
                        l_exponent := l_exponent * 10 + l_text [i].code - ('0').code
                    end
                    i := i + 1
                end
                if l_exponent_negative then
                    l_exponent := -l_exponent
                end
            end
            strip_insignificant_zeros (l_digits)
            if is_zero_digits (l_digits) then
                if l_negative then
                    Result := "-0.0"
                else
                    Result := "0.0"
                end
            else
                from until l_digits.is_empty or else l_digits [1] /= '0' loop
                    l_digits.remove (1)
                end
                from until l_digits.count <= 1 or else l_digits [l_digits.count] /= '0' loop
                    l_digits.remove_tail (1)
                    l_exponent := l_exponent + 1
                end
                l_decimal_position := l_digits.count + l_exponent - l_fraction_count
                if l_negative then
                    create Result.make_from_string ("-")
                else
                    create Result.make_empty
                end
                if -5 <= l_decimal_position and l_decimal_position <= 21 then
                    append_fixed (Result, l_digits, l_decimal_position)
                else
                    append_scientific (Result, l_digits, l_decimal_position - 1)
                end
            end
        ensure
            not_empty: not Result.is_empty
        end

    canonical_value (a_value: REAL_64): STRING_32
            -- Canonical TOML spelling of `a_value`.
        local
            l_candidate, l_shorter: STRING_32
            l_done: BOOLEAN
        do
            if a_value.is_nan then
                Result := "nan"
            elseif a_value.is_positive_infinity then
                Result := "inf"
            elseif a_value.is_negative_infinity then
                Result := "-inf"
            else
                l_candidate := canonical_source (a_value.out)
                from until l_done loop
                    l_shorter := without_last_significant_digit (l_candidate)
                    if l_shorter.same_string (l_candidate) or else parsed_value (l_shorter) /= a_value then
                        l_done := True
                    else
                        l_candidate := l_shorter
                    end
                end
                Result := l_candidate
            end
        ensure
            not_empty: not Result.is_empty
        end

feature {NONE} -- Decimal operations

    strip_insignificant_zeros (a_digits: STRING_32)
            -- Keep at least one digit; zero stripping that changes scale is handled by callers.
        local
            i: INTEGER
        do
            from i := 1 until i >= a_digits.count or else a_digits [i] /= '0' loop
                i := i + 1
            end
            if i > 1 then
                a_digits.remove_head (i - 1)
            end
        end

    is_zero_digits (a_digits: STRING_32): BOOLEAN
        local
            i: INTEGER
        do
            Result := True
            from i := 1 until i > a_digits.count or else not Result loop
                Result := a_digits [i] = '0'
                i := i + 1
            end
        end

    scaled (a_value: REAL_64; a_decimal_exponent: INTEGER): REAL_64
        local
            i: INTEGER
        do
            Result := a_value
            if a_decimal_exponent > 0 then
                from i := 1 until i > a_decimal_exponent or else Result.is_positive_infinity loop
                    Result := Result * 10.0
                    i := i + 1
                end
            elseif a_decimal_exponent < 0 then
                from i := -1 until i < a_decimal_exponent or else Result = 0.0 loop
                    Result := Result / 10.0
                    i := i - 1
                end
            end
        end

    append_fixed (a_target, a_digits: STRING_32; a_decimal_position: INTEGER)
        local
            i: INTEGER
        do
            if a_decimal_position <= 0 then
                a_target.append ("0.")
                from i := 1 until i > -a_decimal_position loop
                    a_target.extend ('0')
                    i := i + 1
                end
                a_target.append (a_digits)
            elseif a_decimal_position >= a_digits.count then
                a_target.append (a_digits)
                from i := a_digits.count until i >= a_decimal_position loop
                    a_target.extend ('0')
                    i := i + 1
                end
                a_target.append (".0")
            else
                a_target.append (a_digits.substring (1, a_decimal_position))
                a_target.extend ('.')
                a_target.append (a_digits.substring (a_decimal_position + 1, a_digits.count))
            end
        end

    append_scientific (a_target, a_digits: STRING_32; a_exponent: INTEGER)
        do
            a_target.extend (a_digits [1])
            if a_digits.count > 1 then
                a_target.extend ('.')
                a_target.append (a_digits.substring (2, a_digits.count))
            end
            a_target.extend ('e')
            if a_exponent >= 0 then
                a_target.extend ('+')
            end
            a_target.append (a_exponent.out)
        end

    without_last_significant_digit (a_text: STRING_32): STRING_32
        local
            i, l_exponent_index, l_digit_count: INTEGER
        do
            Result := a_text.twin
            l_exponent_index := Result.index_of ('e', 1)
            if l_exponent_index = 0 then
                l_exponent_index := Result.count + 1
            end
            from i := 1 until i >= l_exponent_index loop
                if Result [i].is_digit then
                    l_digit_count := l_digit_count + 1
                end
                i := i + 1
            end
            if l_digit_count > 1 then
                from i := l_exponent_index - 1 until i < 1 or else Result [i].is_digit loop
                    i := i - 1
                end
                if i >= 1 then
                    Result.remove (i)
                    if i > 1 and then Result [i - 1] = '.' and then
                        (i > Result.count or else Result [i] = 'e')
                    then
                        Result.remove (i - 1)
                    end
                    Result := canonical_source (Result)
                end
            end
        end

end
