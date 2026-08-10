note
    description: "Parses TOML local and offset date/time values."

class
    TOMELLE_TEMPORAL_PARSER

create
    make

feature {NONE} -- Initialization

    make
        do
            create value_factory.make
        end

feature -- Parsing

    parse (a_text: STRING_32): detachable TOMELLE_VALUE
        local
            l_date: TOMELLE_LOCAL_DATE
            l_time: TOMELLE_LOCAL_TIME
            l_date_time: TOMELLE_LOCAL_DATE_TIME
            l_offset: TOMELLE_OFFSET_DATE_TIME
            l_year, l_month, l_day, l_hour, l_minute, l_second: INTEGER
            l_nanosecond, l_digits, l_offset_minutes, l_offset_hour, l_offset_minute, l_sign, l_offset_index, i: INTEGER
            l_fraction: STRING_32
            l_valid, l_has_date, l_has_time, l_has_offset: BOOLEAN
        do
            l_has_date := a_text.count >= 10 and then a_text [5] = '-' and then a_text [8] = '-' and then
                is_decimal (a_text.substring (1, 4)) and then is_decimal (a_text.substring (6, 7)) and then
                is_decimal (a_text.substring (9, 10))
            if l_has_date then
                l_year := a_text.substring (1, 4).to_integer
                l_month := a_text.substring (6, 7).to_integer
                l_day := a_text.substring (9, 10).to_integer
                l_valid := l_date.is_valid_date (l_year, l_month, l_day)
            end
            if a_text.count = 10 and l_valid then
                create l_date.make (l_year, l_month, l_day)
                Result := value_factory.new_local_date (l_date)
            else
                if l_has_date and a_text.count >= 16 and then
                    (a_text [11] = 'T' or a_text [11] = 't' or a_text [11] = ' ')
                then
                    i := 12
                elseif a_text.count >= 5 then
                    i := 1
                    l_valid := True
                    l_has_date := False
                else
                    l_valid := False
                end
                if l_valid and then i + 4 <= a_text.count and then a_text [i + 2] = ':' and then
                    is_decimal (a_text.substring (i, i + 1)) and then is_decimal (a_text.substring (i + 3, i + 4))
                then
                    l_hour := a_text.substring (i, i + 1).to_integer
                    l_minute := a_text.substring (i + 3, i + 4).to_integer
                    if i + 7 <= a_text.count and then a_text [i + 5] = ':' and then is_decimal (a_text.substring (i + 6, i + 7)) then
                        l_second := a_text.substring (i + 6, i + 7).to_integer
                        i := i + 8
                    else
                        l_second := 0
                        i := i + 5
                    end
                    l_has_time := l_time.is_valid_time (l_hour, l_minute, l_second)
                    if i <= a_text.count and then a_text [i] = '.' then
                        i := i + 1
                        l_offset_index := i
                        from until i > a_text.count or else not a_text [i].is_digit loop i := i + 1 end
                        l_fraction := a_text.substring (l_offset_index, i - 1)
                        l_digits := l_fraction.count
                        if 1 <= l_digits and l_digits <= 9 then
                            from until l_fraction.count = 9 loop l_fraction.extend ('0') end
                            l_nanosecond := l_fraction.to_integer
                        else l_has_time := False end
                    end
                    if i <= a_text.count then
                        if (a_text [i] = 'Z' or a_text [i] = 'z') and i = a_text.count then
                            l_has_offset := True
                            i := i + 1
                        elseif (a_text [i] = '+' or a_text [i] = '-') and then i + 5 = a_text.count and then
                            a_text [i + 3] = ':' and then is_decimal (a_text.substring (i + 1, i + 2)) and then
                            is_decimal (a_text.substring (i + 4, i + 5))
                        then
                            if a_text [i] = '-' then l_sign := -1 else l_sign := 1 end
                            l_offset_hour := a_text.substring (i + 1, i + 2).to_integer
                            l_offset_minute := a_text.substring (i + 4, i + 5).to_integer
                            l_offset_minutes := l_sign * (l_offset_hour * 60 + l_offset_minute)
                            l_has_offset := l_offset_hour <= 23 and l_offset_minute <= 59
                            l_has_time := l_has_time and l_has_offset
                            i := a_text.count + 1
                        else l_has_time := False end
                    end
                    l_valid := l_has_time and i > a_text.count
                    if l_valid then
                        create l_time.make (l_hour, l_minute, l_second, l_nanosecond, l_digits)
                        if l_has_date then
                            create l_date.make (l_year, l_month, l_day)
                            create l_date_time.make (l_date, l_time)
                            if l_has_offset then
                                create l_offset.make (l_date_time, l_offset_minutes)
                                Result := value_factory.new_offset_date_time (l_offset)
                            else Result := value_factory.new_local_date_time (l_date_time) end
                        elseif not l_has_offset then
                            Result := value_factory.new_local_time (l_time)
                        end
                    end
                end
            end
        end

feature {NONE} -- Validation

    is_decimal (a_text: STRING_32): BOOLEAN
        local i: INTEGER
        do
            Result := not a_text.is_empty
            from i := 1 until i > a_text.count or else not Result loop Result := a_text [i].is_digit; i := i + 1 end
        end

    value_factory: TOMELLE_VALUE_FACTORY

end
