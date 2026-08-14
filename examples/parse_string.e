class
    PARSE_STRING

create
    make

feature {NONE} -- Initialization

    make
        local
            parser: TOMELLE_PARSER
            parse_result: TOMELLE_PARSE_RESULT
            document: TOMELLE_DOCUMENT
            title: TOMELLE_STRING
        do
            create parser.make
            parse_result := parser.parsed_string ("title = %"Tomelle%"%N")

            if parse_result.is_successful then
                check attached parse_result.document as parsed_document then
                    document := parsed_document
                end
                if attached {TOMELLE_STRING} document.value_at ("title") as parsed_title then
                    title := parsed_title
                    print (title.value)
                    print ("%N")
                end
            end
        end

end
