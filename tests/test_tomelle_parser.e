note
    description: "Smoke tests for TOMELLE_PARSER"

class
    TEST_TOMELLE_PARSER

inherit
    TS_TEST_CASE

create
    make_default

feature -- Test

    test_new_parser_is_empty
            -- A new parser has no parse result or errors.
        local
            parser: TOMELLE_PARSER
        do
            create parser.make

            assert_false ("not parsed", parser.is_parsed)
            assert_false ("no error", parser.has_error)
            assert_false ("not successful", parser.is_successful)
            assert_true ("no document", parser.document = Void)
            assert_integers_equal ("no errors", 0, parser.error_count)
        end

    test_key_syntax_and_path
        local
            syntax: TOMELLE_KEY_SYNTAX
            path: TOMELLE_PATH
        do
            create syntax.make
            assert_true ("quoted dotted key valid", syntax.is_valid_expression ("server.%"physical.color%""))
            assert_false ("unterminated key invalid", syntax.is_valid_expression ("server.%"broken"))
            create path.make_from_key_expression ("server.%"physical.color%"")
            assert_integers_equal ("two keys", 2, path.count)
            assert_true ("literal dot preserved", path [2].same_string_general ("physical.color"))
            create path.make_from_key_expression ("%"caf\u00E9%"")
            assert_true ("unicode escape decoded", path [1].count = 4 and then path [1].code (4) = 233)
        end

    test_mutable_document
        local
            document, copied: TOMELLE_DOCUMENT
        do
            create document.make
            document.put_integer_at (8080, "server.port")
            document.put_string_at ("localhost", "server.host")
            assert_true ("integer stored", attached document.value_at ("server.port") as v and then v.is_integer and then v.as_integer = 8080)
            document.table_at ("server").put_boolean (True, "enabled")
            assert_true ("live nested table", attached document.value_at ("server.enabled") as v and then v.as_boolean)
            copied := document.independent_copy
            copied.put_integer_at (9090, "server.port")
            assert_true ("copy independent", attached document.value_at ("server.port") as v and then v.as_integer = 8080)
            document.remove_at ("server.host")
            document.remove_at ("server.host")
            assert_false ("idempotent removal", document.has_at ("server.host"))
        end

    test_parse_values
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("title = %"Tomelle%"%N[server]%Nport = 8080%Nenabled = true%Nvalues = [1, %"two%", false]%N")
            assert_true ("parse successful", parser.is_successful)
            assert_true ("title", attached parser.document as d and then attached d.value_at ("title") as v and then v.as_string.same_string_general ("Tomelle"))
            assert_true ("nested integer", attached parser.document as d and then attached d.value_at ("server.port") as v and then v.as_integer = 8080)
            assert_true ("array", attached parser.document as d and then attached d.value_at ("server.values") as v and then v.is_array and then v.as_array.count = 3)
        end

    test_duplicate_key_error
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("port = 1%Nport = 2%N")
            assert_true ("failed", parser.has_error)
            assert_true ("no partial document", parser.document = Void)
            assert_integers_equal ("duplicate code", 5, parser.error (1).code.value)
            assert_integers_equal ("second line", 2, parser.error (1).position.line)
        end

    test_serialize_round_trip
        local
            document: TOMELLE_DOCUMENT
            values: TOMELLE_ARRAY
            writer: TOMELLE_WRITER
            parser: TOMELLE_PARSER
            text: STRING_32
        do
            create document.make
            document.put_string_at ("hello", "message")
            create values.make
            values.extend_integer (1)
            values.extend_boolean (True)
            document.put_array_at (values, "values")
            create writer.make
            text := writer.serialized (document)
            create parser.make
            parser.parse_string (text)
            assert_true ("serialized text parses", parser.is_successful)
            assert_true ("round-trip array", attached parser.document as d and then attached d.value_at ("values") as v and then v.as_array.count = 2)
        end

    test_expanded_defaults_are_valid
        local
            date: TOMELLE_LOCAL_DATE
            position: TOMELLE_SOURCE_POSITION
            code: TOMELLE_ERROR_CODE
        do
            create date.default_create
            create position.default_create
            create code.default_create
            assert_true ("default date", date.month = 1 and date.day = 1)
            assert_true ("default position", position.line = 1 and position.column = 1)
            assert_integers_equal ("default error code", 1, code.value)
        end

    test_temporal_and_numeric_values
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string (
                "date = 2026-08-09%N" +
                "time = 12:34:56.1234%N" +
                "local = 2026-08-09T12:34:56%N" +
                "offset = 2026-08-09T12:34:56+03:00%N" +
                "hex = 0xDEAD_BEEF%N" +
                "special = inf%N")
            assert_true ("temporal parse", parser.is_successful)
            assert_true ("date type", attached parser.document as d and then attached d.value_at ("date") as v and then v.is_local_date and then v.as_local_date.day = 9)
            assert_true ("fraction preserved", attached parser.document as d and then attached d.value_at ("time") as v and then v.is_local_time and then v.as_local_time.fractional_digit_count = 4)
            assert_true ("offset type", attached parser.document as d and then attached d.value_at ("offset") as v and then v.is_offset_date_time and then v.as_offset_date_time.offset_minutes = 180)
            assert_true ("based integer", attached parser.document as d and then attached d.value_at ("hex") as v and then v.as_integer = 3735928559)
            assert_true ("infinity", attached parser.document as d and then attached d.value_at ("special") as v and then v.as_float.is_positive_infinity)
        end

    test_utf_8_file_round_trip
        local
            document: TOMELLE_DOCUMENT
            writer: TOMELLE_WRITER
            parser: TOMELLE_PARSER
            path: PATH
            file: RAW_FILE
        do
            create path.make_from_string ("tests/tomelle_utf8_round_trip.tmp")
            create document.make
            document.put_string_at ("Привет", "message")
            create writer.make
            writer.write_file (document, path)
            assert_true ("write successful", writer.is_successful)
            create parser.make
            parser.parse_file (path)
            assert_true ("read successful", parser.is_successful)
            assert_true ("unicode preserved", attached parser.document as d and then attached d.value_at ("message") as v and then v.as_string.same_string_general ("Привет"))
            create file.make_with_path (path)
            if file.exists then file.delete end
        end

    test_missing_file_error
        local
            parser: TOMELLE_PARSER
            path: PATH
        do
            create path.make_from_string ("tests/does-not-exist.toml")
            create parser.make
            parser.parse_file (path)
            assert_true ("input error", parser.has_error and then parser.error (1).is_input_error)
            assert_integers_equal ("input code", 3, parser.error (1).code.value)
        end

    test_array_of_tables
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string (
                "[[servers]]%Nname = %"alpha%"%Nport = 8001%N" +
                "[[servers]]%Nname = %"beta%"%Nport = 8002%N")
            assert_true ("array of tables parsed", parser.is_successful)
            assert_true ("two tables", attached parser.document as d and then attached d.value_at ("servers") as v and then v.is_array and then v.as_array.count = 2)
            assert_true ("second table", attached parser.document as d and then attached d.value_at ("servers") as v and then attached v.as_array [2].as_table ["name"] as n and then n.as_string.same_string_general ("beta"))
        end

    test_multiline_values
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string (
                "message = %"%"%"%Nhello%Nworld%"%"%"%N" +
                "numbers = [%N  1, # first%N  2,%N  3%N]%N")
            assert_true ("multiline parse", parser.is_successful)
            assert_true ("multiline string", attached parser.document as d and then attached d.value_at ("message") as v and then v.as_string.same_string_general ("hello%Nworld"))
            assert_true ("multiline array", attached parser.document as d and then attached d.value_at ("numbers") as v and then v.as_array.count = 3)
        end

    test_invalid_utf_8_file
        local
            path: PATH
            file: RAW_FILE
            bytes: STRING_8
            parser: TOMELLE_PARSER
        do
            create path.make_from_string ("tests/tomelle_invalid_utf8.tmp")
            create bytes.make (2)
            bytes.append_code (195)
            bytes.append_code (40)
            create file.make_with_path (path)
            file.create_read_write
            file.put_string (bytes)
            file.close
            create parser.make
            parser.parse_file (path)
            assert_true ("encoding error", parser.has_error and then parser.error (1).is_encoding_error)
            assert_integers_equal ("encoding code", 2, parser.error (1).code.value)
            if file.exists then file.delete end
        end

    test_writer_preserves_value_types
        local
            document: TOMELLE_DOCUMENT
            date: TOMELLE_LOCAL_DATE
            writer: TOMELLE_WRITER
            parser: TOMELLE_PARSER
        do
            create document.make
            document.put_float_at (1.0, "float")
            create date.make (2026, 8, 9)
            document.put_local_date_at (date, "date")
            create writer.make
            create parser.make
            parser.parse_string (writer.serialized (document))
            assert_true ("writer result parses", parser.is_successful)
            assert_true ("float remains float", attached parser.document as d and then attached d.value_at ("float") as v and then v.is_float)
            assert_true ("date remains date", attached parser.document as d and then attached d.value_at ("date") as v and then v.is_local_date)
        end

    test_invalid_numeric_forms
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("value = 01%N")
            assert_true ("leading zero rejected", parser.has_error)
            parser.parse_string ("value = 1_%N")
            assert_true ("trailing underscore rejected", parser.has_error)
            parser.parse_string ("value = .5%N")
            assert_true ("missing integer part rejected", parser.has_error)
        end

    test_inline_table_with_dotted_keys
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("point = { coordinates.x = 1, coordinates.y = 2, %"literal.dot%" = true }%N")
            assert_true ("inline table parsed", parser.is_successful)
            assert_true ("nested inline value", attached parser.document as d and then attached d.value_at ("point.coordinates.x") as v and then v.as_integer = 1)
            assert_true ("quoted literal dot", attached parser.document as d and then attached d.value_at ("point.%"literal.dot%"") as v and then v.as_boolean)
        end

    test_float_codec_is_canonical
        local
            parser: TOMELLE_PARSER
            writer: TOMELLE_WRITER
            factory: TOMELLE_VALUE_FACTORY
            text: STRING_32
        do
            create factory.make
            assert_true ("integer-shaped decimal accepted", factory.is_valid_float_text ("42"))
            assert_true ("signed exponent accepted", factory.is_valid_float_text ("-1.25e+3"))
            assert_false ("infinity has value constructor", factory.is_valid_float_text ("inf"))
            assert_false ("incomplete exponent rejected", factory.is_valid_float_text ("1e"))
            assert_false ("decimal point needs fraction", factory.is_valid_float_text ("1."))
            create parser.make
            parser.parse_string (
                "fixed = 1.0%N" +
                "exponent = 1e0%N" +
                "precise = 9_007_199_254_740_991.0%N")
            assert_true ("float source parses", parser.is_successful)
            assert_true ("equivalent spellings canonicalized",
                attached parser.document as d and then
                attached d.value_at ("fixed") as fixed and then
                attached d.value_at ("exponent") as exponent and then
                fixed.as_float_text.same_string (exponent.as_float_text))
            assert_true ("large exact float preserved",
                attached parser.document as d and then
                attached d.value_at ("precise") as precise and then
                precise.as_float_text.same_string_general ("9007199254740991.0"))
            create writer.make
            check attached parser.document as d then
                text := writer.serialized (d)
            end
            assert_true ("writer uses canonical floats",
                text.has_substring ("fixed = 1.0") and then
                text.has_substring ("exponent = 1.0") and then
                text.has_substring ("precise = 9007199254740991.0"))
        end

    test_integer_range_errors
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("value = 9223372036854775808%N")
            assert_true ("decimal overflow rejected", parser.has_error)
            assert_integers_equal ("decimal overflow code", 4, parser.error (1).code.value)
            assert_integers_equal ("value column", 9, parser.error (1).position.column)
            parser.parse_string ("value = 0xFFFFFFFFFFFFFFFFF%N")
            assert_true ("based overflow rejected", parser.has_error)
            assert_integers_equal ("based overflow code", 4, parser.error (1).code.value)
        end

    test_classified_value_errors
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("value = nope%N")
            assert_integers_equal ("invalid number code", 8, parser.error (1).code.value)
            assert_integers_equal ("invalid number column", 9, parser.error (1).position.column)
            parser.parse_string ("value = 2026-99-99%N")
            assert_integers_equal ("invalid date code", 9, parser.error (1).code.value)
            parser.parse_string ("value = %"unterminated%N")
            assert_integers_equal ("unexpected end code", 10, parser.error (1).code.value)
        end

    test_invalid_unicode_key_scalars
        local
            parser: TOMELLE_PARSER
        do
            create parser.make
            parser.parse_string ("%"\uD800%" = 1%N")
            assert_true ("surrogate key rejected", parser.has_error)
            assert_integers_equal ("surrogate key code", 6, parser.error (1).code.value)
            parser.parse_string ("%"\U00110000%" = 1%N")
            assert_true ("out of range key rejected", parser.has_error)
            assert_integers_equal ("out of range key code", 6, parser.error (1).code.value)
        end

    test_traversal_results_are_snapshots
        local
            table: TOMELLE_TABLE
            parser: TOMELLE_PARSER
            key_snapshot: ITERABLE [READABLE_STRING_32]
            error_snapshot: ITERABLE [TOMELLE_PARSE_ERROR]
        do
            create table.make
            table.put_integer (1, "key")
            key_snapshot := table.keys
            if attached {ARRAYED_LIST [READABLE_STRING_32]} key_snapshot as mutable_keys then
                across mutable_keys as key loop
                    if attached {STRING_32} key as mutable_key then
                        mutable_key.wipe_out
                    end
                end
                mutable_keys.wipe_out
            end
            assert_true ("table storage protected", table.has_key ("key") and then table.count = 1)

            create parser.make
            parser.parse_string ("value = nope%N")
            error_snapshot := parser.errors
            if attached {ARRAYED_LIST [TOMELLE_PARSE_ERROR]} error_snapshot as mutable_errors then
                mutable_errors.wipe_out
            end
            if attached {STRING_32} parser.error (1).message as mutable_message then
                mutable_message.wipe_out
            end
            assert_integers_equal ("parser errors protected", 1, parser.error_count)
            assert_false ("error message protected", parser.error (1).message.is_empty)
        end

    test_error_code_stability
        local
            code: TOMELLE_ERROR_CODE
        do
            create code.default_create
            assert_integers_equal ("invalid syntax", 1, code.invalid_syntax.value)
            assert_integers_equal ("invalid utf8", 2, code.invalid_utf_8.value)
            assert_integers_equal ("input unreadable", 3, code.input_unreadable.value)
            assert_integers_equal ("integer range", 4, code.integer_out_of_range.value)
            assert_integers_equal ("duplicate key", 5, code.duplicate_key.value)
            assert_integers_equal ("invalid key", 6, code.invalid_key.value)
            assert_integers_equal ("invalid string", 7, code.invalid_string.value)
            assert_integers_equal ("invalid number", 8, code.invalid_number.value)
            assert_integers_equal ("invalid datetime", 9, code.invalid_date_time.value)
            assert_integers_equal ("unexpected end", 10, code.unexpected_end_of_input.value)
            assert_integers_equal ("output unwritable", 101, code.output_unwritable.value)
            assert_integers_equal ("output interrupted", 102, code.output_interrupted.value)
        end

    test_unwritable_output_contract
        local
            document: TOMELLE_DOCUMENT
            writer: TOMELLE_WRITER
            path: PATH
        do
            create document.make
            document.put_integer_at (1, "value")
            create path.make_from_string ("tests/tomelle-missing-directory/output.toml")
            create writer.make
            writer.write_file (document, path)
            assert_true ("write attempted", writer.is_written)
            assert_false ("write failed", writer.is_successful)
            assert_true ("unwritable classified",
                attached writer.error as write_error and then
                write_error.code = write_error.code.output_unwritable)
        end

end
