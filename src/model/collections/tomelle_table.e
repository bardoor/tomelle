note
    description: "Ordered TOML mapping backed by lossless entries and a semantic key index."

class
    TOMELLE_TABLE

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
            create internal_entries.make (0)
            create semantic_index.make (0)
        ensure
            empty: is_empty
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
                    Result.append (internal_entries [i].value.representation)
                    i := i + 1
                end
                Result.append (l_segments [l_segments.count])
            else
                Result := canonical_representation
            end
        end

    canonical_representation: STRING_32
        local
            l_first: BOOLEAN
        do
            create Result.make_from_string ("{")
            l_first := True
            across internal_entries as l_entry loop
                if l_first then l_first := False else Result.append (", ") end
                Result.append (l_entry.key.representation)
                Result.append (l_entry.key.separator)
                Result.append (l_entry.value.representation)
            end
            Result.extend ('}')
        end

feature {TOMELLE_TABLE, TOMELLE_CONTAINER_PARSER} -- Parsed representation

    set_source_representation (a_source: READABLE_STRING_GENERAL)
        do
            source_model_representation := canonical_representation
            source_representation := a_source.as_string_32.twin
        ensure
            preserved: representation.same_string_general (a_source)
        end

    set_parsed_representation (a_source, a_sanitized_source: STRING_32)
            -- Preserve inline-table text around each direct value.
        local
            i, l_start, l_index: INTEGER
            l_segments: ARRAYED_LIST [STRING_32]
            l_value_text, l_empty: STRING_32
        do
            set_source_representation (a_source)
            sanitized_source_representation := a_sanitized_source.twin
            create l_segments.make (count + 1)
            l_start := 1
            from i := 1 until i > count or else l_start = 0 loop
                l_value_text := internal_entries [i].value.representation
                l_index := a_sanitized_source.substring_index (l_value_text, l_start)
                if l_index > 0 then
                    if l_index > l_start then
                        l_segments.extend (a_source.substring (l_start, l_index - 1))
                    else
                        create l_empty.make_empty
                        l_segments.extend (l_empty)
                    end
                    l_start := l_index + l_value_text.count
                else
                    l_start := 0
                end
                i := i + 1
            end
            if l_start > 0 then
                if l_start <= a_source.count then
                    l_segments.extend (a_source.substring (l_start, a_source.count))
                else
                    create l_empty.make_empty
                    l_segments.extend (l_empty)
                end
                source_segments := l_segments
            end
        end

feature -- Access

    item alias "[]" (a_key: READABLE_STRING_GENERAL): detachable TOMELLE_VALUE
        do
            if attached entry (a_key) as l_entry then
                Result := l_entry.value
            end
        end

    entry (a_key: READABLE_STRING_GENERAL): detachable TOMELLE_ENTRY
        do
            semantic_index.search (a_key.as_string_32)
            if semantic_index.found then
                Result := semantic_index.found_item
            end
        end

    entries: ITERABLE [TOMELLE_ENTRY]
            -- Entries in source/insertion order.
        do
            Result := internal_entries
        end

    value (a_path: TOMELLE_PATH): detachable TOMELLE_VALUE
        local
            i: INTEGER
            l_value: detachable TOMELLE_VALUE
        do
            if a_path.count > 0 then
                l_value := item (a_path [1])
                from i := 2 until i > a_path.count or else l_value = Void loop
                    if attached {TOMELLE_TABLE} l_value as l_table then
                        l_value := l_table [a_path [i]]
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
            create l_snapshot.make (count)
            across internal_entries as l_entry loop
                l_snapshot.extend (l_entry.key.value.twin)
            end
            Result := l_snapshot
        end

feature -- Measurement

    count: INTEGER
        do
            Result := internal_entries.count
        end

    is_empty: BOOLEAN
        do
            Result := internal_entries.is_empty
        end

feature -- Status report

    has_key (a_key: READABLE_STRING_GENERAL): BOOLEAN
        do
            semantic_index.search (a_key.as_string_32)
            Result := semantic_index.found
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
            across internal_entries as l_entry until not Result loop
                Result := attached other.item (l_entry.key.value) as l_other and then
                    l_entry.value.is_equal (l_other)
            end
        end

feature -- Modification

    put (a_value: TOMELLE_VALUE; a_key: READABLE_STRING_GENERAL)
        do
            put_owned (a_value.cloned_value, a_key)
        ensure
            stored: attached item (a_key)
            stable_count: old has_key (a_key) implies count = old count
        end

    put_string (a_value: READABLE_STRING_GENERAL; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_STRING
        do
            if attached {TOMELLE_STRING} item (a_key) as l_existing then
                l_existing.set_value (a_value)
            else
                create l_value.make (a_value)
                put_owned (l_value, a_key)
            end
        end

    put_integer (a_value: INTEGER_64; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_INTEGER
        do
            if attached {TOMELLE_INTEGER} item (a_key) as l_existing then
                l_existing.set_value (a_value)
            else
                create l_value.make (a_value)
                put_owned (l_value, a_key)
            end
        end

    put_float (a_value: REAL_64; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_FLOAT
        do
            if attached {TOMELLE_FLOAT} item (a_key) as l_existing then
                l_existing.set_value (a_value)
            else
                create l_value.make (a_value)
                put_owned (l_value, a_key)
            end
        end

    put_boolean (a_value: BOOLEAN; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_BOOLEAN
        do
            if attached {TOMELLE_BOOLEAN} item (a_key) as l_existing then
                l_existing.set_value (a_value)
            else
                create l_value.make (a_value)
                put_owned (l_value, a_key)
            end
        end

    put_local_date (a_value: TOMELLE_LOCAL_DATE; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_LOCAL_DATE_VALUE
        do
            create l_value.make (a_value)
            put_owned (l_value, a_key)
        end

    put_local_time (a_value: TOMELLE_LOCAL_TIME; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_LOCAL_TIME_VALUE
        do
            create l_value.make (a_value)
            put_owned (l_value, a_key)
        end

    put_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_LOCAL_DATE_TIME_VALUE
        do
            create l_value.make (a_value)
            put_owned (l_value, a_key)
        end

    put_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME; a_key: READABLE_STRING_GENERAL)
        local l_value: TOMELLE_OFFSET_DATE_TIME_VALUE
        do
            create l_value.make (a_value)
            put_owned (l_value, a_key)
        end

    put_table (a_value: TOMELLE_TABLE; a_key: READABLE_STRING_GENERAL)
        do
            put_owned (a_value.cloned_value, a_key)
        end

    put_array (a_value: TOMELLE_ARRAY; a_key: READABLE_STRING_GENERAL)
        do
            put_owned (a_value.cloned_value, a_key)
        end

    remove (a_key: READABLE_STRING_GENERAL)
        local
            l_entry: detachable TOMELLE_ENTRY
        do
            l_entry := entry (a_key)
            if attached l_entry then
                internal_entries.prune_all (l_entry)
                semantic_index.remove (a_key.as_string_32)
            end
        ensure
            absent: not has_key (a_key)
        end

    wipe_out
        do
            internal_entries.wipe_out
            semantic_index.wipe_out
        ensure
            empty: is_empty
        end

feature {TOMELLE_TABLE, TOMELLE_DOCUMENT, TOMELLE_MODEL_BUILDER, TOMELLE_DOCUMENT_BUILDER} -- Owned construction

    put_owned (a_value: TOMELLE_VALUE; a_key: READABLE_STRING_GENERAL)
            -- Store `a_value` without copying; retain an existing key's spelling and position.
        local
            l_key: TOMELLE_KEY
            l_entry: TOMELLE_ENTRY
        do
            if attached entry (a_key) as l_existing then
                l_existing.replace (a_value)
            else
                create l_key.make (a_key)
                create l_entry.make (l_key, a_value)
                put_entry_owned (l_entry)
            end
        ensure
            stored_identity: item (a_key) = a_value
        end

    put_entry_owned (a_entry: TOMELLE_ENTRY)
            -- Append a new lossless entry and index it by semantic key.
        require
            new_key: not has_key (a_entry.key.value)
        do
            internal_entries.extend (a_entry)
            semantic_index.force (a_entry, a_entry.key.value.twin)
        ensure
            one_more: count = old count + 1
            indexed: entry (a_entry.key.value) = a_entry
        end

feature {TOMELLE_VALUE, TOMELLE_DOCUMENT} -- Copying

    cloned_value: TOMELLE_VALUE
        do
            Result := cloned_table
            Result.set_trivia (trivia)
        end

    cloned_table: TOMELLE_TABLE
        do
            create Result.make
            across internal_entries as l_entry loop
                Result.put_entry_owned (l_entry.independent_copy)
            end
            if attached source_representation as l_source then
                if attached sanitized_source_representation as l_sanitized then
                    Result.set_parsed_representation (l_source, l_sanitized)
                else
                    Result.set_source_representation (l_source)
                end
            end
        end

feature {NONE} -- Storage

    internal_entries: ARRAYED_LIST [TOMELLE_ENTRY]
    semantic_index: HASH_TABLE [TOMELLE_ENTRY, STRING_32]
    source_representation: detachable STRING_32
    source_model_representation: detachable STRING_32
    sanitized_source_representation: detachable STRING_32
    source_segments: detachable ARRAYED_LIST [STRING_32]

invariant
    index_complete: semantic_index.count = internal_entries.count

end
