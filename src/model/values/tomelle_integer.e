note
    description: "Lossless TOML integer value."

class
    TOMELLE_INTEGER

inherit
    TOMELLE_VALUE
        redefine
            is_equal
        end

create
    make,
    make_parsed

feature {NONE} -- Initialization

    make (a_value: INTEGER_64)
        do
            initialize_item
            value := a_value
            raw_text := a_value.out
        end

    make_parsed (a_value: INTEGER_64; a_raw_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value
            raw_text := a_raw_text.as_string_32.twin
        end

feature -- Access

    value: INTEGER_64
    raw_text: STRING_32

    representation: STRING_32 do Result := raw_text.twin end

feature -- Element change

    set_value (a_value: INTEGER_64)
        do
            value := a_value
            raw_text := a_value.out
        ensure
            set: value = a_value
        end

feature {TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Copying

    cloned_value: TOMELLE_VALUE
        local l_result: TOMELLE_INTEGER
        do
            create l_result.make_parsed (value, raw_text)
            l_result.set_trivia (trivia)
            Result := l_result
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN do Result := value = other.value end

end
