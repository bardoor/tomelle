note
    description: "Minimal JSON value used by the toml-test adapter."

class
    TOML_TEST_JSON_VALUE

create
    make_string,
    make_array,
    make_object

feature {NONE} -- Initialization

    make_string (a_value: READABLE_STRING_GENERAL)
        do
            kind := string_kind
            string_value := a_value.as_string_32.twin
            create array_values.make (0)
            create object_keys.make (0)
            create object_values.make (0)
        end

    make_array
        do
            kind := array_kind
            create array_values.make (0)
            create object_keys.make (0)
            create object_values.make (0)
        end

    make_object
        do
            kind := object_kind
            create array_values.make (0)
            create object_keys.make (0)
            create object_values.make (0)
        end

feature -- Type report

    is_string: BOOLEAN do Result := kind = string_kind end
    is_array: BOOLEAN do Result := kind = array_kind end
    is_object: BOOLEAN do Result := kind = object_kind end

feature -- Access

    as_string: STRING_32
        require is_string: is_string
        do
            check attached string_value as l_value then Result := l_value end
        end

    array_values: ARRAYED_LIST [TOML_TEST_JSON_VALUE]
    object_keys: ARRAYED_LIST [STRING_32]
    object_values: ARRAYED_LIST [TOML_TEST_JSON_VALUE]

    object_value (a_key: READABLE_STRING_GENERAL): detachable TOML_TEST_JSON_VALUE
        require is_object: is_object
        local i: INTEGER
        do
            from i := 1 until i > object_keys.count or else Result /= Void loop
                if object_keys [i].same_string_general (a_key) then
                    Result := object_values [i]
                end
                i := i + 1
            end
        end

feature -- Modification

    extend_array (a_value: TOML_TEST_JSON_VALUE)
        require is_array: is_array
        do
            array_values.extend (a_value)
        end

    put_object (a_value: TOML_TEST_JSON_VALUE; a_key: READABLE_STRING_GENERAL)
        require
            is_object: is_object
            new_key: object_value (a_key) = Void
        do
            object_keys.extend (a_key.as_string_32.twin)
            object_values.extend (a_value)
        end

feature {NONE} -- Implementation

    kind: INTEGER
    string_value: detachable STRING_32
    string_kind: INTEGER = 1
    array_kind: INTEGER = 2
    object_kind: INTEGER = 3

invariant
    valid_kind: string_kind <= kind and kind <= object_kind
    object_storage_consistent: object_keys.count = object_values.count

end
