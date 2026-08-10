note
    description: "Quote- and container-aware lexical operations for TOML text."

class
    TOMELLE_LEXICAL_TOOLS

feature -- Text

    trimmed (a_text: STRING_32): STRING_32
        local
            l_start, l_end: INTEGER
        do
            from l_start := 1 until l_start > a_text.count or else not a_text [l_start].is_space loop
                l_start := l_start + 1
            end
            from l_end := a_text.count until l_end < l_start or else not a_text [l_end].is_space loop
                l_end := l_end - 1
            end
            Result := substring (a_text, l_start, l_end)
        end

    substring (a_text: STRING_32; a_start, a_end: INTEGER): STRING_32
        local i: INTEGER
        do
            create Result.make ((a_end - a_start + 1).max (0))
            from i := a_start until i > a_end loop
                Result.extend (a_text [i])
                i := i + 1
            end
        end

    without_comment (a_line: STRING_32): STRING_32
        local
            i: INTEGER
            l_quote: CHARACTER_32
            l_escaped: BOOLEAN
        do
            from i := 1 until i > a_line.count or else (a_line [i] = '#' and l_quote = '%U') loop
                if l_quote = '%U' and then (a_line [i] = '%"' or a_line [i] = '%'') then l_quote := a_line [i]
                elseif l_quote /= '%U' and then a_line [i] = l_quote and then not l_escaped then l_quote := '%U' end
                l_escaped := l_quote = '%"' and then a_line [i] = '\' and then not l_escaped
                if a_line [i] /= '\' then l_escaped := False end
                i := i + 1
            end
            Result := substring (a_line, 1, i - 1)
        end

feature -- Structure

    top_level_equal (a_text: STRING_32): INTEGER
        local
            i, l_depth: INTEGER
            l_quote: CHARACTER_32
        do
            from i := 1 until i > a_text.count or Result > 0 loop
                if l_quote = '%U' then
                    if a_text [i] = '%"' or a_text [i] = '%'' then l_quote := a_text [i]
                    elseif a_text [i] = '[' or a_text [i] = '{' then l_depth := l_depth + 1
                    elseif a_text [i] = ']' or a_text [i] = '}' then l_depth := l_depth - 1
                    elseif a_text [i] = '=' and l_depth = 0 then Result := i end
                elseif a_text [i] = l_quote and then (i = 1 or else a_text [i - 1] /= '\') then l_quote := '%U' end
                i := i + 1
            end
        end

    split_top_level (a_text: STRING_32; a_separator: CHARACTER_32): ARRAYED_LIST [STRING_32]
        local
            i, l_start, l_depth: INTEGER
            l_quote: CHARACTER_32
        do
            create Result.make (1)
            l_start := 1
            from i := 1 until i > a_text.count loop
                if l_quote = '%U' then
                    if a_text [i] = '%"' or a_text [i] = '%'' then l_quote := a_text [i]
                    elseif a_text [i] = '[' or a_text [i] = '{' then l_depth := l_depth + 1
                    elseif a_text [i] = ']' or a_text [i] = '}' then l_depth := l_depth - 1
                    elseif a_text [i] = a_separator and l_depth = 0 then
                        Result.extend (substring (a_text, l_start, i - 1))
                        l_start := i + 1
                    end
                elseif a_text [i] = l_quote and then (i = 1 or else a_text [i - 1] /= '\') then l_quote := '%U' end
                i := i + 1
            end
            if l_start <= a_text.count then Result.extend (substring (a_text, l_start, a_text.count))
            elseif a_text.is_empty then Result.extend (create {STRING_32}.make_empty) end
        end

    is_only_separator (a_text: STRING_32; a_separator: CHARACTER_32): BOOLEAN
        local l_text: STRING_32
        do
            l_text := trimmed (a_text)
            Result := l_text.count = 1 and then l_text [1] = a_separator
        end

    has_repeated_trailing_separator (a_text: STRING_32; a_separator: CHARACTER_32): BOOLEAN
        local l_text: STRING_32
        do
            l_text := trimmed (a_text)
            Result := l_text.count >= 2 and then l_text [l_text.count] = a_separator and then
                l_text [l_text.count - 1] = a_separator
        end

end
