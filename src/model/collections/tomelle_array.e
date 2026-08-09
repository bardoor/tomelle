note
    description: "Mutable ordered sequence of TOML values."

class
    TOMELLE_ARRAY

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
            create storage.make (0)
        ensure
            empty: is_empty
        end

feature -- Measurement

    count: INTEGER
        do
            Result := storage.count
        end

    is_empty: BOOLEAN
        do
            Result := storage.is_empty
        end

feature -- Access

    item alias "[]" (a_index: INTEGER): TOMELLE_VALUE
        require valid_index: valid_index (a_index)
        do
            Result := storage [a_index]
        end

    first: TOMELLE_VALUE
        require not_empty: not is_empty
        do
            Result := storage.first
        end

    last: TOMELLE_VALUE
        require not_empty: not is_empty
        do
            Result := storage.last
        end

    new_cursor: ITERATION_CURSOR [TOMELLE_VALUE]
        do
            Result := storage.new_cursor
        end

feature -- Status report

    valid_index (a_index: INTEGER): BOOLEAN
        do
            Result := 1 <= a_index and a_index <= count
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        local i: INTEGER
        do
            Result := count = other.count
            from i := 1 until i > count or else not Result loop
                Result := item (i).is_equal (other.item (i))
                i := i + 1
            end
        end

feature -- Modification

    extend (a_value: TOMELLE_VALUE)
        do
            storage.extend (a_value.cloned_value)
        ensure
            one_more: count = old count + 1
        end

    extend_string (a_value: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_string (a_value)
            storage.extend (l_value)
        end

    extend_integer (a_value: INTEGER_64)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_integer (a_value)
            storage.extend (l_value)
        end

    extend_float (a_value: REAL_64)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_float (a_value)
            storage.extend (l_value)
        end

    extend_boolean (a_value: BOOLEAN)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_boolean (a_value)
            storage.extend (l_value)
        end

    extend_local_date (a_value: TOMELLE_LOCAL_DATE)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_local_date (a_value)
            storage.extend (l_value)
        end

    extend_local_time (a_value: TOMELLE_LOCAL_TIME)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_local_time (a_value)
            storage.extend (l_value)
        end

    extend_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_local_date_time (a_value)
            storage.extend (l_value)
        end

    extend_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_offset_date_time (a_value)
            storage.extend (l_value)
        end

    extend_table (a_value: TOMELLE_TABLE)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_table (a_value)
            storage.extend (l_value)
        end

    extend_array (a_value: TOMELLE_ARRAY)
        local l_value: TOMELLE_VALUE
        do
            create l_value.make_array (a_value)
            storage.extend (l_value)
        end

    replace (a_value: TOMELLE_VALUE; a_index: INTEGER)
        require valid_index: valid_index (a_index)
        do
            storage.put_i_th (a_value.cloned_value, a_index)
        ensure
            same_count: count = old count
        end

    remove (a_index: INTEGER)
        require valid_index: valid_index (a_index)
        do
            storage.go_i_th (a_index)
            storage.remove
        ensure
            one_less: count = old count - 1
        end

    wipe_out
        do
            storage.wipe_out
        ensure
            empty: is_empty
        end

feature {TOMELLE_VALUE, TOMELLE_DOCUMENT, TOMELLE_TABLE} -- Copying

    cloned_array: TOMELLE_ARRAY
        do
            create Result.make
            across storage as l_value loop Result.extend (l_value) end
        end

feature {NONE} -- Storage

    storage: ARRAYED_LIST [TOMELLE_VALUE]

invariant
    non_negative_count: count >= 0

end
