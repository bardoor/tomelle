# API overview

This document covers the main Tomelle types and the usual read, inspect,
modify, and write workflow.

## Main objects

### `TOMELLE_PARSER`

Parses TOML from a string or a UTF-8 file:

```eiffel
parser.parse_string (source)
parser.parse_file (config_path)
```

A parser can be reused. Each call replaces its previous document and errors.
Check `is_successful` before reading `document`. On failure, use `errors` or
`error (index)`; each `TOMELLE_PARSE_ERROR` contains a stable error code, a
message, the source name, and a source position.

### `TOMELLE_DOCUMENT`

Represents a complete TOML document. Most application code can work through
this object without accessing the root table directly.

Keys are addressed with TOML dotted-key expressions:

```eiffel
document.value_at ("server.port")
document.has_at ("server.tls.enabled")
document.remove_at ("server.legacy_timeout")
```

Quoted path components preserve dots inside a key:

```eiffel
document.value_at ("server.%"physical.port%"")
```

Typed modification routines include `put_string_at`, `put_integer_at`,
`put_float_at`, `put_boolean_at`, and matching routines for dates, times,
arrays, and tables. Missing intermediate tables are created when the path is
compatible. Use `can_put_at` before accepting a path from an external source.

`independent_copy` creates a deep copy that can be changed without modifying
the original document.

### `TOMELLE_VALUE`

Stores one TOML value. It is a tagged value, so check its kind before calling a
typed accessor.

| TOML type | Kind query | Accessor | Eiffel result |
| --- | --- | --- | --- |
| String | `is_string` | `as_string` | `READABLE_STRING_32` |
| Integer | `is_integer` | `as_integer` | `INTEGER_64` |
| Float | `is_float` | `as_float`, `as_float_text` | `REAL_64`, canonical decimal text |
| Boolean | `is_boolean` | `as_boolean` | `BOOLEAN` |
| Offset date-time | `is_offset_date_time` | `as_offset_date_time` | `TOMELLE_OFFSET_DATE_TIME` |
| Local date-time | `is_local_date_time` | `as_local_date_time` | `TOMELLE_LOCAL_DATE_TIME` |
| Local date | `is_local_date` | `as_local_date` | `TOMELLE_LOCAL_DATE` |
| Local time | `is_local_time` | `as_local_time` | `TOMELLE_LOCAL_TIME` |
| Array | `is_array` | `as_array` | `TOMELLE_ARRAY` |
| Table | `is_table` | `as_table` | `TOMELLE_TABLE` |

The accessors have preconditions. Calling `as_integer` on a string value is a
contract violation.

`as_float_text` exposes the compiler-independent canonical TOML spelling used
by the writer. Use `TOMELLE_VALUE_FACTORY.new_float_from_text` when the input
decimal must be converted without first passing through a compiler formatter;
check `is_valid_float_text` before accepting untrusted input. Infinities and
NaN are created with `new_float`.

### `TOMELLE_TABLE` and `TOMELLE_ARRAY`

`TOMELLE_TABLE` maps Unicode keys to values. It supports direct key lookup,
iteration over `keys`, typed `put_*` routines, and removal.

`TOMELLE_ARRAY` is a one-based ordered collection. It supports iteration,
indexed access, typed `extend_*` routines, replacement, and removal.

Values passed into public table, array, and document modification routines are
copied. Later changes to the supplied value do not change the stored document.

### `TOMELLE_WRITER`

Serializes a document to `STRING_32` or writes it as UTF-8:

```eiffel
text := writer.serialized (document)
writer.write_file (document, config_path)
```

After `write_file`, check `is_successful`. A failed write exposes a
`TOMELLE_WRITE_ERROR` through `error`. File writes use a uniquely named sibling
temporary file followed by a rename, so a partially written destination is not
left behind and concurrent writers do not share temporary paths.

## Reading an application config

Given this `config.toml`:

```toml
[server]
host = "127.0.0.1"
port = 8080
enabled = true
```

Read and validate the values before using them:

```eiffel
local
    parser: TOMELLE_PARSER
    config_path: PATH
    port: INTEGER_64
    enabled: BOOLEAN
do
    create config_path.make_from_string ("config.toml")
    create parser.make
    parser.parse_file (config_path)

    if attached parser.document as config then
        if attached config.value_at ("server.port") as port_value and then
            port_value.is_integer and then
            attached config.value_at ("server.enabled") as enabled_value and then
            enabled_value.is_boolean
        then
            port := port_value.as_integer
            enabled := enabled_value.as_boolean

            if enabled then
                print ("Server port: ")
                print (port)
                print ("%N")
            end
        else
            print ("Missing or invalid server configuration%N")
        end
    else
        across parser.errors as parse_error loop
            print (parse_error.position.line)
            print (": ")
            print (parse_error.message)
            print ("%N")
        end
    end
end
```

An unsuccessful parse has no partial document. Application code cannot
accidentally continue with only part of the input.

## Updating an existing config

The following example reads a file, changes a nested integer, removes an old
setting, and writes the result back to the same path:

```eiffel
local
    parser: TOMELLE_PARSER
    writer: TOMELLE_WRITER
    config_path: PATH
do
    create config_path.make_from_string ("config.toml")
    create parser.make
    parser.parse_file (config_path)

    if attached parser.document as config then
        config.put_integer_at (9090, "server.port")
        config.remove_at ("server.legacy_timeout")

        create writer.make
        writer.write_file (config, config_path)
        if not writer.is_successful and then attached writer.error as write_error then
            print (write_error.message)
            print ("%N")
        end
    end
end
```

> [!WARNING]
> **Known issue: updates are not format-preserving.** `TOMELLE_PARSER` keeps
> the document's values, not its concrete syntax. `TOMELLE_WRITER` then emits a
> new canonical representation. Comments, blank lines, original quoting,
> whitespace, number formatting, and section layout are lost when an existing
> file is rewritten. The resulting TOML has the same data, but it may have a
> substantially different diff. Format-preserving editing needs a concrete
> syntax tree and is not implemented yet.

For configuration files maintained by people, write to a separate output path
or keep a backup until format-preserving updates are implemented. For files
owned entirely by the application, rewriting in canonical form is usually
acceptable.
