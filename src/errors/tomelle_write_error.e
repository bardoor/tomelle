note
    description: "Immutable TOML file serialization error."

class
    TOMELLE_WRITE_ERROR

create {TOMELLE_WRITER}
    make

feature {NONE} -- Initialization

    make (a_code: TOMELLE_ERROR_CODE; a_message, a_target_name: READABLE_STRING_GENERAL)
        require write_code: a_code.is_write_code
        do
            code := a_code
            internal_message := a_message.as_string_32.twin
            internal_target_name := a_target_name.as_string_32.twin
        end

feature -- Access

    code: TOMELLE_ERROR_CODE

    message: READABLE_STRING_32
        do
            Result := internal_message.twin
        end

    target_name: READABLE_STRING_32
        do
            Result := internal_target_name.twin
        end

feature {NONE} -- Storage

    internal_message: STRING_32
    internal_target_name: STRING_32

end
