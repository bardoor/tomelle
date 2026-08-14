# Tomelle API Specification

## Status

This document defines the proposed public API of Tomelle. It describes the
consumer-facing model rather than the parser implementation or the complete
TOML 1.1 grammar.

## Goals

Tomelle is a bidirectional TOML 1.1 library for Eiffel. It parses TOML into an
editable object model, lets clients construct the same model programmatically,
and serializes that model back to TOML. Its API is designed
to:

- follow Eiffel Command/Query Separation;
- be small and easy to discover;
- expose parsed documents as directly editable object trees;
- prioritize a small and convenient mutation API for configuration files;
- generate deterministic TOML text and UTF-8 files;
- use Design by Contract to guard typed access;
- compile with both EiffelStudio and Gobo Eiffel;
- keep the core library dependent only on ELKS/FreeELKS;
- preserve every value and distinction required by TOML 1.1.

The core API must not depend on EiffelTime, Gobo Time, or compiler-specific
libraries. Optional adapters for those libraries may be supplied separately.

## Bidirectional API Revision

Supporting TOML generation requires the following changes to the original
parse-only API:

- make documents, tables, and arrays directly mutable;
- provide typed `put_*` and `extend_*` commands for common edits;
- retain a value factory for generic, dynamically typed operations;
- add creation procedures and validity contracts to temporal expanded types;
- preserve a stable key order in tables for deterministic serialization;
- add `TOMELLE_WRITER` for text and transactional UTF-8 file output;
- add write errors and fully define stable parse/write error codes;
- define semantic round-tripping and explicitly exclude lexical formatting
  preservation from the core model.

The invalid Eiffel feature name `local` is corrected to `local_date_time`.
This first version performs semantic editing and canonical rewriting; it does
not preserve comments or lexical formatting.

## Naming

All public classes use the `TOMELLE_` prefix. Implementation classes may also
use this prefix but are not exported for creation by library consumers.

Every Tomelle class source must begin with a `note` clause containing a
non-empty `description:` entry. API excerpts below may omit repeated note
clauses for brevity.

## API and Cluster Layout

The recommended core-library clusters are:

| Cluster | Public classes |
| --- | --- |
| `parsing` | `TOMELLE_PARSER` |
| `model.values` | `TOMELLE_VALUE`, `TOMELLE_VALUE_FACTORY` |
| `model.collections` | `TOMELLE_DOCUMENT`, `TOMELLE_ARRAY`, `TOMELLE_TABLE` |
| `model.paths` | `TOMELLE_PATH`, `TOMELLE_KEY_SYNTAX` |
| `model.time` | `TOMELLE_LOCAL_DATE`, `TOMELLE_LOCAL_TIME`, `TOMELLE_LOCAL_DATE_TIME`, `TOMELLE_OFFSET_DATE_TIME` |
| `serialization` | `TOMELLE_WRITER` |
| `errors` | `TOMELLE_ERROR_CODE`, `TOMELLE_PARSE_ERROR`, `TOMELLE_WRITE_ERROR`, `TOMELLE_SOURCE_POSITION` |

Cluster names describe source organization only and are not part of Eiffel
type names. Compiler configuration must include these clusters recursively.
Implementation-only concrete value, parser, writer, cursor, and storage classes
may live in corresponding `implementation` subclusters.

## Parser

`TOMELLE_PARSER` is a reusable stateful parser. Parsing is a command. The
document, errors, and parser status are queries describing the last parse
operation.

```eiffel
class
    TOMELLE_PARSER

create
    make

feature {NONE} -- Initialization

    make
            -- Create a parser with no parse result.
        ensure
            not_parsed: not is_parsed
            no_document: document = Void
            no_errors: error_count = 0
        end

feature -- Parsing

    parse_string (a_source: READABLE_STRING_GENERAL)
            -- Parse TOML text from `a_source`.
        require
            source_attached: a_source /= Void
        ensure
            parsed: is_parsed
            result_consistent:
                is_successful = attached document
        end

    parse_file (a_path: PATH)
            -- Read and parse a UTF-8 TOML document from `a_path`.
            --
            -- Report file access and invalid UTF-8 as parse errors.
        require
            path_attached: a_path /= Void
            path_not_empty: not a_path.is_empty
        ensure
            parsed: is_parsed
            result_consistent:
                is_successful = attached document
        end

    reset
            -- Discard the result of the previous parse operation.
        ensure
            not_parsed: not is_parsed
            no_document: document = Void
            no_errors: error_count = 0
        end

feature -- Status report

    is_parsed: BOOLEAN
            -- Has a parse operation been attempted?

    is_successful: BOOLEAN
            -- Did the last parse operation produce a document?
        ensure
            definition:
                Result = (is_parsed and then not has_error)
        end

    has_error: BOOLEAN
            -- Did the last parse operation report an error?
        ensure
            definition: Result = (error_count > 0)
        end

feature -- Result

    document: detachable TOMELLE_DOCUMENT
            -- Document produced by the last successful parse operation.

    error_count: INTEGER
            -- Number of errors from the last parse operation.

    error (a_index: INTEGER): TOMELLE_PARSE_ERROR
            -- Error at one-based `a_index`.
        require
            valid_index: 1 <= a_index and a_index <= error_count
        end

    errors: ITERABLE [TOMELLE_PARSE_ERROR]
            -- Read-only traversal over errors from the last parse operation.

invariant
    not_parsed_has_no_document:
        not is_parsed implies document = Void
    not_parsed_has_no_errors:
        not is_parsed implies error_count = 0
    successful_has_document:
        is_successful implies attached document
    unsuccessful_has_no_document:
        is_parsed and then not is_successful implies document = Void

end
```

Parsing is transactional. A partially constructed document must never become
visible to a client. A failed file read and invalid UTF-8 count as attempted,
unsuccessful parse operations: `is_parsed` and `has_error` are true, while
`document` is `Void`.

The collection returned by `errors` must not allow a client to mutate parser
state. A mutable `ARRAYED_LIST` must not be exposed directly.

## Document

A document owns one mutable root table and provides path-based lookup and
editing. Typed lookup is performed through `TOMELLE_VALUE`. Typed mutation
commands are provided for convenience because Eiffel does not support routine
overloading.

```eiffel
class
    TOMELLE_DOCUMENT

create
    make

feature {NONE} -- Initialization

    make
            -- Create an empty TOML document.
        ensure
            empty: is_empty
        end

feature -- Access

    root: TOMELLE_TABLE
            -- Mutable root table of the document.

    value (a_path: TOMELLE_PATH): detachable TOMELLE_VALUE
            -- Value at exactly `a_path`, if present.
        require
            path_attached: a_path /= Void
        end

    value_at (
        a_key_expression: READABLE_STRING_GENERAL
    ): detachable TOMELLE_VALUE
            -- Value addressed by TOML dotted-key expression
            -- `a_key_expression`, if present.
            --
            -- Quoted keys are interpreted according to TOML syntax. For
            -- example, `server.%"physical.color%"` addresses two keys.
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        end

feature -- Status report

    has (a_path: TOMELLE_PATH): BOOLEAN
            -- Is a value present at exactly `a_path`?
        require
            path_attached: a_path /= Void
        ensure
            definition: Result = (value (a_path) /= Void)
        end

    has_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
            -- Is a value present at TOML dotted-key expression
            -- `a_key_expression`?
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        ensure
            definition: Result = (value_at (a_key_expression) /= Void)
        end

    is_empty: BOOLEAN
        ensure
            definition: Result = root.is_empty
        end

    can_put (a_path: TOMELLE_PATH): BOOLEAN
            -- Are all existing intermediate components tables?
        require
            path_attached: a_path /= Void
            path_not_empty: a_path.count > 0
        end

    can_put_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
            -- Is the expression valid and are all existing intermediate
            -- components tables?
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        end

feature -- Structured access

    table_at (a_key_expression: READABLE_STRING_GENERAL): TOMELLE_TABLE
        require
            correct_type:
                attached value_at (a_key_expression) as v and then v.is_table
        ensure
            definition:
                attached value_at (a_key_expression) as v and then
                Result = v.as_table
        end

    array_at (a_key_expression: READABLE_STRING_GENERAL): TOMELLE_ARRAY
        require
            correct_type:
                attached value_at (a_key_expression) as v and then v.is_array
        ensure
            definition:
                attached value_at (a_key_expression) as v and then
                Result = v.as_array
        end

feature -- General modification

    put (a_value: TOMELLE_VALUE; a_path: TOMELLE_PATH)
            -- Insert or replace `a_value`, creating missing intermediate
            -- tables.
        require
            value_attached: a_value /= Void
            path_attached: a_path /= Void
            path_not_empty: a_path.count > 0
            path_compatible: can_put (a_path)
        ensure
            stored:
                attached value (a_path) as v and then v.is_equal (a_value)
        end

    put_at (a_value: TOMELLE_VALUE; a_key_expression: READABLE_STRING_GENERAL)
            -- Insert or replace a value using a dotted-key expression.
        require
            value_attached: a_value /= Void
            path_compatible: can_put_at (a_key_expression)
        ensure
            stored:
                attached value_at (a_key_expression) as v and then
                v.is_equal (a_value)
        end

    remove (a_path: TOMELLE_PATH)
            -- Remove the value if present; otherwise do nothing.
        require
            path_attached: a_path /= Void
        ensure
            absent: not has (a_path)
        end

    remove_at (a_key_expression: READABLE_STRING_GENERAL)
            -- Remove the addressed value if present; otherwise do nothing.
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        ensure
            absent: not has_at (a_key_expression)
        end

    wipe_out
            -- Remove all values.
        ensure
            empty: is_empty
        end

feature -- Typed modification

    put_string_at (a_value: READABLE_STRING_GENERAL;
        a_key_expression: READABLE_STRING_GENERAL)
        require
            value_attached: a_value /= Void
            path_compatible: can_put_at (a_key_expression)
        ensure
            stored:
                attached value_at (a_key_expression) as v and then
                v.is_string and then
                v.as_string.same_string_general (a_value)
        end

    put_integer_at (a_value: INTEGER_64;
        a_key_expression: READABLE_STRING_GENERAL)
        require
            path_compatible: can_put_at (a_key_expression)
        ensure
            correct_value:
                attached value_at (a_key_expression) as v and then
                v.is_integer and then v.as_integer = a_value
        end

    put_float_at (a_value: REAL_64;
        a_key_expression: READABLE_STRING_GENERAL)

    put_boolean_at (a_value: BOOLEAN;
        a_key_expression: READABLE_STRING_GENERAL)

    put_local_date_at (a_value: TOMELLE_LOCAL_DATE;
        a_key_expression: READABLE_STRING_GENERAL)

    put_local_time_at (a_value: TOMELLE_LOCAL_TIME;
        a_key_expression: READABLE_STRING_GENERAL)

    put_local_date_time_at (a_value: TOMELLE_LOCAL_DATE_TIME;
        a_key_expression: READABLE_STRING_GENERAL)

    put_offset_date_time_at (a_value: TOMELLE_OFFSET_DATE_TIME;
        a_key_expression: READABLE_STRING_GENERAL)

    put_table_at (a_value: TOMELLE_TABLE;
        a_key_expression: READABLE_STRING_GENERAL)

    put_array_at (a_value: TOMELLE_ARRAY;
        a_key_expression: READABLE_STRING_GENERAL)

feature -- Structure creation

    make_table_at (a_key_expression: READABLE_STRING_GENERAL)
            -- Create or replace a table at the given path.
        require
            path_compatible: can_put_at (a_key_expression)
        ensure
            table_created:
                attached value_at (a_key_expression) as v and then v.is_table
        end

    make_array_at (a_key_expression: READABLE_STRING_GENERAL)
            -- Create or replace an array at the given path.
        require
            path_compatible: can_put_at (a_key_expression)
        ensure
            array_created:
                attached value_at (a_key_expression) as v and then v.is_array
        end

feature -- Copying

    independent_copy: TOMELLE_DOCUMENT
            -- Independent mutable copy of the complete document.
        ensure
            independent: Result /= Current
            equivalent: Result.is_equal (Current)
        end

invariant
    root_attached: root /= Void

end
```

All `put_*_at` commands are upserts. Missing intermediate tables are created
automatically. If an existing intermediate component is not a table,
`can_put_at` is false and the mutation violates its precondition. `remove` and
`remove_at` are intentionally idempotent.

Structured values use copy-on-insert semantics. Inserting a table or array
recursively copies it into its destination, preventing cycles and accidental
aliasing between different documents or paths. Structured objects obtained
later through `table_at`, `array_at`, `as_table`, or `as_array` are live and
may be edited in place.

## Value Model

`TOMELLE_VALUE` is the single dynamically typed entry point for TOML values.
Its public interface contains only:

- `is_*` queries that identify the represented TOML type;
- `as_*` queries that return the represented value.

An `as_*` query is non-detachable and has its corresponding `is_*` query as a
precondition. This avoids boxing scalar expanded values in `INTEGER_64_REF`,
`REAL_64_REF`, or `BOOLEAN_REF`.

Exactly one `is_*` query must be true for every value.

```eiffel
deferred class
    TOMELLE_VALUE

feature -- Type report

    is_string: BOOLEAN
    is_integer: BOOLEAN
    is_float: BOOLEAN
    is_boolean: BOOLEAN
    is_offset_date_time: BOOLEAN
    is_local_date_time: BOOLEAN
    is_local_date: BOOLEAN
    is_local_time: BOOLEAN
    is_array: BOOLEAN
    is_table: BOOLEAN

feature -- Typed access

    as_string: READABLE_STRING_32
        require
            is_string: is_string
        deferred
        end

    as_integer: INTEGER_64
        require
            is_integer: is_integer
        deferred
        end

    as_float: REAL_64
        require
            is_float: is_float
        deferred
        end

    as_float_text: READABLE_STRING_32
            -- Compiler-independent canonical TOML spelling.
        require
            is_float: is_float
        deferred
        end

    as_boolean: BOOLEAN
        require
            is_boolean: is_boolean
        deferred
        end

    as_offset_date_time: TOMELLE_OFFSET_DATE_TIME
        require
            is_offset_date_time: is_offset_date_time
        deferred
        end

    as_local_date_time: TOMELLE_LOCAL_DATE_TIME
        require
            is_local_date_time: is_local_date_time
        deferred
        end

    as_local_date: TOMELLE_LOCAL_DATE
        require
            is_local_date: is_local_date
        deferred
        end

    as_local_time: TOMELLE_LOCAL_TIME
        require
            is_local_time: is_local_time
        deferred
        end

    as_array: TOMELLE_ARRAY
        require
            is_array: is_array
        deferred
        end

    as_table: TOMELLE_TABLE
        require
            is_table: is_table
        deferred
        end

end
```

Concrete scalar classes such as `TOMELLE_INTEGER_VALUE` are implementation
details. Clients inspect them only through `TOMELLE_VALUE`:

```eiffel
if value.is_integer then
    print (value.as_integer)
end
```

## TOML-to-Eiffel Type Mapping

| TOML type | Type query | Access query | Public Eiffel type |
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
| Table or inline table | `is_table` | `as_table` | `TOMELLE_TABLE` |

IELKS scalar types are used wherever they represent TOML without loss.
Tomelle-owned types are used for structured and temporal values because IELKS
does not provide exact immutable equivalents.

TOML integers must be range-checked before conversion to `INTEGER_64`. A value
outside the TOML 64-bit signed integer range is a parse error. TOML special
float values (`inf`, `-inf`, and `nan`) are represented by the corresponding
`REAL_64` values supported by the compiler runtime.

## Array

`TOMELLE_ARRAY` is a mutable ordered sequence. It does not expose its internal
storage. Arrays may contain values of different types.

```eiffel
class
    TOMELLE_ARRAY

create
    make

feature {NONE} -- Initialization

    make
        ensure
            empty: is_empty
        end

feature -- Measurement

    count: INTEGER

    is_empty: BOOLEAN
        ensure
            definition: Result = (count = 0)
        end

feature -- Access

    item alias "[]" (a_index: INTEGER): TOMELLE_VALUE
        require
            valid_index: valid_index (a_index)
        end

    first: TOMELLE_VALUE
        require
            not_empty: not is_empty
        end

    last: TOMELLE_VALUE
        require
            not_empty: not is_empty
        end

    new_cursor: ITERATION_CURSOR [TOMELLE_VALUE]
            -- Fresh cursor for `across` traversal.

feature -- Status report

    valid_index (a_index: INTEGER): BOOLEAN
        ensure
            definition: Result = (1 <= a_index and a_index <= count)
        end

feature -- Modification

    extend (a_value: TOMELLE_VALUE)
        require
            value_attached: a_value /= Void
        ensure
            one_more: count = old count + 1
            appended: last.is_equal (a_value)
        end

    extend_string (a_value: READABLE_STRING_GENERAL)
        require
            value_attached: a_value /= Void
        ensure
            one_more: count = old count + 1
            correct_type: last.is_string
        end

    extend_integer (a_value: INTEGER_64)
        ensure
            one_more: count = old count + 1
            correct_value: last.as_integer = a_value
        end

    extend_float (a_value: REAL_64)

    extend_boolean (a_value: BOOLEAN)

    extend_local_date (a_value: TOMELLE_LOCAL_DATE)

    extend_local_time (a_value: TOMELLE_LOCAL_TIME)

    extend_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME)

    extend_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME)

    extend_table (a_value: TOMELLE_TABLE)
        require
            value_attached: a_value /= Void
        end

    extend_array (a_value: TOMELLE_ARRAY)
        require
            value_attached: a_value /= Void
        end

    replace (a_value: TOMELLE_VALUE; a_index: INTEGER)
        require
            value_attached: a_value /= Void
            valid_index: valid_index (a_index)
        ensure
            replaced: item (a_index) = a_value
            same_count: count = old count
        end

    remove (a_index: INTEGER)
        require
            valid_index: valid_index (a_index)
        ensure
            one_less: count = old count - 1
        end

    wipe_out
        ensure
            empty: is_empty
        end

invariant
    non_negative_count: count >= 0

end
```

TOML arrays may contain values of different types. An array of tables is
exposed as a `TOMELLE_ARRAY` whose elements satisfy `is_table`.

## Table

`TOMELLE_TABLE` is a mutable mapping from Unicode keys to values. Direct-key
lookup and dotted-path lookup are deliberately separate.

```eiffel
class
    TOMELLE_TABLE

create
    make

feature {NONE} -- Initialization

    make
        ensure
            empty: is_empty
        end

feature -- Access

    item alias "[]" (
        a_key: READABLE_STRING_GENERAL
    ): detachable TOMELLE_VALUE
            -- Value directly associated with literal `a_key`, if present.
            -- A dot in `a_key` has no special meaning.
        require
            key_attached: a_key /= Void
        end

    value (a_path: TOMELLE_PATH): detachable TOMELLE_VALUE
            -- Value at exactly `a_path`, if present.
        require
            path_attached: a_path /= Void
        end

    value_at (
        a_key_expression: READABLE_STRING_GENERAL
    ): detachable TOMELLE_VALUE
            -- Value addressed by TOML dotted-key expression
            -- `a_key_expression`, if present.
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        end

    keys: ITERABLE [READABLE_STRING_32]
            -- Traversal over direct keys in stable source or insertion order.

feature -- Measurement

    count: INTEGER

    is_empty: BOOLEAN
        ensure
            definition: Result = (count = 0)
        end

feature -- Status report

    has_key (a_key: READABLE_STRING_GENERAL): BOOLEAN
            -- Is literal `a_key` directly present?
        require
            key_attached: a_key /= Void
        ensure
            definition: Result = (item (a_key) /= Void)
        end

    has (a_path: TOMELLE_PATH): BOOLEAN
        require
            path_attached: a_path /= Void
        ensure
            definition: Result = (value (a_path) /= Void)
        end

    has_at (a_key_expression: READABLE_STRING_GENERAL): BOOLEAN
        require
            expression_attached: a_key_expression /= Void
            expression_not_empty: not a_key_expression.is_empty
        ensure
            definition: Result = (value_at (a_key_expression) /= Void)
        end

feature -- Modification

    put (a_value: TOMELLE_VALUE; a_key: READABLE_STRING_GENERAL)
            -- Insert or replace a literal direct key.
        require
            value_attached: a_value /= Void
            key_attached: a_key /= Void
            key_not_empty: not a_key.is_empty
        ensure
            stored:
                attached item (a_key) as v and then v.is_equal (a_value)
        end

    put_string (a_value: READABLE_STRING_GENERAL;
        a_key: READABLE_STRING_GENERAL)

    put_integer (a_value: INTEGER_64; a_key: READABLE_STRING_GENERAL)

    put_float (a_value: REAL_64; a_key: READABLE_STRING_GENERAL)

    put_boolean (a_value: BOOLEAN; a_key: READABLE_STRING_GENERAL)

    put_local_date (a_value: TOMELLE_LOCAL_DATE;
        a_key: READABLE_STRING_GENERAL)

    put_local_time (a_value: TOMELLE_LOCAL_TIME;
        a_key: READABLE_STRING_GENERAL)

    put_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME;
        a_key: READABLE_STRING_GENERAL)

    put_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME;
        a_key: READABLE_STRING_GENERAL)

    put_table (a_value: TOMELLE_TABLE; a_key: READABLE_STRING_GENERAL)

    put_array (a_value: TOMELLE_ARRAY; a_key: READABLE_STRING_GENERAL)

    remove (a_key: READABLE_STRING_GENERAL)
            -- Remove a literal direct key if present.
        require
            key_attached: a_key /= Void
        ensure
            absent: not has_key (a_key)
        end

    wipe_out
        ensure
            empty: is_empty
        end

invariant
    non_negative_count: count >= 0

end
```

Regular tables and inline tables have the same public mutable representation.
Their syntactic origin is not part of the value API. The parser may retain this
information internally if required for validation or diagnostics.

## Paths

`TOMELLE_PATH` represents a sequence of literal keys. It is immutable after
creation.

```eiffel
class
    TOMELLE_PATH

create
    make,
    make_from_key,
    make_from_key_expression

feature {NONE} -- Initialization

    make (a_keys: ITERABLE [READABLE_STRING_GENERAL])
            -- Create a path from already separated literal keys.

    make_from_key (a_key: READABLE_STRING_GENERAL)
            -- Create a one-component path containing literal `a_key`.
            -- A dot in `a_key` has no special meaning.

    make_from_key_expression (
        a_key_expression: READABLE_STRING_GENERAL
    )
            -- Parse a TOML dotted-key expression.
        require
            valid_expression:
                (create {TOMELLE_KEY_SYNTAX}.make).is_valid_expression (
                    a_key_expression)

feature -- Access

    item alias "[]" (a_index: INTEGER): READABLE_STRING_32
        require
            valid_index: 1 <= a_index and a_index <= count
        end

    keys: ITERABLE [READABLE_STRING_32]

feature -- Measurement

    count: INTEGER

feature -- Element change

    extended (a_key: READABLE_STRING_GENERAL): TOMELLE_PATH
            -- New path with literal `a_key` appended.
            -- Leave Current unchanged.
        require
            key_attached: a_key /= Void
        ensure
            one_more: Result.count = count + 1
        end

end
```

`make_from_key_expression` must parse TOML key syntax rather than split the
input at every dot. For example, `server.%"physical.color%"` contains the two
keys `server` and `physical.color`.

`TOMELLE_KEY_SYNTAX` is a stateless portable validator. Clients that accept
dynamic expressions should retain one instance and call
`is_valid_expression` before invoking path creation or path-based mutation.

## Date and Time Values

Date and time classes are small immutable Tomelle value objects. They preserve
TOML semantics without requiring EiffelTime or Gobo Time.

```eiffel
expanded class
    TOMELLE_LOCAL_DATE

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create 0000-01-01.

    make (a_year, a_month, a_day: INTEGER)
        require
            valid_date: is_valid_date (a_year, a_month, a_day)
        ensure
            year_set: year = a_year
            month_set: month = a_month
            day_set: day = a_day
        end

feature -- Access

    year: INTEGER
    month: INTEGER
    day: INTEGER

feature -- Validation

    is_valid_date (a_year, a_month, a_day: INTEGER): BOOLEAN
            -- Do the components form a TOML/RFC 3339 full-date?

invariant
    valid_date: is_valid_date (year, month, day)

end
```

```eiffel
expanded class
    TOMELLE_LOCAL_TIME

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create 00:00:00 without a fractional part.

    make (a_hour, a_minute, a_second, a_nanosecond,
        a_fractional_digit_count: INTEGER)
        require
            valid_time: is_valid_time (a_hour, a_minute, a_second)
            valid_fraction:
                is_valid_fraction (a_nanosecond, a_fractional_digit_count)
        ensure
            hour_set: hour = a_hour
            minute_set: minute = a_minute
            second_set: second = a_second
            nanosecond_set: nanosecond = a_nanosecond
            fractional_digit_count_set:
                fractional_digit_count = a_fractional_digit_count
        end

feature -- Access

    hour: INTEGER
    minute: INTEGER
    second: INTEGER
    nanosecond: INTEGER
            -- Fractional second normalized to nanoseconds.

    fractional_digit_count: INTEGER
            -- Number of fractional digits preserved from the source.

feature -- Validation

    is_valid_time (a_hour, a_minute, a_second: INTEGER): BOOLEAN

    is_valid_fraction (a_nanosecond, a_digit_count: INTEGER): BOOLEAN
            -- Is the normalized fraction exactly representable using
            -- `a_digit_count` source digits?

invariant
    valid_time: is_valid_time (hour, minute, second)
    valid_fraction: is_valid_fraction (nanosecond, fractional_digit_count)

end
```

```eiffel
expanded class
    TOMELLE_LOCAL_DATE_TIME

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create 0000-01-01T00:00:00.

    make (a_date: TOMELLE_LOCAL_DATE; a_time: TOMELLE_LOCAL_TIME)
        ensure
            date_set: date = a_date
            time_set: time = a_time
        end

feature -- Access

    date: TOMELLE_LOCAL_DATE
    time: TOMELLE_LOCAL_TIME

end
```

```eiffel
expanded class
    TOMELLE_OFFSET_DATE_TIME

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create 0000-01-01T00:00:00Z.

    make (a_local_date_time: TOMELLE_LOCAL_DATE_TIME; a_offset_minutes: INTEGER)
        require
            valid_offset: -1439 <= a_offset_minutes and a_offset_minutes <= 1439
        ensure
            local_date_time_set: local_date_time = a_local_date_time
            offset_set: offset_minutes = a_offset_minutes
        end

feature -- Access

    local_date_time: TOMELLE_LOCAL_DATE_TIME
    offset_minutes: INTEGER
            -- Signed offset from UTC in minutes.

feature -- Status report

    is_utc: BOOLEAN
        ensure
            definition: Result = (offset_minutes = 0)
        end

invariant
    valid_offset: -1439 <= offset_minutes and offset_minutes <= 1439

end
```

The spelling `local_date_time` is intentional. `local` is an Eiffel reserved
word and therefore cannot be used as a feature name. This is the only naming
deviation from the corresponding TOML terminology.

Optional adapter libraries may convert these classes to Gobo or EiffelTime
objects. Such conversions are outside the core API.

## Errors

Parse and write errors contain stable machine-readable codes. Numeric code
values are part of the compatibility contract and must never be reassigned.

```eiffel
note
    description: "Stable machine-readable Tomelle error code."

expanded class
    TOMELLE_ERROR_CODE

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create `invalid_syntax`.

    make (a_value: INTEGER)
        require
            valid_value: is_valid_value (a_value)
        ensure
            value_set: value = a_value
        end

feature -- Access

    value: INTEGER
            -- Stable numeric representation.

    name: READABLE_STRING_8
            -- Stable ASCII symbolic name.
        ensure
            not_empty: not Result.is_empty
        end

feature -- Parse codes

    invalid_syntax: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 1 end

    invalid_utf_8: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 2 end

    input_unreadable: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 3 end

    integer_out_of_range: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 4 end

    duplicate_key: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 5 end

    invalid_key: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 6 end

    invalid_string: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 7 end

    invalid_number: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 8 end

    invalid_date_time: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 9 end

    unexpected_end_of_input: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 10 end

feature -- Write codes

    output_unwritable: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 101 end

    output_interrupted: TOMELLE_ERROR_CODE
        once ensure value: Result.value = 102 end

feature -- Status report

    is_valid_value (a_value: INTEGER): BOOLEAN
            -- Does `a_value` identify a code declared by this version?

    is_parse_code: BOOLEAN
        ensure
            definition: Result = (1 <= value and value <= 10)
        end

    is_write_code: BOOLEAN
        ensure
            definition: Result = (101 <= value and value <= 102)
        end

invariant
    valid_value: is_valid_value (value)

end
```

New codes may be added in later versions. Existing numeric values and symbolic
names are permanent. Consumers must compare `TOMELLE_ERROR_CODE` values rather
than diagnostic messages.

Parse errors are immutable and contain both a code and a human-readable
message.

```eiffel
class
    TOMELLE_PARSE_ERROR

feature -- Access

    code: TOMELLE_ERROR_CODE
            -- Stable error classification.

    message: READABLE_STRING_32
            -- Human-readable explanation.

    source_name: detachable READABLE_STRING_32
            -- Source file name, when available.

    position: TOMELLE_SOURCE_POSITION
            -- Position at which the error was detected.

feature -- Classification

    is_syntax_error: BOOLEAN
        ensure
            definition:
                Result = (code.is_parse_code and then
                    code /= code.invalid_utf_8 and then
                    code /= code.input_unreadable)
        end

    is_encoding_error: BOOLEAN
        ensure
            definition: Result = (code = code.invalid_utf_8)
        end

    is_input_error: BOOLEAN
        ensure
            definition: Result = (code = code.input_unreadable)
        end

invariant
    parse_code: code.is_parse_code

end
```

```eiffel
expanded class
    TOMELLE_SOURCE_POSITION

create
    default_create,
    make

feature {NONE} -- Initialization

    default_create
            -- Create the start position: byte 0, line 1, column 1.

    make (a_byte_offset, a_line, a_column: INTEGER)
        require
            non_negative_byte_offset: a_byte_offset >= 0
            positive_line: a_line >= 1
            positive_column: a_column >= 1

feature -- Access

    byte_offset: INTEGER
    line: INTEGER
    column: INTEGER

invariant
    non_negative_byte_offset: byte_offset >= 0
    positive_line: line >= 1
    positive_column: column >= 1

end
```

Tests should assert stable error codes and positions, not exact diagnostic
messages.

## Generic Value Construction

Concrete scalar descendants of `TOMELLE_VALUE` remain private. Most clients
use the typed commands on documents, tables, and arrays. Code that determines
types dynamically can create standalone values through
`TOMELLE_VALUE_FACTORY`.

```eiffel
note
    description: "Factory for scalar and structured TOML values."

class
    TOMELLE_VALUE_FACTORY

create
    make

feature {NONE} -- Initialization

    make
        ensure
            ready: True
        end

feature -- Scalar values

    new_string (a_value: READABLE_STRING_GENERAL): TOMELLE_VALUE
        require
            value_attached: a_value /= Void
            valid_unicode: is_valid_unicode (a_value)
        ensure
            is_string: Result.is_string
            value_preserved: Result.as_string.same_string_general (a_value)
        end

    new_integer (a_value: INTEGER_64): TOMELLE_VALUE
        ensure
            is_integer: Result.is_integer
            value_preserved: Result.as_integer = a_value
        end

    new_float (a_value: REAL_64): TOMELLE_VALUE
        ensure
            is_float: Result.is_float
            value_preserved_or_nan:
                Result.as_float = a_value or else
                (Result.as_float /= Result.as_float and a_value /= a_value)
        end

    new_float_from_text (a_source: READABLE_STRING_GENERAL): TOMELLE_VALUE
            -- Exact conversion from a finite decimal representation.
        require
            valid_source: is_valid_float_text (a_source)
        ensure
            is_float: Result.is_float
        end

    new_boolean (a_value: BOOLEAN): TOMELLE_VALUE
        ensure
            is_boolean: Result.is_boolean
            value_preserved: Result.as_boolean = a_value
        end

    new_offset_date_time (a_value: TOMELLE_OFFSET_DATE_TIME): TOMELLE_VALUE
        ensure
            is_offset_date_time: Result.is_offset_date_time
            value_preserved: Result.as_offset_date_time = a_value
        end

    new_local_date_time (a_value: TOMELLE_LOCAL_DATE_TIME): TOMELLE_VALUE
        ensure
            is_local_date_time: Result.is_local_date_time
            value_preserved: Result.as_local_date_time = a_value
        end

    new_local_date (a_value: TOMELLE_LOCAL_DATE): TOMELLE_VALUE
        ensure
            is_local_date: Result.is_local_date
            value_preserved: Result.as_local_date = a_value
        end

    new_local_time (a_value: TOMELLE_LOCAL_TIME): TOMELLE_VALUE
        ensure
            is_local_time: Result.is_local_time
            value_preserved: Result.as_local_time = a_value
        end

feature -- Structured values

    new_array (a_value: TOMELLE_ARRAY): TOMELLE_VALUE
        require
            value_attached: a_value /= Void
        ensure
            is_array: Result.is_array
            value_preserved: Result.as_array.is_equal (a_value)
            independent: Result.as_array /= a_value
        end

    new_table (a_value: TOMELLE_TABLE): TOMELLE_VALUE
        require
            value_attached: a_value /= Void
        ensure
            is_table: Result.is_table
            value_preserved: Result.as_table.is_equal (a_value)
            independent: Result.as_table /= a_value
        end

feature -- Validation

    is_valid_float_text (a_source: READABLE_STRING_GENERAL): BOOLEAN
            -- Can `a_source` be passed to `new_float_from_text`?
        end

    is_valid_unicode (a_value: READABLE_STRING_GENERAL): BOOLEAN
            -- Does `a_value` contain only Unicode scalar values?
        require
            value_attached: a_value /= Void
        end

end
```

TOML has no null value, so the factory intentionally has no `new_null`
feature. `new_float` accepts finite values, infinities, and NaN.
`new_float_from_text` is the compiler-independent path for exact decimal input;
its canonical text is available through `as_float_text` and is used by the
writer.

## Serialization

`TOMELLE_WRITER` serializes any valid `TOMELLE_DOCUMENT`, whether parsed or
programmatically constructed. String serialization is a side-effect-free
query. File serialization is a command because it can fail due to I/O.

```eiffel
note
    description: "Deterministic TOML text and UTF-8 file serializer."

class
    TOMELLE_WRITER

create
    make

feature {NONE} -- Initialization

    make
        ensure
            not_written: not is_written
            no_error: error = Void
        end

feature -- Serialization

    serialized (a_document: TOMELLE_DOCUMENT): STRING_32
            -- Deterministic TOML representation of `a_document`.
        require
            document_attached: a_document /= Void
        ensure
            result_attached: Result /= Void
            valid_toml: is_valid_toml (Result)
        end

    write_file (a_document: TOMELLE_DOCUMENT; a_path: PATH)
            -- Atomically write UTF-8 TOML without a byte-order mark.
        require
            document_attached: a_document /= Void
            path_attached: a_path /= Void
            path_not_empty: not a_path.is_empty
        ensure
            written: is_written
            result_consistent: is_successful = (error = Void)
        end

    reset
        ensure
            not_written: not is_written
            no_error: error = Void
        end

feature -- Status report

    is_written: BOOLEAN
            -- Has a file write been attempted since creation or reset?

    is_successful: BOOLEAN
        ensure
            definition: Result = (is_written and then error = Void)
        end

feature -- Error

    error: detachable TOMELLE_WRITE_ERROR
            -- Error from the last failed file write.

feature {NONE} -- Validation

    is_valid_toml (a_text: READABLE_STRING_GENERAL): BOOLEAN
            -- Is `a_text` a syntactically valid TOML 1.1 document?

invariant
    not_written_has_no_error: not is_written implies error = Void
    failed_has_error: is_written and then not is_successful implies error /= Void

end
```

```eiffel
note
    description: "Immutable TOML file serialization error."

class
    TOMELLE_WRITE_ERROR

feature -- Access

    code: TOMELLE_ERROR_CODE
        ensure
            write_code: Result.is_write_code
        end

    message: READABLE_STRING_32

    target_name: READABLE_STRING_32

end
```

File replacement is transactional: if encoding or writing fails, an existing
target file remains unchanged whenever the host file system supports atomic
replacement. Each attempt uses a uniquely named sibling temporary file so
concurrent writers do not collide. Temporary files must not remain after a
handled failure.

### Serialization Policy

Tomelle guarantees semantic, not lexical, round-tripping:

```text
parse (writer.serialized (document)) ≡ document
```

Here equivalence means the same keys, values, array order, date/time precision,
and table structure. Comments, whitespace, quote style, numeric base, numeric
underscores, and whether a table originated as an inline table are not part of
the object model and are not preserved.

The writer must:

- emit valid TOML 1.1;
- use stable table insertion/source order and array order;
- choose one deterministic representation for strings, keys, integers,
  finite floats, infinities, NaN, and temporal values;
- serialize every non-root `TOMELLE_TABLE` canonically as an inline table;
  this avoids depending on whether it was parsed from a regular table, inline
  table, or an array-of-tables declaration;
- preserve `fractional_digit_count` when writing local times;
- escape keys and strings when required;
- end non-empty output with a single line feed;
- never expose a partially written target file as a successful result.

## Usage

### Parse a string

```eiffel
create parser.make
parser.parse_string (source)

if parser.is_successful then
    check attached parser.document as document then
        if attached document.value_at ("database.port") as value then
            if value.is_integer then
                print (value.as_integer)
            end
        end
    end
else
    across parser.errors as error loop
        print (error.message)
    end
end
```

### Read an array of tables

```eiffel
if attached document.value_at ("servers") as value and then
    value.is_array
then
    across value.as_array as element loop
        if element.is_table then
            if attached element.as_table ["host"] as host and then
                host.is_string
            then
                print (host.as_string)
            end
        end
    end
end
```

### Read a date

```eiffel
if attached document.value_at ("release.date") as value and then
    value.is_local_date
then
    print (value.as_local_date.year)
end
```

### Edit and rewrite a parsed configuration

```eiffel
create parser.make
parser.parse_file (config_path)

if attached parser.document as config then
    config.put_string_at ("production", "application.environment")
    config.put_integer_at (8081, "server.port")
    config.remove_at ("server.legacy_timeout")

    create writer.make
    writer.write_file (config, config_path)

    if not writer.is_successful then
        check attached writer.error as write_error then
            print (write_error.message)
        end
    end
end
```

To apply changes only after an external operation succeeds, edit an independent
copy:

```eiffel
working_config := config.independent_copy
working_config.put_integer_at (8081, "server.port")

if external_command_succeeded then
    writer.write_file (working_config, config_path)
end
```

### Create and serialize a document

```eiffel
create document.make

document.put_integer_at (5432, "database.port")
document.put_string_at ("localhost", "database.host")

create writer.make
text := writer.serialized (document)
writer.write_file (document, output_path)

if not writer.is_successful then
    check attached writer.error as write_error then
        print (write_error.message)
    end
end
```

### Create an array

```eiffel
create values.make
values.extend_string ("alpha")
values.extend_integer (2)
document.put_array_at (values, "values")
```

## Construction and Mutability

`TOMELLE_DOCUMENT`, `TOMELLE_TABLE`, and `TOMELLE_ARRAY` are mutable reference
objects. The document returned by a parser can be edited directly and then
passed to a writer. Scalar `TOMELLE_VALUE` instances and expanded temporal
values remain immutable.

Structured access returns live objects owned by the document. For example,
mutating `document.table_at ("server")` immediately mutates `document`. Clients
must not concurrently mutate the same object tree without their own
synchronization.

`independent_copy` provides opt-in isolation. It recursively copies all tables,
arrays, keys, strings, and scalar value wrappers, so changes to either document
cannot affect the other. This supports external-command workflows without
forcing every ordinary edit through a separate editing object.

## Compatibility Policy

The core library target depends only on ELKS/FreeELKS. Public signatures must
not contain classes owned exclusively by EiffelStudio, Gobo, or another
compiler ecosystem.

Compiler- or library-specific integrations must be separate optional targets.
This permits applications to opt into convenient date/time conversions without
making those dependencies mandatory for all Tomelle users.

## Required API Tests

The public API test suite should demonstrate:

- parsing a minimal document;
- reading every TOML value type through `is_*` and `as_*`;
- nested dotted-key lookup;
- quoted keys containing dots;
- the distinction between literal-key and path lookup;
- heterogeneous arrays;
- arrays of tables;
- inline tables;
- parser reuse and `reset`;
- duplicate-key errors;
- syntax error positions;
- missing or unreadable input files;
- invalid UTF-8 input;
- stability of every declared numeric error code;
- construction of every TOML scalar type through `TOMELLE_VALUE_FACTORY`;
- construction of nested tables, heterogeneous arrays, arrays of tables, and
  inline-table values through the mutable model;
- typed upserts on documents, tables, and arrays;
- idempotent path and direct-key removal;
- rejection of paths whose intermediate value is not a table;
- direct nested mutation through `table_at` and `array_at`;
- independence of `independent_copy` after mutations to either document;
- deterministic serialization of every TOML value type;
- correct escaping of Unicode strings and quoted keys;
- preservation of table order, array order, and fractional-second precision;
- semantic parse-serialize-parse round-trips;
- UTF-8 file output without a byte-order mark;
- writer reuse and `reset`;
- unwritable output paths and preservation of an existing target after a
  failed write.
