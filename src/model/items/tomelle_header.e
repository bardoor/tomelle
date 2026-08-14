note
    description: "Lossless table or array-of-tables header in document order."

class
    TOMELLE_HEADER

inherit
    TOMELLE_ITEM

create
    make

feature {NONE} -- Initialization

    make (a_source: READABLE_STRING_GENERAL; a_is_array: BOOLEAN)
        do
            initialize_item
            source := a_source.as_string_32.twin
            is_array := a_is_array
        end

feature -- Access

    source: STRING_32
    is_array: BOOLEAN

    representation: STRING_32
        do
            Result := source.twin
        end

end
