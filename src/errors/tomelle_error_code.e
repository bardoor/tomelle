note
    description: "Stable machine-readable Tomelle error code."

expanded class
    TOMELLE_ERROR_CODE

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
            value := invalid_syntax_value
        ensure then
            invalid_syntax_by_default: value = invalid_syntax_value
        end

    make (a_value: INTEGER)
        require
            valid_value: is_valid_value (a_value)
        do
            value := a_value
        ensure
            value_set: value = a_value
        end

feature -- Access

    value: INTEGER

    name: STRING_8
        do
            inspect value
            when invalid_syntax_value then
                Result := "invalid_syntax"
            when invalid_utf_8_value then
                Result := "invalid_utf_8"
            when input_unreadable_value then
                Result := "input_unreadable"
            when integer_out_of_range_value then
                Result := "integer_out_of_range"
            when duplicate_key_value then
                Result := "duplicate_key"
            when invalid_key_value then
                Result := "invalid_key"
            when invalid_string_value then
                Result := "invalid_string"
            when invalid_number_value then
                Result := "invalid_number"
            when invalid_date_time_value then
                Result := "invalid_date_time"
            when unexpected_end_of_input_value then
                Result := "unexpected_end_of_input"
            when output_unwritable_value then
                Result := "output_unwritable"
            when output_interrupted_value then
                Result := "output_interrupted"
            else
                check
                    valid_value: False
                then
                end
                create Result.make_empty
            end
        ensure
            not_empty: not Result.is_empty
        end

feature -- Codes

    invalid_syntax: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_syntax_value)
        end

    invalid_utf_8: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_utf_8_value)
        end

    input_unreadable: TOMELLE_ERROR_CODE
        once
            create Result.make (input_unreadable_value)
        end

    integer_out_of_range: TOMELLE_ERROR_CODE
        once
            create Result.make (integer_out_of_range_value)
        end

    duplicate_key: TOMELLE_ERROR_CODE
        once
            create Result.make (duplicate_key_value)
        end

    invalid_key: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_key_value)
        end

    invalid_string: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_string_value)
        end

    invalid_number: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_number_value)
        end

    invalid_date_time: TOMELLE_ERROR_CODE
        once
            create Result.make (invalid_date_time_value)
        end

    unexpected_end_of_input: TOMELLE_ERROR_CODE
        once
            create Result.make (unexpected_end_of_input_value)
        end

    output_unwritable: TOMELLE_ERROR_CODE
        once
            create Result.make (output_unwritable_value)
        end

    output_interrupted: TOMELLE_ERROR_CODE
        once
            create Result.make (output_interrupted_value)
        end

feature -- Status report

    is_valid_value (a_value: INTEGER): BOOLEAN
        do
            Result := (invalid_syntax_value <= a_value and a_value <= unexpected_end_of_input_value) or else
                (output_unwritable_value <= a_value and a_value <= output_interrupted_value)
        end

    is_parse_code: BOOLEAN
        do
            Result := invalid_syntax_value <= value and value <= unexpected_end_of_input_value
        end

    is_write_code: BOOLEAN
        do
            Result := output_unwritable_value <= value and value <= output_interrupted_value
        end

feature -- Code values

    invalid_syntax_value: INTEGER = 1
    invalid_utf_8_value: INTEGER = 2
    input_unreadable_value: INTEGER = 3
    integer_out_of_range_value: INTEGER = 4
    duplicate_key_value: INTEGER = 5
    invalid_key_value: INTEGER = 6
    invalid_string_value: INTEGER = 7
    invalid_number_value: INTEGER = 8
    invalid_date_time_value: INTEGER = 9
    unexpected_end_of_input_value: INTEGER = 10

    output_unwritable_value: INTEGER = 101
    output_interrupted_value: INTEGER = 102

invariant
    valid_value: is_valid_value (value)

end
