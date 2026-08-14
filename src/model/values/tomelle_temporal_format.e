note
    description: "Canonical rendering for TOML temporal values."

class
    TOMELLE_TEMPORAL_FORMAT

feature -- Rendering

    date (a_value: TOMELLE_LOCAL_DATE): STRING_32
        do
            Result := padded (a_value.year, 4) + "-" + padded (a_value.month, 2) + "-" + padded (a_value.day, 2)
        end

    time (a_value: TOMELLE_LOCAL_TIME): STRING_32
        do
            Result := padded (a_value.hour, 2) + ":" + padded (a_value.minute, 2) + ":" + padded (a_value.second, 2)
            if a_value.fractional_digit_count > 0 then
                Result.extend ('.')
                Result.append (padded (a_value.nanosecond, 9).substring (1, a_value.fractional_digit_count))
            end
        end

    local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME): STRING_32
        do
            Result := date (a_value.date) + "T" + time (a_value.time)
        end

    offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME): STRING_32
        local
            l_absolute: INTEGER
        do
            Result := local_date_time (a_value.local_date_time)
            if a_value.is_utc then
                Result.extend ('Z')
            else
                l_absolute := a_value.offset_minutes.abs
                if a_value.offset_minutes < 0 then Result.extend ('-') else Result.extend ('+') end
                Result.append (padded (l_absolute // 60, 2))
                Result.extend (':')
                Result.append (padded (l_absolute \\ 60, 2))
            end
        end

feature {NONE} -- Implementation

    padded (a_value, a_width: INTEGER): STRING_32
        do
            Result := a_value.out
            from until Result.count >= a_width loop Result.prepend_character ('0') end
        end

end
