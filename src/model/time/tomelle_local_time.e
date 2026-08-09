note
    description: "Immutable TOML local-time value with nanosecond precision."

expanded class
    TOMELLE_LOCAL_TIME

inherit
    ANY
        redefine
            default_create
        end

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
        do
            hour := 0
            minute := 0
            second := 0
            nanosecond := 0
            fractional_digit_count := 0
        ensure then
            midnight: hour = 0 and minute = 0 and second = 0
            no_fraction: nanosecond = 0 and fractional_digit_count = 0
        end

    make (a_hour, a_minute, a_second, a_nanosecond, a_fractional_digit_count: INTEGER)
        require
            valid_time: is_valid_time (a_hour, a_minute, a_second)
            valid_fraction: is_valid_fraction (a_nanosecond, a_fractional_digit_count)
        do
            hour := a_hour
            minute := a_minute
            second := a_second
            nanosecond := a_nanosecond
            fractional_digit_count := a_fractional_digit_count
        ensure
            hour_set: hour = a_hour
            minute_set: minute = a_minute
            second_set: second = a_second
            nanosecond_set: nanosecond = a_nanosecond
            digit_count_set: fractional_digit_count = a_fractional_digit_count
        end

feature -- Access

    hour: INTEGER
    minute: INTEGER
    second: INTEGER
    nanosecond: INTEGER
    fractional_digit_count: INTEGER

feature -- Validation

    is_valid_time (a_hour, a_minute, a_second: INTEGER): BOOLEAN
        do
            Result := 0 <= a_hour and a_hour <= 23 and
                0 <= a_minute and a_minute <= 59 and
                0 <= a_second and a_second <= 59
        end

    is_valid_fraction (a_nanosecond, a_digit_count: INTEGER): BOOLEAN
        local
            l_factor, i: INTEGER
        do
            if 0 <= a_nanosecond and a_nanosecond <= 999999999 and
                0 <= a_digit_count and a_digit_count <= 9
            then
                l_factor := 1
                from i := a_digit_count until i = 9 loop
                    l_factor := l_factor * 10
                    i := i + 1
                end
                Result := a_nanosecond \\ l_factor = 0
            end
        end

invariant
    valid_time: is_valid_time (hour, minute, second)
    valid_fraction: is_valid_fraction (nanosecond, fractional_digit_count)

end
