note
    description: "Immutable TOML local date-time value."

expanded class
    TOMELLE_LOCAL_DATE_TIME

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
        local
            l_date: TOMELLE_LOCAL_DATE
            l_time: TOMELLE_LOCAL_TIME
        do
            create l_date.default_create
            create l_time.default_create
            date := l_date
            time := l_time
        end

    make (a_date: TOMELLE_LOCAL_DATE; a_time: TOMELLE_LOCAL_TIME)
        do
            date := a_date
            time := a_time
        ensure
            date_set: date = a_date
            time_set: time = a_time
        end

feature -- Access

    date: TOMELLE_LOCAL_DATE
    time: TOMELLE_LOCAL_TIME

end
