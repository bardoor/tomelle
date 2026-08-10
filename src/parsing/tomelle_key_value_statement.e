note
    description: "Parsed TOML key/value statement before value conversion."

class
    TOMELLE_KEY_VALUE_STATEMENT

inherit
    TOMELLE_STATEMENT

create
    make

feature {NONE} -- Initialization

    make (a_key_expression, a_value_text: STRING_32; a_position: TOMELLE_SOURCE_POSITION)
        require
            valid_key: key_syntax.is_valid_expression (a_key_expression)
        do
            key_expression := a_key_expression
            value_text := a_value_text
            create path.make_from_key_expression (a_key_expression)
            set_position (a_position)
        end

feature -- Access

    key_expression: STRING_32
    value_text: STRING_32
    path: TOMELLE_PATH

feature {NONE} -- Implementation

    key_syntax: TOMELLE_KEY_SYNTAX
        once create Result.make end

end
