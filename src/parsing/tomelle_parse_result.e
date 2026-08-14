note
    description: "Explicit document parsing outcome."

class
    TOMELLE_PARSE_RESULT

create
    make_success,
    make_failure

feature {NONE} -- Initialization

    make_success (a_document: TOMELLE_DOCUMENT)
        do
            document := a_document
            create internal_errors.make (0)
        ensure
            successful: is_successful
        end

    make_failure (a_errors: ITERABLE [TOMELLE_PARSE_ERROR])
        do
            create internal_errors.make (1)
            across a_errors as l_error loop
                internal_errors.extend (l_error)
            end
        ensure
            failed: has_error
        end

feature -- Outcome

    document: detachable TOMELLE_DOCUMENT

    is_successful: BOOLEAN
        do
            Result := attached document
        end

    has_error: BOOLEAN
        do
            Result := not internal_errors.is_empty
        end

feature -- Errors

    error_count: INTEGER
        do
            Result := internal_errors.count
        end

    error (a_index: INTEGER): TOMELLE_PARSE_ERROR
        require
            valid_index: 1 <= a_index and a_index <= error_count
        do
            Result := internal_errors [a_index]
        end

    errors: ITERABLE [TOMELLE_PARSE_ERROR]
        local
            l_snapshot: ARRAYED_LIST [TOMELLE_PARSE_ERROR]
        do
            create l_snapshot.make (error_count)
            across internal_errors as l_error loop l_snapshot.extend (l_error) end
            Result := l_snapshot
        end

feature {NONE} -- Storage

    internal_errors: ARRAYED_LIST [TOMELLE_PARSE_ERROR]

invariant
    exclusive_outcome: is_successful /= has_error

end
