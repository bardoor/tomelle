note
    description: "Presentation details surrounding a TOML item."

class
    TOMELLE_TRIVIA

create
    make,
    make_with_values

feature {NONE} -- Initialization

    make
        do
            create indent.make_empty
            create comment_spacing.make_empty
            create comment.make_empty
            create trail.make_from_string ("%N")
        end

    make_with_values (a_indent, a_comment_spacing, a_comment, a_trail: READABLE_STRING_GENERAL)
        do
            indent := a_indent.as_string_32.twin
            comment_spacing := a_comment_spacing.as_string_32.twin
            comment := a_comment.as_string_32.twin
            trail := a_trail.as_string_32.twin
        end

feature -- Access

    indent: STRING_32
    comment_spacing: STRING_32
    comment: STRING_32
    trail: STRING_32

    suffix: STRING_32
        do
            create Result.make (comment_spacing.count + comment.count + trail.count)
            Result.append (comment_spacing)
            Result.append (comment)
            Result.append (trail)
        end

feature -- Element change

    set_indent (a_text: READABLE_STRING_GENERAL)
        do
            indent := a_text.as_string_32.twin
        ensure
            set: indent.same_string_general (a_text)
        end

    set_comment (a_text: READABLE_STRING_GENERAL)
        require
            valid_comment: a_text.is_empty or else a_text [1] = '#'
        do
            comment := a_text.as_string_32.twin
        ensure
            set: comment.same_string_general (a_text)
        end

    set_comment_spacing (a_text: READABLE_STRING_GENERAL)
        do
            comment_spacing := a_text.as_string_32.twin
        ensure
            set: comment_spacing.same_string_general (a_text)
        end

    set_trail (a_text: READABLE_STRING_GENERAL)
        do
            trail := a_text.as_string_32.twin
        ensure
            set: trail.same_string_general (a_text)
        end

    independent_copy: TOMELLE_TRIVIA
        do
            create Result.make_with_values (indent, comment_spacing, comment, trail)
        ensure
            independent: Result /= Current
        end

end
