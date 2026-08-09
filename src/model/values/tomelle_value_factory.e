note
    description: "Factory for TOML values used by generic APIs."

class
    TOMELLE_VALUE_FACTORY

create
    make

feature {NONE} -- Initialization

    make
        do
        end

feature -- Construction

    new_string (a_value: READABLE_STRING_GENERAL): TOMELLE_VALUE
        do
            create Result.make_string (a_value)
        ensure
            correct_type: Result.is_string
        end

    new_string_32 (a_value: STRING_32): TOMELLE_VALUE
        do
            create Result.make_string_owned (a_value)
        ensure
            correct_type: Result.is_string
        end

    new_parser_string (a_encoded_value: STRING_32): TOMELLE_VALUE
        do
            create Result.make_parser_string (a_encoded_value)
        ensure
            correct_type: Result.is_string
        end

    new_integer (a_value: INTEGER_64): TOMELLE_VALUE
        do
            create Result.make_integer (a_value)
        ensure
            value_set: Result.as_integer = a_value
        end

    new_float (a_value: REAL_64): TOMELLE_VALUE
        do
            create Result.make_float (a_value)
        ensure
            correct_type: Result.is_float
        end

    new_float_with_lexeme (a_value: REAL_64; a_lexeme: STRING_32): TOMELLE_VALUE
        do
            create Result.make_float_with_lexeme (a_value, a_lexeme)
        ensure
            correct_type: Result.is_float
        end

    new_boolean (a_value: BOOLEAN): TOMELLE_VALUE
        do
            create Result.make_boolean (a_value)
        ensure
            value_set: Result.as_boolean = a_value
        end

    new_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME): TOMELLE_VALUE
        do
            create Result.make_offset_date_time (a_value)
        ensure
            correct_type: Result.is_offset_date_time
        end

    new_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME): TOMELLE_VALUE
        do
            create Result.make_local_date_time (a_value)
        ensure
            correct_type: Result.is_local_date_time
        end

    new_local_date (a_value: TOMELLE_LOCAL_DATE): TOMELLE_VALUE
        do
            create Result.make_local_date (a_value)
        ensure
            correct_type: Result.is_local_date
        end

    new_local_time (a_value: TOMELLE_LOCAL_TIME): TOMELLE_VALUE
        do
            create Result.make_local_time (a_value)
        ensure
            correct_type: Result.is_local_time
        end

    new_array (a_value: TOMELLE_ARRAY): TOMELLE_VALUE
        do
            create Result.make_array (a_value)
        ensure
            correct_type: Result.is_array
        end

    new_table (a_value: TOMELLE_TABLE): TOMELLE_VALUE
        do
            create Result.make_table (a_value)
        ensure
            correct_type: Result.is_table
        end

end
