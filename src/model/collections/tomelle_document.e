note
    description: "Mutable TOML document."

class
    TOMELLE_DOCUMENT

inherit
    ANY
        redefine
            is_equal
        end

create
    make

feature {NONE} -- Initialization

    make
        do
            create root.make
        ensure
            empty: is_empty
        end

feature -- Access

    root: TOMELLE_TABLE

    value (a_path: TOMELLE_PATH): detachable TOMELLE_VALUE
        do
            Result := root.value (a_path)
        end

    value_at (a_key_expression: READABLE_STRING_GENERAL): detachable TOMELLE_VALUE
        require valid_expression: is_valid_key_expression (a_key_expression)
        do
            Result := root.value_at (a_key_expression)
        end

    table_at (a_key_expression: READABLE_STRING_GENERAL): TOMELLE_TABLE
        require table_value: attached value_at (a_key_expression) as v and then v.is_table
        do
            check attached value_at (a_key_expression) as v then
                Result := v.as_table
            end
        end

    array_at (a_key_expression: READABLE_STRING_GENERAL): TOMELLE_ARRAY
        require array_value: attached value_at (a_key_expression) as v and then v.is_array
        do
            check attached value_at (a_key_expression) as v then
                Result := v.as_array
            end
        end

feature -- Status report

    has (a_path: TOMELLE_PATH): BOOLEAN
        do
            Result := root.has (a_path)
        end
    has_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
        require valid_expression: is_valid_key_expression (a_key_expression)
        do
            Result := root.has_at (a_key_expression)
        end

    is_empty: BOOLEAN
        do
            Result := root.is_empty
        end

    can_put (a_path: TOMELLE_PATH): BOOLEAN
        require path_not_empty: a_path.count > 0
        local
            i: INTEGER
            l_value: detachable TOMELLE_VALUE
            l_table: TOMELLE_TABLE
        do
            Result := True
            l_table := root
            from i := 1 until i >= a_path.count or else not Result loop
                l_value := l_table [a_path [i]]
                if attached l_value as v then
                    if v.is_table then
                        l_table := v.as_table
                    else
                        Result := False
                    end
                end
                i := i + 1
            end
        end

    can_put_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
        local l_path: TOMELLE_PATH
        do
            if key_syntax.is_valid_expression (a_key_expression) then
                create l_path.make_from_key_expression (a_key_expression)
                Result := can_put (l_path)
            end
        end

    is_valid_key_expression (a_expression: READABLE_STRING_GENERAL): BOOLEAN
        do
            Result := key_syntax.is_valid_expression (a_expression)
        end

feature -- General modification

    put (a_value: TOMELLE_VALUE; a_path: TOMELLE_PATH)
        require
            path_not_empty: a_path.count > 0
            path_compatible: can_put (a_path)
        do
            put_owned (a_value.cloned_value, a_path)
        ensure
            stored: attached value (a_path)
        end

    put_at (a_value: TOMELLE_VALUE; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local l_path: TOMELLE_PATH
        do
            create l_path.make_from_key_expression (a_key_expression)
            put (a_value, l_path)
        end

    remove (a_path: TOMELLE_PATH)
        local
            i: INTEGER
            l_table: TOMELLE_TABLE
            l_value: detachable TOMELLE_VALUE
            l_possible: BOOLEAN
        do
            if a_path.count > 0 then
                l_table := root
                l_possible := True
                from i := 1 until i >= a_path.count or else not l_possible loop
                    l_value := l_table [a_path [i]]
                    if attached l_value as v and then v.is_table then
                        l_table := v.as_table
                    else
                        l_possible := False
                    end
                    i := i + 1
                end
                if l_possible then
                    l_table.remove (a_path [a_path.count])
                end
            end
        ensure absent: not has (a_path)
        end

    remove_at (a_key_expression: READABLE_STRING_GENERAL)
        require valid_expression: is_valid_key_expression (a_key_expression)
        local l_path: TOMELLE_PATH
        do
            create l_path.make_from_key_expression (a_key_expression)
            remove (l_path)
        end

    wipe_out
        do
            root.wipe_out
        ensure
            empty: is_empty
        end

feature -- Typed modification

    put_string_at (a_value: READABLE_STRING_GENERAL; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_string (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_integer_at (a_value: INTEGER_64; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_integer (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_float_at (a_value: REAL_64; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_float (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_boolean_at (a_value: BOOLEAN; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_boolean (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_local_date_at (a_value: TOMELLE_LOCAL_DATE; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_local_date (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_local_time_at (a_value: TOMELLE_LOCAL_TIME; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_local_time (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_local_date_time_at (a_value: TOMELLE_LOCAL_DATE_TIME; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_local_date_time (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_offset_date_time_at (a_value: TOMELLE_OFFSET_DATE_TIME; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_offset_date_time (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_table_at (a_value: TOMELLE_TABLE; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_table (a_value)
            put_owned_at (v, a_key_expression)
        end
    put_array_at (a_value: TOMELLE_ARRAY; a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            v: TOMELLE_VALUE
        do
            create v.make_array (a_value)
            put_owned_at (v, a_key_expression)
        end

    make_table_at (a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            t: TOMELLE_TABLE
        do
            create t.make
            put_table_at (t, a_key_expression)
        end
    make_array_at (a_key_expression: READABLE_STRING_GENERAL)
        require path_compatible: can_put_at (a_key_expression)
        local
            a: TOMELLE_ARRAY
        do
            create a.make
            put_array_at (a, a_key_expression)
        end

feature -- Copying

    independent_copy: TOMELLE_DOCUMENT
        do
            create Result.make
            Result.set_root (root.cloned_table)
        ensure
            independent: Result /= Current
            equivalent: Result.is_equal (Current)
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        do
            Result := root.is_equal (other.root)
        end

feature {TOMELLE_PARSER, TOMELLE_DOCUMENT} -- Parser support

    set_root (a_root: TOMELLE_TABLE)
        do
            root := a_root
        end

feature {NONE} -- Implementation

    key_syntax: TOMELLE_KEY_SYNTAX
        once
            create Result.make
        end

    put_owned_at (a_value: TOMELLE_VALUE; a_expression: READABLE_STRING_GENERAL)
        local l_path: TOMELLE_PATH
        do
            create l_path.make_from_key_expression (a_expression)
            put_owned (a_value, l_path)
        end

    put_owned (a_value: TOMELLE_VALUE; a_path: TOMELLE_PATH)
        local
            i: INTEGER
            l_table, l_new_table: TOMELLE_TABLE
            l_wrapper: TOMELLE_VALUE
        do
            l_table := root
            from i := 1 until i >= a_path.count loop
                if attached l_table [a_path [i]] as v then
                    l_table := v.as_table
                else
                    create l_new_table.make
                    create l_wrapper.make_table (l_new_table)
                    l_table.put_owned (l_wrapper, a_path [i])
                    l_table := l_wrapper.as_table
                end
                i := i + 1
            end
            l_table.put_owned (a_value, a_path [a_path.count])
        end

end
