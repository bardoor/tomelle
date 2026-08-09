note
    description: "Immutable TOML date-time value with a UTC offset."

expanded class
    TOMELLE_OFFSET_DATE_TIME

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
            l_local: TOMELLE_LOCAL_DATE_TIME
        do
            create l_local.default_create
            local_date_time := l_local
            offset_minutes := 0
        ensure then
            utc: is_utc
        end

    make (a_local_date_time: TOMELLE_LOCAL_DATE_TIME; a_offset_minutes: INTEGER)
        require
            valid_offset: -1439 <= a_offset_minutes and a_offset_minutes <= 1439
        do
            local_date_time := a_local_date_time
            offset_minutes := a_offset_minutes
        ensure
            local_date_time_set: local_date_time = a_local_date_time
            offset_set: offset_minutes = a_offset_minutes
        end

feature -- Access

    local_date_time: TOMELLE_LOCAL_DATE_TIME
    offset_minutes: INTEGER

feature -- Status report

    is_utc: BOOLEAN
        do
            Result := offset_minutes = 0
        ensure
            definition: Result = (offset_minutes = 0)
        end

invariant
    valid_offset: -1439 <= offset_minutes and offset_minutes <= 1439

end
