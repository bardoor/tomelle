note
    description: "Immutable TOML local-date value."

expanded class
    TOMELLE_LOCAL_DATE

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
            year := 0
            month := 1
            day := 1
        ensure then
            default_year: year = 0
            default_month: month = 1
            default_day: day = 1
        end

    make (a_year, a_month, a_day: INTEGER)
        require
            valid_date: is_valid_date (a_year, a_month, a_day)
        do
            year := a_year
            month := a_month
            day := a_day
        ensure
            year_set: year = a_year
            month_set: month = a_month
            day_set: day = a_day
        end

feature -- Access

    year: INTEGER
    month: INTEGER
    day: INTEGER

feature -- Validation

    is_valid_date (a_year, a_month, a_day: INTEGER): BOOLEAN
        local
            l_days: INTEGER
        do
            if 0 <= a_year and a_year <= 9999 and 1 <= a_month and a_month <= 12 then
                inspect a_month
                when 2 then
                    if a_year \\ 400 = 0 or else (a_year \\ 4 = 0 and a_year \\ 100 /= 0) then
                        l_days := 29
                    else
                        l_days := 28
                    end
                when 4, 6, 9, 11 then
                    l_days := 30
                else
                    l_days := 31
                end
                Result := 1 <= a_day and a_day <= l_days
            end
        end

invariant
    valid_date: is_valid_date (year, month, day)

end
