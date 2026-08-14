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
                    if attached {TOMELLE_TABLE} l_value as l_nested_table then
                        l_table := l_nested_table
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

    new_parser_string (a_encoded_value, a_source: STRING_32): TOMELLE_VALUE
            -- String value from the parser's compiler-neutral encoding.
        local
            l_decoded: TOMELLE_STRING
        do
            create l_decoded.make_parser_encoded (a_encoded_value)
            create {TOMELLE_STRING} Result.make_parsed (l_decoded.value, a_source)
        ensure
            correct_type: attached {TOMELLE_STRING} Result
        end

    put_owned (a_root: TOMELLE_TABLE; a_value: TOMELLE_VALUE; a_path: TOMELLE_PATH)
        require
            path_not_empty: a_path.count > 0
            path_compatible: can_put (a_root, a_path)
        local
            i: INTEGER
            l_table, l_new_table: TOMELLE_TABLE
        do
            l_table := a_root
            from i := 1 until i >= a_path.count loop
                if attached l_table [a_path [i]] as l_value then
                    check attached {TOMELLE_TABLE} l_value as l_nested_table then
                        l_table := l_nested_table
                    end
                else
                    create l_new_table.make
                    l_table.put_owned (l_new_table, a_path [i])
                    l_table := l_new_table
                end
                i := i + 1
            end
            l_table.put_owned (a_value, a_path [a_path.count])
        ensure
            stored: a_root.has (a_path)
        end

end
