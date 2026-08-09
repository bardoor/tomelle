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
            message := a_message.as_string_32.twin
            target_name := a_target_name.as_string_32.twin
        end

feature -- Access

    code: TOMELLE_ERROR_CODE
    message: STRING_32
    target_name: STRING_32

end
