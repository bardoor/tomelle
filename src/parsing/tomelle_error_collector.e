note
    description: "Collects parser errors and applies the current source name."

class
    TOMELLE_ERROR_COLLECTOR

create
    make

feature {NONE} -- Initialization

    make
        do
            create internal_errors.make (0)
        end

feature -- Access

    count: INTEGER do Result := internal_errors.count end

    error (a_index: INTEGER): TOMELLE_PARSE_ERROR
        require valid_index: 1 <= a_index and a_index <= count
        do Result := internal_errors [a_index] end

    errors: ITERABLE [TOMELLE_PARSE_ERROR] do Result := internal_errors end

    has_error: BOOLEAN do Result := not internal_errors.is_empty end

feature -- Change

    set_source_name (a_name: detachable READABLE_STRING_GENERAL)
        do
            if attached a_name as l_name then source_name := l_name.as_string_32.twin else source_name := Void end
        end

    add (a_code: TOMELLE_ERROR_CODE; a_message: READABLE_STRING_GENERAL;
        a_source: detachable READABLE_STRING_GENERAL; a_line, a_column: INTEGER)
        local
            l_error: TOMELLE_PARSE_ERROR
            l_position: TOMELLE_SOURCE_POSITION
        do
            create l_position.make (0, a_line, a_column)
            if attached a_source as l_source then
                create l_error.make (a_code, a_message, l_source, l_position)
            else
                create l_error.make (a_code, a_message, source_name, l_position)
            end
            internal_errors.extend (l_error)
        end

    reset
        do
            internal_errors.wipe_out
            source_name := Void
        end

feature {NONE} -- Implementation

    internal_errors: ARRAYED_LIST [TOMELLE_PARSE_ERROR]
    source_name: detachable STRING_32

end
