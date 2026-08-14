note
    description: "Lossless TOML floating-point value."

class
    TOMELLE_FLOAT

inherit
    TOMELLE_VALUE
        redefine
            is_equal
        end

create
    make,
    make_from_source,
    make_canonical,
    make_parsed

feature {NONE} -- Initialization

    make (a_value: REAL_64)
        do
            initialize_item
            value := a_value
            canonical_text := float_codec.canonical_value (a_value)
            raw_text := canonical_text.twin
        end

    make_from_source (a_source: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := float_codec.parsed_value (a_source)
            canonical_text := float_codec.canonical_source (a_source)
            raw_text := a_source.as_string_32.twin
        end

    make_canonical (a_value: REAL_64; a_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value
            canonical_text := a_text.as_string_32.twin
            raw_text := canonical_text.twin
        end

    make_parsed (a_value: REAL_64; a_canonical_text, a_raw_text: READABLE_STRING_GENERAL)
        do
            initialize_item
            value := a_value
            canonical_text := a_canonical_text.as_string_32.twin
            raw_text := a_raw_text.as_string_32.twin
        end

feature -- Access

    value: REAL_64
    canonical_text: STRING_32
    raw_text: STRING_32

    representation: STRING_32 do Result := raw_text.twin end

feature -- Element change

    set_value (a_value: REAL_64)
        do
            value := a_value
            canonical_text := float_codec.canonical_value (a_value)
            raw_text := canonical_text.twin
        ensure
            set_or_nan: value = a_value or else (value.is_nan and a_value.is_nan)
        end

feature {TOMELLE_DOCUMENT, TOMELLE_TABLE, TOMELLE_ARRAY} -- Copying

    cloned_value: TOMELLE_VALUE
        local l_result: TOMELLE_FLOAT
        do
            create l_result.make_parsed (value, canonical_text, raw_text)
            l_result.set_trivia (trivia)
            Result := l_result
        end

feature -- Comparison

    is_equal (other: like Current): BOOLEAN
        do
            Result := value = other.value or else (value.is_nan and other.value.is_nan)
        end

feature {NONE} -- Implementation

    float_codec: TOMELLE_FLOAT_CODEC once create Result end

end
