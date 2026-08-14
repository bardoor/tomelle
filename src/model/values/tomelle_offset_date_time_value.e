note
    description: "Lossless TOML offset date-time item."

class
    TOMELLE_OFFSET_DATE_TIME_VALUE

inherit
    TOMELLE_VALUE
        redefine
            is_equal
        end

create
    make,
    make_parsed

feature {NONE} -- Initialization

    make (a_value: TOMELLE_OFFSET_DATE_TIME)
        do
            initialize_item
            value := a_value
            raw_text := formatter.offset_date_time (value)
        end

    make_parsed (a_value: TOMELLE_OFFSET_DATE_TIME; a_raw_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value
            raw_text := a_raw_text.as_string_32.twin
        end

feature -- Access

    value: TOMELLE_OFFSET_DATE_TIME
    raw_text: STRING_32
    representation: STRING_32 do Result := raw_text.twin end

feature {TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Copying

    cloned_value: TOMELLE_VALUE
        local l_result: TOMELLE_OFFSET_DATE_TIME_VALUE
        do
            create l_result.make_parsed (value, raw_text)
            l_result.set_trivia (trivia)
            Result := l_result
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN do Result := value = other.value end

feature {NONE} -- Implementation

    formatter: TOMELLE_TEMPORAL_FORMAT once create Result end

end
