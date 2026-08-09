note
    description: "Dynamically typed TOML value."

class
    TOMELLE_VALUE

inherit
    ANY
        redefine
            is_equal
        end

create {TOMELLE_VALUE, TOMELLE_VALUE_FACTORY, TOMELLE_PARSER, TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY}
    make_string,
    make_string_owned,
    make_parser_string,
    make_integer,
    make_float,
    make_float_with_lexeme,
    make_boolean,
    make_offset_date_time,
    make_local_date_time,
    make_local_date,
    make_local_time,
    make_array,
    make_table

feature {NONE} -- Initialization

    make_string (a_value: READABLE_STRING_GENERAL)
        local
            i: INTEGER
            l_characters: ARRAYED_LIST [CHARACTER_32]
        do
            kind := string_kind
            create l_characters.make (a_value.count)
            from i := 1 until i > a_value.count loop
                l_characters.extend (a_value.as_string_32 [i])
                i := i + 1
            end
            internal_characters := l_characters
        end

    make_string_owned (a_value: STRING_32)
        local
            i: INTEGER
            l_characters: ARRAYED_LIST [CHARACTER_32]
        do
            kind := string_kind
            create l_characters.make (a_value.count)
            from i := 1 until i > a_value.count loop
                l_characters.extend (a_value [i])
                i := i + 1
            end
            internal_characters := l_characters
        end

    make_parser_string (a_encoded_value: STRING_32)
        do
            kind := string_kind
            parser_encoded_string := a_encoded_value
        end

    make_integer (a_value: INTEGER_64)
        do
            kind := integer_kind
            internal_integer := a_value
        end

    make_float (a_value: REAL_64)
        do
            kind := float_kind
            internal_float := a_value
        end

    make_float_with_lexeme (a_value: REAL_64; a_lexeme: STRING_32)
        do
            kind := float_kind
            internal_float := a_value
            float_lexeme := a_lexeme
        end

    make_boolean (a_value: BOOLEAN)
        do
            kind := boolean_kind
            internal_boolean := a_value
        end

    make_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME)
        do
            kind := offset_date_time_kind
            internal_offset_date_time := a_value
        end

    make_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME)
        do
            kind := local_date_time_kind
            internal_local_date_time := a_value
        end

    make_local_date (a_value: TOMELLE_LOCAL_DATE)
        do
            kind := local_date_kind
            internal_local_date := a_value
        end

    make_local_time (a_value: TOMELLE_LOCAL_TIME)
        do
            kind := local_time_kind
            internal_local_time := a_value
        end

    make_array (a_value: TOMELLE_ARRAY)
        do
            kind := array_kind
            internal_array := a_value.cloned_array
        end

    make_table (a_value: TOMELLE_TABLE)
        do
            kind := table_kind
            internal_table := a_value.cloned_table
        end

feature -- Type report

    is_string: BOOLEAN
        do
            Result := kind = string_kind
        end

    is_integer: BOOLEAN
        do
            Result := kind = integer_kind
        end

    is_float: BOOLEAN
        do
            Result := kind = float_kind
        end

    is_boolean: BOOLEAN
        do
            Result := kind = boolean_kind
        end

    is_offset_date_time: BOOLEAN
        do
            Result := kind = offset_date_time_kind
        end

    is_local_date_time: BOOLEAN
        do
            Result := kind = local_date_time_kind
        end

    is_local_date: BOOLEAN
        do
            Result := kind = local_date_kind
        end

    is_local_time: BOOLEAN
        do
            Result := kind = local_time_kind
        end

    is_array: BOOLEAN
        do
            Result := kind = array_kind
        end

    is_table: BOOLEAN
        do
            Result := kind = table_kind
        end

feature -- Typed access

    as_string: READABLE_STRING_32
        require is_string: is_string
        local l_result: STRING_32
        do
            if attached parser_encoded_string as l_encoded then
                Result := decoded_parser_string (l_encoded)
            else check attached internal_characters as l_characters then
                create l_result.make (l_characters.count)
                across l_characters as l_character loop
                    l_result.extend (l_character)
                end
                Result := l_result
            end
            end
        end

    as_integer: INTEGER_64
        require is_integer: is_integer
        do
            Result := internal_integer
        end

    as_float: REAL_64
        require is_float: is_float
        do
            Result := internal_float
        end

    float_lexeme: detachable STRING_32

    as_boolean: BOOLEAN
        require is_boolean: is_boolean
        do
            Result := internal_boolean
        end

    as_offset_date_time: TOMELLE_OFFSET_DATE_TIME
        require is_offset_date_time: is_offset_date_time
        do
            Result := internal_offset_date_time
        end

    as_local_date_time: TOMELLE_LOCAL_DATE_TIME
        require is_local_date_time: is_local_date_time
        do
            Result := internal_local_date_time
        end

    as_local_date: TOMELLE_LOCAL_DATE
        require is_local_date: is_local_date
        do
            Result := internal_local_date
        end

    as_local_time: TOMELLE_LOCAL_TIME
        require is_local_time: is_local_time
        do
            Result := internal_local_time
        end

    as_array: TOMELLE_ARRAY
        require is_array: is_array
        do
            check attached internal_array as l_value then
                Result := l_value
            end
        end

    as_table: TOMELLE_TABLE
        require is_table: is_table
        do
            check attached internal_table as l_value then
                Result := l_value
            end
        end

feature {TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY, TOMELLE_VALUE_FACTORY} -- Copying

    cloned_value: TOMELLE_VALUE
        do
            inspect kind
            when string_kind then
                if attached parser_encoded_string as l_encoded then
                    create Result.make_parser_string (l_encoded)
                else
                    create Result.make_string (as_string)
                end
            when integer_kind then create Result.make_integer (as_integer)
            when float_kind then
                if attached float_lexeme as l_lexeme then
                    create Result.make_float_with_lexeme (as_float, l_lexeme)
                else
                    create Result.make_float (as_float)
                end
            when boolean_kind then create Result.make_boolean (as_boolean)
            when offset_date_time_kind then create Result.make_offset_date_time (as_offset_date_time)
            when local_date_time_kind then create Result.make_local_date_time (as_local_date_time)
            when local_date_kind then create Result.make_local_date (as_local_date)
            when local_time_kind then create Result.make_local_time (as_local_time)
            when array_kind then create Result.make_array (as_array)
            when table_kind then create Result.make_table (as_table)
            else check valid_kind: False then end
            end
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        local l_left, l_right: REAL_64
        do
            if kind = other.kind then
                inspect kind
                when string_kind then
                    Result := as_string.same_string (other.as_string)
                when integer_kind then
                    Result := as_integer = other.as_integer
                when float_kind then
                    l_left := as_float
                    l_right := other.as_float
                    Result := l_left = l_right or else (l_left.is_nan and l_right.is_nan)
                when boolean_kind then
                    Result := as_boolean = other.as_boolean
                when offset_date_time_kind then
                    Result := as_offset_date_time = other.as_offset_date_time
                when local_date_time_kind then
                    Result := as_local_date_time = other.as_local_date_time
                when local_date_kind then
                    Result := as_local_date = other.as_local_date
                when local_time_kind then
                    Result := as_local_time = other.as_local_time
                when array_kind then
                    Result := as_array.is_equal (other.as_array)
                when table_kind then
                    Result := as_table.is_equal (other.as_table)
                else end
            end
        end

feature {TOMELLE_VALUE} -- Type identity

    kind: INTEGER

feature {NONE} -- Storage

    decoded_parser_string (a_encoded: STRING_32): STRING_32
        local
            i, j: INTEGER
            l_code: NATURAL_32
        do
            create Result.make (a_encoded.count)
            from i := 1 until i > a_encoded.count loop
                if a_encoded [i] = '~' and then i < a_encoded.count and then a_encoded [i + 1] = '~' then
                    Result.extend ('~')
                    i := i + 2
                elseif a_encoded [i] = '~' and then i + 9 <= a_encoded.count and then a_encoded [i + 9] = '~' then
                    l_code := 0
                    from j := 1 until j > 8 loop
                        l_code := l_code * 16 + hex_value (a_encoded [i + j]).to_natural_32
                        j := j + 1
                    end
                    Result.append_code (l_code)
                    i := i + 10
                else
                    Result.extend (a_encoded [i])
                    i := i + 1
                end
            end
        end

    hex_value (a_character: CHARACTER_32): INTEGER
        do
            if '0' <= a_character and a_character <= '9' then Result := a_character.code - ('0').code
            elseif 'A' <= a_character and a_character <= 'F' then Result := 10 + a_character.code - ('A').code
            else Result := 10 + a_character.code - ('a').code end
        end

    internal_characters: detachable ARRAYED_LIST [CHARACTER_32]
    parser_encoded_string: detachable STRING_32
    internal_integer: INTEGER_64
    internal_float: REAL_64
    internal_boolean: BOOLEAN
    internal_offset_date_time: TOMELLE_OFFSET_DATE_TIME
    internal_local_date_time: TOMELLE_LOCAL_DATE_TIME
    internal_local_date: TOMELLE_LOCAL_DATE
    internal_local_time: TOMELLE_LOCAL_TIME
    internal_array: detachable TOMELLE_ARRAY
    internal_table: detachable TOMELLE_TABLE

    string_kind: INTEGER = 1
    integer_kind: INTEGER = 2
    float_kind: INTEGER = 3
    boolean_kind: INTEGER = 4
    offset_date_time_kind: INTEGER = 5
    local_date_time_kind: INTEGER = 6
    local_date_kind: INTEGER = 7
    local_time_kind: INTEGER = 8
    array_kind: INTEGER = 9
    table_kind: INTEGER = 10

invariant
    valid_kind: string_kind <= kind and kind <= table_kind
    string_storage_exists: is_string implies attached internal_characters or attached parser_encoded_string
    array_attached: is_array implies attached internal_array
    table_attached: is_table implies attached internal_table

end
