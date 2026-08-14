note
    description: "Explicit success or classified failure from TOML value parsing."

class
    TOMELLE_VALUE_PARSE_RESULT

create
    make_success,
    make_failure

feature {NONE} -- Initialization

    make_success (a_value: TOMELLE_VALUE)
        do
            value := a_value
            create internal_message.make_empty
            error_column := 1
        ensure
            successful: is_success
        end

    make_failure (a_code: TOMELLE_ERROR_CODE; a_message: READABLE_STRING_GENERAL; a_column: INTEGER)
        require
            parse_code: a_code.is_parse_code
            positive_column: a_column >= 1
        do
            internal_error_code := a_code
            internal_message := a_message.as_string_32.twin
            error_column := a_column
        ensure
            failed: not is_success
        end

feature -- Outcome

    is_success: BOOLEAN
        do
            Result := attached value
        end

    value: detachable TOMELLE_VALUE

    error_code: TOMELLE_ERROR_CODE
        require
            failed: not is_success
        do
            Result := internal_error_code
        end

    message: READABLE_STRING_32
        require
            failed: not is_success
        do
            Result := internal_message.twin
        end

    error_column: INTEGER

feature {NONE} -- Storage

    internal_message: STRING_32
    internal_error_code: TOMELLE_ERROR_CODE

invariant
    positive_column: error_column >= 1
    success_has_value: is_success = attached value
    failure_has_message: not is_success implies not internal_message.is_empty

end
