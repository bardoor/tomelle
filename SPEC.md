# Tomelle API specification

## Scope

Tomelle is a void-safe, dual-compiler TOML 1.1 library. It provides semantic
lookup and construction, lossless parse/edit/write behavior, and a separate
canonical renderer. The production library depends only on EiffelStudio Base
or Gobo FreeELKS.

## Parsing contract

`TOMELLE_PARSER.parsed_string` and `parsed_file` are stateless queries that
return `TOMELLE_PARSE_RESULT`.

- Exactly one of `document` and a non-empty error collection is present.
- Invalid TOML, invalid UTF-8, and file access failures are expected outcomes,
  not exceptions exposed to clients.
- Failed parsing never exposes a partial document.
- Error collections returned to clients are snapshots.

The command forms `parse_string` and `parse_file` are compatibility
operations backed by `last_result`; new clients use the stateless queries.

## Abstract document model

A document has two coordinated views:

1. A semantic root `TOMELLE_TABLE` used for lookup by decoded keys and paths.
2. An ordered physical sequence of `TOMELLE_ITEM` objects used for lossless
   rendering.

The semantic table stores ordered `TOMELLE_ENTRY` objects and a key index.
These representations must agree: each indexed key names exactly one ordered
entry, and the indexed value is the entry's value.

Physical items include entries, comments, whitespace, and table headers.
`representation` returns the retained or locally reconstructed source text.
`TOMELLE_TRIVIA` owns indentation, comment spacing, comment text, and trailing
text. Mutable text received from clients is copied.

## Values

`TOMELLE_VALUE` is deferred. Runtime type is expressed through Eiffel object
tests, not tag queries or down-cast accessors. Public concrete types are:

- `TOMELLE_STRING`
- `TOMELLE_INTEGER`
- `TOMELLE_FLOAT`
- `TOMELLE_BOOLEAN`
- `TOMELLE_LOCAL_DATE_VALUE`
- `TOMELLE_LOCAL_TIME_VALUE`
- `TOMELLE_LOCAL_DATE_TIME_VALUE`
- `TOMELLE_OFFSET_DATE_TIME_VALUE`
- `TOMELLE_ARRAY`
- `TOMELLE_TABLE`

Each scalar exposes its semantic `value`, retained `raw_text`, and a
`set_value` command. `TOMELLE_FLOAT.canonical_text` is compiler-independent.
Temporal semantic values remain portable expanded types.

Public insertion into documents, tables, and arrays copies the supplied value.
Objects returned from a document are live. `independent_copy` must not share
mutable semantic state with its source.

## Mutation

`put_*`, `extend_*`, `replace`, `remove`, and `wipe_out` are commands.
Lookup, validation, measurement, and rendering are queries.

Document path mutation:

- accepts TOML dotted-key expressions;
- creates missing intermediate tables only when the existing prefix is
  compatible;
- updates the corresponding physical entry on replacement;
- appends a canonical physical entry for a new key;
- preserves unrelated source items and trivia.

Direct scalar mutation retains the prior lexical style when the new semantic
value can be represented safely in that style. Otherwise it falls back to a
valid canonical spelling.

## Rendering

`TOMELLE_WRITER.serialized` renders the physical model.

- An unchanged parsed document is byte-for-code-point identical to its input.
- A local supported mutation changes the affected value representation while
  preserving unrelated comments, whitespace, key spelling, section layout,
  and container layout.

`serialized_canonical` ignores physical trivia and deterministically renders
the semantic model. It is intentionally distinct from lossless serialization.

`write_file` encodes UTF-8 and replaces the destination through a unique
temporary sibling. A failed write exposes `TOMELLE_WRITE_ERROR` and does not
claim success.

## TOML rules and portability

- Empty quoted keys are valid.
- TOML 1.1 `\e` and `\xHH` escapes are accepted in basic strings and keys.
- Integers are signed 64-bit values.
- Float canonicalization is shared across compilers.
- Unicode scalar validation rejects surrogate code points and values above
  U+10FFFF.
- Production code must compile under both supported compiler profiles and must
  not expose compiler-specific string, time, or collection implementations.

## Verification

A release candidate must pass:

- Gobo unit tests and full library compilation;
- EiffelStudio library and example builds;
- decoder and encoder builds for `toml-test`;
- the pinned TOML 1.1 conformance suite;
- focused lossless tests covering comments, blank lines, quoting, number
  spelling, arrays, inline tables, dotted keys, tables, and arrays-of-tables.
