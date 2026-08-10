note
    description: "Tracks table definitions needed for TOML conflict validation."

class
    TOMELLE_DEFINITION_REGISTRY

create
    make

feature {NONE} -- Initialization

    make
        do
            create explicit_tables.make (0)
            explicit_tables.compare_objects
            create dotted_tables.make (0)
            dotted_tables.compare_objects
            create sealed_tables.make (0)
            sealed_tables.compare_objects
            create array_tables.make (0)
            array_tables.compare_objects
        end

feature -- Status

    is_explicit (a_key: STRING_32): BOOLEAN do Result := explicit_tables.has (a_key) end
    is_dotted (a_key: STRING_32): BOOLEAN do Result := dotted_tables.has (a_key) end
    is_sealed (a_key: STRING_32): BOOLEAN do Result := sealed_tables.has (a_key) end
    is_array (a_key: STRING_32): BOOLEAN do Result := array_tables.has (a_key) end

feature -- Change

    mark_explicit (a_key: STRING_32) do add_once (explicit_tables, a_key) end
    mark_dotted (a_key: STRING_32) do add_once (dotted_tables, a_key) end
    mark_sealed (a_key: STRING_32) do add_once (sealed_tables, a_key) end
    mark_array (a_key: STRING_32) do add_once (array_tables, a_key) end

    reset
        do
            explicit_tables.wipe_out
            dotted_tables.wipe_out
            sealed_tables.wipe_out
            array_tables.wipe_out
        end

    reset_explicit_descendants (a_prefix: STRING_32)
        local i: INTEGER
        do
            from i := explicit_tables.count until i < 1 loop
                if explicit_tables [i].starts_with (a_prefix) and then
                    not explicit_tables [i].same_string (a_prefix)
                then
                    explicit_tables.go_i_th (i)
                    explicit_tables.remove
                end
                i := i - 1
            end
        end

feature {NONE} -- Implementation

    add_once (a_items: ARRAYED_LIST [STRING_32]; a_key: STRING_32)
        do
            if not a_items.has (a_key) then a_items.extend (a_key.twin) end
        end

    explicit_tables: ARRAYED_LIST [STRING_32]
    dotted_tables: ARRAYED_LIST [STRING_32]
    sealed_tables: ARRAYED_LIST [STRING_32]
    array_tables: ARRAYED_LIST [STRING_32]

end
