note
    description: "A complete TOML statement with its physical source position."

class
    TOMELLE_LOGICAL_LINE

create
    make

feature {NONE} -- Initialization

    make (a_text: STRING_32; a_line, a_column: INTEGER)
        require
            positive_line: a_line > 0
            positive_column: a_column > 0
        do
            text := a_text
            create position.make (0, a_line, a_column)
        end

feature -- Access

    text: STRING_32
    position: TOMELLE_SOURCE_POSITION

end
