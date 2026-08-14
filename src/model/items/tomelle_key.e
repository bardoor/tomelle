note
    description: "Semantic TOML key with its source representation and separator."

class
    TOMELLE_KEY

inherit
    ANY
        redefine
            is_equal
        end

create
    make,
    make_parsed

feature {NONE} -- Initialization

    make (a_value: READABLE_STRING_GENERAL)
        do
            value := a_value.as_string_32.twin
            representation := canonical_representation (value)
            create separator.make_from_string (" = ")
        end

    make_parsed (a_value, a_representation, a_separator: READABLE_STRING_GENERAL)
        do
            value := a_value.as_string_32.twin
            representation := a_representation.as_string_32.twin
            separator := a_separator.as_string_32.twin
        end

feature -- Access

    value: STRING_32
    representation: STRING_32
    separator: STRING_32

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        do
            Result := value.same_string (other.value)
        end

feature -- Copying

    independent_copy: TOMELLE_KEY
        do
            create Result.make_parsed (value, representation, separator)
        ensure
            independent: Result /= Current
            same_representation: has_same_representation (Result)
        end

    has_same_representation (other: like Current): BOOLEAN
        do
            Result := is_equal (other) and then representation.same_string (other.representation) and then
                separator.same_string (other.separator)
        end

feature {NONE} -- Rendering

    canonical_representation (a_value: STRING_32): STRING_32
        local
            i: INTEGER
            l_bare: BOOLEAN
        do
            l_bare := not a_value.is_empty
            from i := 1 until i > a_value.count or else not l_bare loop
                l_bare := ('a' <= a_value [i] and a_value [i] <= 'z') or else
                    ('A' <= a_value [i] and a_value [i] <= 'Z') or else
                    ('0' <= a_value [i] and a_value [i] <= '9') or else
                    a_value [i] = '-' or else a_value [i] = '_'
                i := i + 1
            end
            if l_bare then
                Result := a_value.twin
            else
                create Result.make (a_value.count + 2)
                Result.extend ('%"')
                from i := 1 until i > a_value.count loop
                    inspect a_value [i]
                    when '%"' then Result.append ("\%"")
                    when '\' then Result.append ("\\")
                    else Result.extend (a_value [i])
                    end
                    i := i + 1
                end
                Result.extend ('%"')
            end
        end

end
