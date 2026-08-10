note
    description: "Base type for parsed TOML statements."

deferred class
    TOMELLE_STATEMENT

feature -- Access

    position: TOMELLE_SOURCE_POSITION

feature {TOMELLE_TABLE_HEADER, TOMELLE_ARRAY_TABLE_HEADER, TOMELLE_KEY_VALUE_STATEMENT} -- Initialization

    set_position (a_position: TOMELLE_SOURCE_POSITION)
        do
            position := a_position
        end

end
