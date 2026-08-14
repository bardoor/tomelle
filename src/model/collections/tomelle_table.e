note
    description: "Mutable mapping from Unicode TOML keys to values."

class
    TOMELLE_TABLE

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
            create internal_keys.make (0)
            create internal_values.make (0)
        ensure
            empty: is_empty
        end

feature -- Access

    item alias "[]" (a_key: READABLE_STRING_GENERAL): detachable TOMELLE_VALUE
        local i: INTEGER
        do
            i := index_of (a_key)
            if i > 0 then
                Result := internal_values [i]
            end
        end

    value (a_path: TOMELLE_PATH): detachable TOMELLE_VALUE
        local
            i: INTEGER
            l_value: detachable TOMELLE_VALUE
        do
            if a_path.count > 0 then
                l_value := item (a_path [1])
                from i := 2 until i > a_path.count or else l_value = Void loop
                    if attached l_value as v and then v.is_table then
                        l_value := v.as_table [a_path [i]]
                    else
                        l_value := Void
                    end
                    i := i + 1
                end
                Result := l_value
            end
        end

    value_at (a_key_expression: READABLE_STRING_GENERAL): detachable TOMELLE_VALUE
        local l_path: TOMELLE_PATH
        do
            create l_path.make_from_key_expression (a_key_expression)
            Result := value (l_path)
        end

    keys: ITERABLE [READABLE_STRING_32]
        local
            l_snapshot: ARRAYED_LIST [READABLE_STRING_32]
        do
            create l_snapshot.make (internal_keys.count)
            across internal_keys as l_key loop
                l_snapshot.extend (l_key.twin)
            end
            Result := l_snapshot
        end

feature -- Measurement

    count: INTEGER
        do
            Result := internal_keys.count
        end

    is_empty: BOOLEAN
        do
            Result := count = 0
        end

feature -- Status report

    has_key (a_key: READABLE_STRING_GENERAL): BOOLEAN
        do
            Result := index_of (a_key) > 0
        end

    has (a_path: TOMELLE_PATH): BOOLEAN
        do
            Result := value (a_path) /= Void
        end

    has_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
        do
            Result := value_at (a_key_expression) /= Void
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        do
            Result := count = other.count
            across internal_keys as l_key until not Result loop
                Result := attached item (l_key) as l_value and then
                    attached other.item (l_key) as l_other and then
                    l_value.is_equal (l_other)
            end
        end

feature -- Modification

    put (a_value: TOMELLE_VALUE; a_key: READABLE_STRING_GENERAL)
        require key_not_empty: not a_key.is_empty
        local
            i: INTEGER
            l_key: STRING_32
        do
            i := index_of (a_key)
            if i > 0 then
                internal_values.put_i_th (a_value.cloned_value, i)
            else
                l_key := a_key.as_string_32.twin
                internal_keys.extend (l_key)
                internal_values.extend (a_value.cloned_value)
            end
        ensure stored: attached item (a_key)
        end

    put_string (a_value: READABLE_STRING_GENERAL; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_string (a_value)
            put_owned (l_value, a_key)
        end

    put_integer (a_value: INTEGER_64; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_integer (a_value)
            put_owned (l_value, a_key)
        end

    put_float (a_value: REAL_64; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_float (a_value)
            put_owned (l_value, a_key)
        end

    put_boolean (a_value: BOOLEAN; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_boolean (a_value)
            put_owned (l_value, a_key)
        end

    put_local_date (a_value: TOMELLE_LOCAL_DATE; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_local_date (a_value)
            put_owned (l_value, a_key)
        end

    put_local_time (a_value: TOMELLE_LOCAL_TIME; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_local_time (a_value)
            put_owned (l_value, a_key)
        end

    put_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_local_date_time (a_value)
            put_owned (l_value, a_key)
        end

    put_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_offset_date_time (a_value)
            put_owned (l_value, a_key)
        end

    put_table (a_value: TOMELLE_TABLE; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_table (a_value)
            put_owned (l_value, a_key)
        end

    put_array (a_value: TOMELLE_ARRAY; a_key: READABLE_STRING_GENERAL)
        local
            l_value: TOMELLE_VALUE
        do
            create l_value.make_array (a_value)
            put_owned (l_value, a_key)
        end

    remove (a_key: READABLE_STRING_GENERAL)
        local i: INTEGER
        do
            i := index_of (a_key)
            if i > 0 then
                internal_keys.go_i_th (i)
                internal_keys.remove
                internal_values.go_i_th (i)
                internal_values.remove
            end
        ensure absent: not has_key (a_key)
        end

    wipe_out
        do
            internal_keys.wipe_out
            internal_values.wipe_out
        ensure
            empty: is_empty
        end

feature {TOMELLE_DOCUMENT, TOMELLE_MODEL_BUILDER} -- Implementation

    put_owned (a_value: TOMELLE_VALUE; a_key: READABLE_STRING_GENERAL)
            -- Store a value already owned by this model without another copy.
        require key_not_empty: not a_key.is_empty
        local i: INTEGER
        do
            i := index_of (a_key)
            if i > 0 then internal_values.put_i_th (a_value, i)
            else
                internal_keys.extend (a_key.as_string_32.twin)
                internal_values.extend (a_value)
            end
        end

feature {TOMELLE_VALUE, TOMELLE_DOCUMENT} -- Copying

    cloned_table: TOMELLE_TABLE
        do
            create Result.make
            across internal_keys as l_key loop
                check attached item (l_key) as l_value then
                    Result.put (l_value, l_key)
                end
            end
        end

feature {NONE} -- Storage

    internal_keys: ARRAYED_LIST [READABLE_STRING_32]
    internal_values: ARRAYED_LIST [TOMELLE_VALUE]

    index_of (a_key: READABLE_STRING_GENERAL): INTEGER
        local i: INTEGER
        do
            from i := 1 until i > internal_keys.count or else Result > 0 loop
                if internal_keys [i].same_string_general (a_key) then
                    Result := i
                end
                i := i + 1
            end
        end

invariant
    same_count: internal_keys.count = internal_values.count

end
