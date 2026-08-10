note
    description: "Reusable stateful TOML parser facade."

class
    TOMELLE_PARSER

create
    make

feature {NONE} -- Initialization

    make
        do
            create error_collector.make
            create document_builder.make (error_collector)
        ensure
            not_parsed: not is_parsed
            no_document: document = Void
            no_errors: error_count = 0
        end

feature -- Parsing

    parse_string (a_source: READABLE_STRING_GENERAL)
        do
            if attached {STRING_32} a_source as l_source then
                parse_text (l_source, Void)
            else
                parse_text (a_source.as_string_32, Void)
            end
        ensure
            parsed: is_parsed
            result_consistent: is_successful = attached document
        end

    parse_file (a_path: PATH)
        require
            path_not_empty: not a_path.is_empty
        local
            l_text: detachable STRING_32
        do
            reset
            if source_reader.is_readable (a_path) then
                l_text := source_reader.decoded_file (a_path)
                if attached l_text as t then
                    parse_text (t, a_path.name)
                else
                    is_parsed := True
                    error_collector.add (error_codes.invalid_utf_8,
                        "Input is not valid UTF-8", a_path.name, 1, 1)
                end
            else
                is_parsed := True
                error_collector.add (error_codes.input_unreadable,
                    "Input file is missing or unreadable", a_path.name, 1, 1)
            end
        rescue
            reset
            is_parsed := True
            error_collector.add (error_codes.input_unreadable,
                "Unable to read input file", a_path.name, 1, 1)
        end

    reset
        do
            document := Void
            error_collector.reset
            is_parsed := False
        end

feature -- Status report

    is_parsed: BOOLEAN

    is_successful: BOOLEAN
        do
            Result := is_parsed and then not has_error
        end

    has_error: BOOLEAN
        do
            Result := error_collector.has_error
        end

feature -- Result

    document: detachable TOMELLE_DOCUMENT

    error_count: INTEGER
        do
            Result := error_collector.count
        end

    error (a_index: INTEGER): TOMELLE_PARSE_ERROR
        require
            valid_index: 1 <= a_index and a_index <= error_count
        do
            Result := error_collector.error (a_index)
        end

    errors: ITERABLE [TOMELLE_PARSE_ERROR]
        do
            Result := error_collector.errors
        end

feature {NONE} -- Pipeline

    parse_text (a_source: STRING_32; a_source_name: detachable READABLE_STRING_GENERAL)
        local
            l_candidate: TOMELLE_DOCUMENT
        do
            reset
            is_parsed := True
            error_collector.set_source_name (a_source_name)
            create l_candidate.make
            if source_validator.is_valid (a_source) then
                document_builder.build (a_source, l_candidate)
            else
                error_collector.add (error_codes.invalid_syntax,
                    "Invalid control character", Void, 1, 1)
            end
            if not has_error then
                document := l_candidate
            end
        end

feature {NONE} -- Dependencies

    error_collector: TOMELLE_ERROR_COLLECTOR
    document_builder: TOMELLE_DOCUMENT_BUILDER

    source_reader: TOMELLE_SOURCE_READER
        once
            create Result
        end

    source_validator: TOMELLE_SOURCE_VALIDATOR
        once
            create Result
        end

    error_codes: TOMELLE_ERROR_CODE
        once
            create Result.default_create
        end

invariant
    not_parsed_has_no_document: not is_parsed implies document = Void
    not_parsed_has_no_errors: not is_parsed implies error_count = 0
    successful_has_document: is_successful implies attached document
    unsuccessful_has_no_document: is_parsed and then not is_successful implies document = Void

end
