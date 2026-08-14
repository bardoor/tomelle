note
    description: "Mutable ordered sequence of TOML values."

class
    TOMELLE_ARRAY

inherit
    TOMELLE_VALUE
        redefine
            is_equal
        end

create
    make

feature {NONE} -- Initialization

    make
        do
            initialize_item
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

    representation: STRING_32
        local
            i: INTEGER
        do
            if attached source_representation as l_source and then
                attached source_model_representation as l_model and then
                canonical_representation.same_string (l_model)
            then
                Result := l_source.twin
            elseif attached source_segments as l_segments and then l_segments.count = count + 1 then
                create Result.make_empty
                from i := 1 until i > count loop
                    Result.append (l_segments [i])
                    Result.append (item (i).representation)
                    i := i + 1
                end
                Result.append (l_segments [l_segments.count])
            else
                Result := canonical_representation
            end
        end

    canonical_representation: STRING_32
        local
            i: INTEGER
        do
            create Result.make_from_string ("[")
            from i := 1 until i > count loop
                if i > 1 then
                    Result.append (", ")
                end
                Result.append (item (i).representation)
                i := i + 1
            end
            Result.extend (']')
        end

feature {TOMELLE_ARRAY, TOMELLE_CONTAINER_PARSER} -- Parsed representation

    set_source_representation (a_source: READABLE_STRING_GENERAL)
        do
            source_model_representation := canonical_representation
            source_representation := a_source.as_string_32.twin
        ensure
            preserved: representation.same_string_general (a_source)
        end

    set_parsed_representation (a_source, a_sanitized_source: STRING_32)
            -- Preserve text around each parsed element for local mutations.
        local
            i, l_start, l_index: INTEGER
            l_segments: ARRAYED_LIST [STRING_32]
            l_element_text: STRING_32
        do
            set_source_representation (a_source)
            sanitized_source_representation := a_sanitized_source.twin
            create l_segments.make (count + 1)
            l_start := 1
            from i := 1 until i > count or else l_start = 0 loop
                l_element_text := item (i).representation
                l_index := a_sanitized_source.substring_index (l_element_text, l_start)
                if l_index > 0 then
                    if l_index > l_start then
                        l_segments.extend (a_source.substring (l_start, l_index - 1))
                    else
                        create l_element_text.make_empty
                        l_segments.extend (l_element_text)
                    end
                    l_start := l_index + item (i).representation.count
                else
                    l_start := 0
                end
                i := i + 1
            end
            if l_start > 0 then
                if l_start <= a_source.count then
                    l_segments.extend (a_source.substring (l_start, a_source.count))
                else
                    create l_element_text.make_empty
                    l_segments.extend (l_element_text)
                end
                source_segments := l_segments
            end
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
        local l_value: TOMELLE_STRING
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_integer (a_value: INTEGER_64)
        local l_value: TOMELLE_INTEGER
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_float (a_value: REAL_64)
        local l_value: TOMELLE_FLOAT
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_boolean (a_value: BOOLEAN)
        local l_value: TOMELLE_BOOLEAN
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_local_date (a_value: TOMELLE_LOCAL_DATE)
        local l_value: TOMELLE_LOCAL_DATE_VALUE
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_local_time (a_value: TOMELLE_LOCAL_TIME)
        local l_value: TOMELLE_LOCAL_TIME_VALUE
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME)
        local l_value: TOMELLE_LOCAL_DATE_TIME_VALUE
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME)
        local l_value: TOMELLE_OFFSET_DATE_TIME_VALUE
        do
            create l_value.make (a_value)
            storage.extend (l_value)
        end

    extend_table (a_value: TOMELLE_TABLE)
        do
            storage.extend (a_value.cloned_value)
        end

    extend_array (a_value: TOMELLE_ARRAY)
        do
            storage.extend (a_value.cloned_value)
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

    cloned_value: TOMELLE_VALUE
        do
            Result := cloned_array
            Result.set_trivia (trivia)
        end

    cloned_array: TOMELLE_ARRAY
        do
            create Result.make
            across storage as l_value loop Result.extend (l_value) end
            if attached source_representation as l_source then
                if attached sanitized_source_representation as l_sanitized then
                    Result.set_parsed_representation (l_source, l_sanitized)
                else
                    Result.set_source_representation (l_source)
                end
            end
        end

feature {NONE} -- Storage

    storage: ARRAYED_LIST [TOMELLE_VALUE]
    source_representation: detachable STRING_32
    source_model_representation: detachable STRING_32
    sanitized_source_representation: detachable STRING_32
    source_segments: detachable ARRAYED_LIST [STRING_32]

invariant
    non_negative_count: count >= 0

end
