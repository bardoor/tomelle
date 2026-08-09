note
    description: "Immutable byte, line, and column position in TOML input."

expanded class
    TOMELLE_SOURCE_POSITION

inherit
    ANY
        redefine
            default_create
        end

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
        do
            byte_offset := 0
            line := 1
            column := 1
        ensure then
            start_position: byte_offset = 0 and line = 1 and column = 1
        end

    make (a_byte_offset, a_line, a_column: INTEGER)
        require
            non_negative_byte_offset: a_byte_offset >= 0
            positive_line: a_line >= 1
            positive_column: a_column >= 1
        do
            byte_offset := a_byte_offset
            line := a_line
            column := a_column
        ensure
            byte_offset_set: byte_offset = a_byte_offset
            line_set: line = a_line
            column_set: column = a_column
        end

feature -- Access

    byte_offset: INTEGER
    line: INTEGER
    column: INTEGER

invariant
    non_negative_byte_offset: byte_offset >= 0
    positive_line: line >= 1
    positive_column: column >= 1

end
