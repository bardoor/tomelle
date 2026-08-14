note
    description: "Lossless item in a TOML document."

deferred class
    TOMELLE_ITEM

feature -- Access

    trivia: TOMELLE_TRIVIA

    representation: STRING_32
        deferred
        end

feature -- Comparison

    has_same_representation (other: TOMELLE_ITEM): BOOLEAN
        do
            Result := representation.same_string (other.representation)
        end

feature {TOMELLE_ITEM, TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Initialization

    initialize_item
        do
            create trivia.make
        end

    set_trivia (a_trivia: TOMELLE_TRIVIA)
        do
            trivia := a_trivia.independent_copy
        end

end
