class
    PARSE_STRING

create
    make

feature {NONE} -- Initialization

    make
        local
            parser: TOMELLE_PARSER
            document: TOMELLE_DOCUMENT
            title: TOMELLE_VALUE
        do
            create parser.make
            parser.parse_string ("title = %"Tomelle%"%N")

            if parser.is_successful then
                check attached parser.document as parsed_document then
                    document := parsed_document
                end
                if attached document.value_at ("title") as parsed_title then
                    title := parsed_title
                    print (title.as_string)
                    print ("%N")
                end
            end
        end

end
