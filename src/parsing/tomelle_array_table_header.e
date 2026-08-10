note
    description: "Parsed [[array-of-tables]] header."

class
    TOMELLE_ARRAY_TABLE_HEADER

inherit
    TOMELLE_STATEMENT

create
    make

feature {NONE} -- Initialization

    make (a_expression: STRING_32; a_position: TOMELLE_SOURCE_POSITION)
        require
            valid_key: key_syntax.is_valid_expression (a_expression)
        do
            expression := a_expression
            create path.make_from_key_expression (a_expression)
            set_position (a_position)
        end

feature -- Access

    expression: STRING_32
    path: TOMELLE_PATH

feature {NONE} -- Implementation

    key_syntax: TOMELLE_KEY_SYNTAX
        once create Result.make end

end
