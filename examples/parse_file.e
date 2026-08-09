class
    PARSE_FILE

create
    make

feature {NONE} -- Initialization

    make
        local
            parser: TOMELLE_PARSER
            config_path: PATH
            document: TOMELLE_DOCUMENT
            port: TOMELLE_VALUE
        do
            create config_path.make_from_string ("examples/config.toml")
            create parser.make
            parser.parse_file (config_path)

            if parser.is_successful then
                check attached parser.document as parsed_document then
                    document := parsed_document
                end
                if attached document.value_at ("server.port") as parsed_port then
                    port := parsed_port
                    print (port.as_integer)
                    print ("%N")
                end
            end
        end

end
