note
    description: "Base type for lossless TOML values."

deferred class
    TOMELLE_VALUE

inherit
    TOMELLE_ITEM

feature {TOMELLE_ENTRY, TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Copying

    cloned_value: TOMELLE_VALUE
        deferred
        end

end
