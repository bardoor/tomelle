note
    description: "Internal owned construction operations for TOML object trees."

class
    TOMELLE_MODEL_BUILDER

feature -- Status

    can_put (a_root: TOMELLE_TABLE; a_path: TOMELLE_PATH): BOOLEAN
        require
            path_not_empty: a_path.count > 0
        local
            i: INTEGER
            l_table: TOMELLE_TABLE
        do
            Result := True
            l_table := a_root
            from i := 1 until i >= a_path.count or else not Result loop
                if attached l_table [a_path [i]] as l_value then
                    if l_value.is_table then
                        l_table := l_value.as_table
                    else
                        Result := False
                    end
                end
                i := i + 1
            end
        end

    has (a_root: TOMELLE_TABLE; a_path: TOMELLE_PATH): BOOLEAN
        do
            Result := a_root.has (a_path)
        end

feature -- Construction

    new_parser_string (a_encoded_value: STRING_32): TOMELLE_VALUE
            -- String value from the parser's compiler-neutral encoding.
        do
            create Result.make_parser_string (a_encoded_value)
        ensure
            correct_type: Result.is_string
        end

    put_owned (a_root: TOMELLE_TABLE; a_value: TOMELLE_VALUE; a_path: TOMELLE_PATH)
        require
            path_not_empty: a_path.count > 0
            path_compatible: can_put (a_root, a_path)
        local
            i: INTEGER
            l_table, l_new_table: TOMELLE_TABLE
            l_wrapper: TOMELLE_VALUE
        do
            l_table := a_root
            from i := 1 until i >= a_path.count loop
                if attached l_table [a_path [i]] as l_value then
                    l_table := l_value.as_table
                else
                    create l_new_table.make
                    create l_wrapper.make_table (l_new_table)
                    l_table.put_owned (l_wrapper, a_path [i])
                    l_table := l_wrapper.as_table
                end
                i := i + 1
            end
            l_table.put_owned (a_value, a_path [a_path.count])
        ensure
            stored: a_root.has (a_path)
        end

end
