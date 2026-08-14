note
    description: "Whitespace retained in a TOML document."

class
    TOMELLE_WHITESPACE

inherit
    TOMELLE_ITEM

create
    make

feature {NONE} -- Initialization

    make (a_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            text := a_text.as_string_32.twin
            trivia.set_trail ("")
        end

feature -- Access

    text: STRING_32

    representation: STRING_32
        do
            Result := text.twin
        end

end
