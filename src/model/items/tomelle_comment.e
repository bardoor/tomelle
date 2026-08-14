note
    description: "Standalone TOML comment."

class
    TOMELLE_COMMENT

inherit
    TOMELLE_ITEM

create
    make

feature {NONE} -- Initialization

    make (a_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            text := a_text.as_string_32.twin
        end

feature -- Access

    text: STRING_32

    representation: STRING_32
        do
            Result := text.twin
        end

end
