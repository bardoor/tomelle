note
    description: "toml-test encoder command for Tomelle."

class
    TOML_TEST_ENCODER

create
    make

feature {NONE} -- Entry point

    make
        local
            l_json: TOML_TEST_JSON_PARSER
            l_document: detachable TOMELLE_DOCUMENT
            l_writer: TOMELLE_WRITER
            l_io: TOML_TEST_IO
        do
            create l_io
            if attached l_io.decoded_utf_8 (l_io.stdin_bytes) as l_source then
                create l_json.make
                l_json.parse (l_source)
                if attached l_json.root as l_root then
                    l_document := document_from_json (l_root)
                    if attached l_document as d then
                        create l_writer.make
                        l_io.write_stdout (l_writer.serialized (d))
                    else fail ("Invalid tagged JSON document", l_io) end
                elseif attached l_json.error_message as l_error then fail (l_error, l_io)
                else fail ("Invalid JSON", l_io) end
            else fail ("Input is not valid UTF-8", l_io) end
        end

feature {NONE} -- Conversion

    document_from_json (a_root: TOML_TEST_JSON_VALUE): detachable TOMELLE_DOCUMENT
        local
            i: INTEGER
            l_value: detachable TOMELLE_VALUE
        do
            if a_root.is_object and then not is_tagged_value (a_root) then
                create Result.make
                from i := 1 until i > a_root.object_keys.count or else Result = Void loop
                    l_value := toml_value (a_root.object_values [i])
                    if attached l_value as v then Result.root.put (v, a_root.object_keys [i])
                    else Result := Void end
                    i := i + 1
                end
            end
        end

    toml_value (a_json: TOML_TEST_JSON_VALUE): detachable TOMELLE_VALUE
        local
            i: INTEGER
            l_array: TOMELLE_ARRAY
            l_table: TOMELLE_TABLE
            l_child: detachable TOMELLE_VALUE
            l_valid: BOOLEAN
        do
            l_valid := True
            if a_json.is_array then
                create l_array.make
                from i := 1 until i > a_json.array_values.count or else not l_valid loop
                    l_child := toml_value (a_json.array_values [i])
                    if attached l_child as v then l_array.extend (v) else l_valid := False end
                    i := i + 1
                end
                if l_valid then Result := value_factory.new_array (l_array) end
            elseif a_json.is_object then
                if is_tagged_value (a_json) then Result := scalar_value (a_json)
                else
                    create l_table.make
                    from i := 1 until i > a_json.object_keys.count or else not l_valid loop
                        l_child := toml_value (a_json.object_values [i])
                        if attached l_child as v then l_table.put (v, a_json.object_keys [i]) else l_valid := False end
                        i := i + 1
                    end
                    if l_valid then Result := value_factory.new_table (l_table) end
                end
            end
        end

    scalar_value (a_json: TOML_TEST_JSON_VALUE): detachable TOMELLE_VALUE
        local
            l_parser: TOMELLE_PARSER
            l_type, l_text: STRING_32
        do
            check attached a_json.object_value ("type") as l_type_node and
                attached a_json.object_value ("value") as l_value_node
            then
                l_type := l_type_node.as_string
                l_text := l_value_node.as_string
                if l_type.same_string ("string") then Result := value_factory.new_string (l_text)
                elseif l_type.same_string ("float") and then not l_text.same_string ("inf") and then
                    not l_text.same_string ("+inf") and then not l_text.same_string ("-inf") and then
                    not l_text.same_string ("nan") and then not l_text.same_string ("+nan") and then
                    not l_text.same_string ("-nan")
                then
                    Result := value_factory.new_float_from_text (l_text)
                elseif l_type.same_string ("integer") or l_type.same_string ("float") or
                    l_type.same_string ("bool") or l_type.same_string ("datetime") or
                    l_type.same_string ("datetime-local") or l_type.same_string ("date-local") or
                    l_type.same_string ("time-local")
                then
                    create l_parser.make
                    l_parser.parse_string ("value = " + l_text + "%N")
                    if attached l_parser.document as l_document and then attached l_document.root ["value"] as l_value then
                            Result := l_value
                    end
                end
            end
        end

    is_tagged_value (a_json: TOML_TEST_JSON_VALUE): BOOLEAN
        do
            Result := a_json.is_object and then a_json.object_keys.count = 2 and then
                attached a_json.object_value ("type") as l_type and then l_type.is_string and then
                attached a_json.object_value ("value") as l_value and then l_value.is_string
        end

    value_factory: TOMELLE_VALUE_FACTORY
        once
            create Result.make
        end

feature {NONE} -- Failure

    fail (a_message: READABLE_STRING_GENERAL; a_io: TOML_TEST_IO)
        local l_exceptions: EXCEPTIONS
        do
            a_io.write_stderr (a_message)
            create l_exceptions
            l_exceptions.die (1)
        end

end
