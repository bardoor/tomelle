note
    description: "Shared lexical validity rules used across TOML syntax components."

class
    TOMELLE_SYNTAX_RULES

feature -- Unicode

    is_unicode_scalar (a_code: NATURAL_64): BOOLEAN
        do
            Result := a_code <= 0x10FFFF and then not (0xD800 <= a_code and a_code <= 0xDFFF)
        end

feature -- Characters

    is_hex_character (a_character: CHARACTER_32): BOOLEAN
        do
            Result := ('0' <= a_character and a_character <= '9') or else
                ('a' <= a_character and a_character <= 'f') or else
                ('A' <= a_character and a_character <= 'F')
        end

    hex_value (a_character: CHARACTER_32): INTEGER
        require
            hexadecimal: is_hex_character (a_character)
        do
            if '0' <= a_character and a_character <= '9' then
                Result := a_character.code - ('0').code
            elseif 'a' <= a_character and a_character <= 'f' then
                Result := 10 + a_character.code - ('a').code
            else
                Result := 10 + a_character.code - ('A').code
            end
        end

    is_bare_key_character (a_character: CHARACTER_32): BOOLEAN
        do
            Result := ('a' <= a_character and a_character <= 'z') or else
                ('A' <= a_character and a_character <= 'Z') or else
                ('0' <= a_character and a_character <= '9') or else
                a_character = '-' or else a_character = '_'
        end

end
