note
    description: "Groups physical input lines into complete TOML statements."

class
    TOMELLE_LOGICAL_LINE_SCANNER

feature -- Scanning

    scan (a_source: STRING_32): ARRAYED_LIST [TOMELLE_LOGICAL_LINE]
        local
            i, l_depth, l_run, j, l_line, l_start_line: INTEGER
            l_current, l_raw_current: STRING_32
            l_quote: CHARACTER_32
            l_multiline, l_escaped, l_comment: BOOLEAN
            l_item: TOMELLE_LOGICAL_LINE
        do
            create Result.make (1)
            create l_current.make_empty
            create l_raw_current.make_empty
            l_line := 1
            l_start_line := 1
            from i := 1 until i > a_source.count loop
                l_raw_current.extend (a_source [i])
                if l_comment then
                    if a_source [i] = '%N' then
                        l_comment := False
                        if l_depth = 0 then
                            create l_item.make (l_current, l_raw_current, l_start_line, 1)
                            Result.extend (l_item)
                            create l_current.make_empty
                            create l_raw_current.make_empty
                            l_start_line := l_line + 1
                        else
                            l_current.extend ('%N')
                        end
                    else
                        l_current.extend (' ')
                    end
                elseif l_quote = '%U' then
                    if i + 2 <= a_source.count and then
                        ((a_source [i] = '%"' and a_source [i + 1] = '%"' and a_source [i + 2] = '%"') or else
                         (a_source [i] = '%'' and a_source [i + 1] = '%'' and a_source [i + 2] = '%''))
                    then
                        l_quote := a_source [i]
                        l_multiline := True
                        l_current.append (a_source.substring (i, i + 2))
                        l_raw_current.append (a_source.substring (i + 1, i + 2))
                        i := i + 2
                    elseif a_source [i] = '%"' or a_source [i] = '%'' then
                        l_quote := a_source [i]
                        l_current.extend (a_source [i])
                    elseif a_source [i] = '#' then
                        l_comment := True
                        l_current.extend (' ')
                    elseif a_source [i] = '[' or a_source [i] = '{' then
                        l_depth := l_depth + 1
                        l_current.extend (a_source [i])
                    elseif a_source [i] = ']' or a_source [i] = '}' then
                        l_depth := l_depth - 1
                        l_current.extend (a_source [i])
                    elseif a_source [i] = '%N' then
                        if l_depth = 0 then
                            create l_item.make (l_current, l_raw_current, l_start_line, 1)
                            Result.extend (l_item)
                            create l_current.make_empty
                            create l_raw_current.make_empty
                            l_start_line := l_line + 1
                        else
                            l_current.extend ('%N')
                        end
                    else l_current.extend (a_source [i]) end
                elseif l_multiline then
                    if a_source [i] = l_quote and then not l_escaped then
                        from l_run := 0 until i + l_run > a_source.count or else a_source [i + l_run] /= l_quote loop
                            l_run := l_run + 1
                        end
                        if 3 <= l_run and l_run <= 5 then
                            from j := 1 until j > l_run - 3 loop l_current.extend (l_quote); j := j + 1 end
                            l_current.append (a_source.substring (i, i + 2))
                            if l_run > 1 then
                                l_raw_current.append (a_source.substring (i + 1, i + l_run - 1))
                            end
                            i := i + l_run - 1
                            l_quote := '%U'
                            l_multiline := False
                        else l_current.extend (a_source [i]) end
                    else
                        l_current.extend (a_source [i])
                        l_escaped := l_quote = '%"' and then a_source [i] = '\' and then not l_escaped
                        if a_source [i] /= '\' then l_escaped := False end
                    end
                else
                    l_current.extend (a_source [i])
                    if a_source [i] = l_quote and then not l_escaped then l_quote := '%U' end
                    l_escaped := l_quote = '%"' and then a_source [i] = '\' and then not l_escaped
                    if a_source [i] /= '\' then l_escaped := False end
                end
                if a_source [i] = '%N' then l_line := l_line + 1 end
                i := i + 1
            end
            if not l_current.is_empty then
                create l_item.make (l_current, l_raw_current, l_start_line, 1)
                Result.extend (l_item)
            elseif not l_raw_current.is_empty then
                create l_item.make (l_current, l_raw_current, l_start_line, 1)
                Result.extend (l_item)
            end
        end

end
