class
    PARSE_FILE

create
    make

feature {NONE} -- Initialization

    make
        local
            parser: TOMELLE_PARSER
            parse_result: TOMELLE_PARSE_RESULT
            config_path: PATH
            document: TOMELLE_DOCUMENT
            port: TOMELLE_INTEGER
        do
            create config_path.make_from_string ("examples/config.toml")
            create parser.make
            parse_result := parser.parsed_file (config_path)

            if parse_result.is_successful then
                check attached parse_result.document as parsed_document then
                    document := parsed_document
                end
                if attached {TOMELLE_INTEGER} document.value_at ("server.port") as parsed_port then
                    port := parsed_port
                    print (port.value)
                    print ("%N")
                end
            end
        end

end
