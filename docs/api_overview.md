# API overview

Tomelle parses TOML into a typed, lossless object model. Parsed source spelling
and trivia remain attached to the model, so local edits produce local textual
changes.

## Parse outcomes

`TOMELLE_PARSER` offers stateless queries:

```eiffel
parse_result := parser.parsed_string (source)
parse_result := parser.parsed_file (config_path)
```

`TOMELLE_PARSE_RESULT.is_successful` means that `document` is attached.
Failures expose `error_count`, `error (index)`, and a snapshot returned by
`errors`; no partial document is exposed.

The command forms `parse_string` and `parse_file`, together with the
last-result queries on `TOMELLE_PARSER`, remain as a compatibility bridge.
New code should use `parsed_string` and `parsed_file`.

## Typed values

`TOMELLE_VALUE` is a deferred common type. Use Eiffel object tests and the
concrete value's `value` query:

```eiffel
if attached {TOMELLE_INTEGER} document.value_at ("server.port") as port then
    print (port.value)
elseif attached {TOMELLE_STRING} document.value_at ("server.port") as text then
    print (text.value)
end
```

Concrete public value classes are:

| TOML type | Eiffel class | Semantic query |
| --- | --- | --- |
| String | `TOMELLE_STRING` | `value: STRING_32` |
| Integer | `TOMELLE_INTEGER` | `value: INTEGER_64` |
| Float | `TOMELLE_FLOAT` | `value: REAL_64`, `canonical_text` |
| Boolean | `TOMELLE_BOOLEAN` | `value: BOOLEAN` |
| Local date | `TOMELLE_LOCAL_DATE_VALUE` | `value: TOMELLE_LOCAL_DATE` |
| Local time | `TOMELLE_LOCAL_TIME_VALUE` | `value: TOMELLE_LOCAL_TIME` |
| Local date-time | `TOMELLE_LOCAL_DATE_TIME_VALUE` | `value: TOMELLE_LOCAL_DATE_TIME` |
| Offset date-time | `TOMELLE_OFFSET_DATE_TIME_VALUE` | `value: TOMELLE_OFFSET_DATE_TIME` |
| Array | `TOMELLE_ARRAY` | indexed access and iteration |
| Table | `TOMELLE_TABLE` | keyed access and ordered `entries` |

Scalar `set_value` commands update the semantic value while retaining a
compatible source style where possible.

## Documents, entries, and trivia

`TOMELLE_DOCUMENT.value_at` accepts a TOML dotted-key expression. Typed
`put_*_at` commands insert or replace values and `remove_at` removes them.
Edits through the document synchronize the semantic tree with its physical
`TOMELLE_ENTRY` sequence.

`document.items` traverses physical items in source order. Entries,
standalone comments, whitespace, and table headers are represented by
`TOMELLE_ENTRY`, `TOMELLE_COMMENT`, `TOMELLE_WHITESPACE`, and
`TOMELLE_HEADER`. Each item exposes `representation`; values and entries
carry `TOMELLE_TRIVIA`.

`TOMELLE_TABLE` keeps entries in source/insertion order and maintains a
separate semantic key index. `keys` and `errors` return snapshots rather
than mutable internal storage.

## Rendering

```eiffel
text := writer.serialized (document)
canonical_text := writer.serialized_canonical (document)
writer.write_file (document, config_path)
```

`serialized` is lossless for an unchanged parsed document and preserves
unaffected formatting after local mutations. `serialized_canonical` ignores
retained trivia and emits deterministic semantic TOML.

`write_file` writes UTF-8 through a temporary sibling followed by rename.
After the command, inspect `is_successful` and `error`.

## Ownership

Public document, table, and array insertion commands copy supplied values.
Objects obtained from an existing document are live: calling `set_value` on a
concrete scalar or editing a returned table/array updates that document.
`TOMELLE_DOCUMENT.independent_copy` creates an independent semantic copy.
