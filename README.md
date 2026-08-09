<div align="center">

# `tomelle`

### TOML 1.1 for Eiffel

[![Language: Eiffel](https://img.shields.io/badge/language-Eiffel-6f42c1)](https://www.eiffel.org/)
[![ISE Eiffel](https://img.shields.io/badge/toolchain-ISE%20Eiffel-17365D)](https://www.eiffel.com/)
[![Gobo Eiffel](https://img.shields.io/badge/toolchain-Gobo%20Eiffel-8B5A2B)](https://www.gobosoft.com/)

</div>

`tomelle` is a void-safe Eiffel library for reading and writing TOML. It works
with EiffelStudio and Gobo Eiffel.

[API overview](docs/api_overview.md)

## Features

- Full TOML 1.1 decoder and encoder support. The library passes every case in
  `toml-test` v2.2.0: 214 valid, 214 encoder, and 467 invalid cases.
- UTF-8 and Unicode strings, keys, and escapes. Malformed UTF-8 is rejected.
- Typed values for strings, integers, floats, booleans, dates, times, arrays,
  and tables.
- Dotted-key access for reading and updating nested values.
- Deterministic TOML serialization.
- Void-safe API with preconditions, postconditions, and class invariants.

## Installation

Add `tomelle` to an Eiffel project as a Git submodule:

```console
git submodule add https://github.com/samedit66/tomelle.git vendor/tomelle
git submodule update --init --recursive
```

Reference the library from the consuming project's ECF file:

```xml
<library name="tomelle" location="./vendor/tomelle/tomelle.ecf" readonly="true"/>
```

The same ECF works with both supported compilers. EiffelStudio uses its Base
library directly and does not require Gobo to be installed. Gobo Eiffel uses
FreeELKS when `GOBO_EIFFEL=ge`, as set by the Gobo toolchain.


## Usage

### Parse a string

```eiffel
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
```

The complete source is in
[`examples/parse_string.e`](examples/parse_string.e).

### Parse a file

Given `config.toml`:

```toml
title = "Tomelle example"

[server]
host = "127.0.0.1"
port = 8080
```

Read a typed value by its dotted key:

```eiffel
class
    PARSE_FILE

create
    make

feature {NONE} -- Initialization

    make
        local
            parser: TOMELLE_PARSER
            config_path: PATH
            document: TOMELLE_DOCUMENT
            port: TOMELLE_VALUE
        do
            create config_path.make_from_string ("examples/config.toml")
            create parser.make
            parser.parse_file (config_path)

            if parser.is_successful then
                check attached parser.document as parsed_document then
                    document := parsed_document
                end
                if attached document.value_at ("server.port") as parsed_port then
                    port := parsed_port
                    print (port.as_integer)
                    print ("%N")
                end
            end
        end

end
```

The complete source is in [`examples/parse_file.e`](examples/parse_file.e).
Build and run both examples from the repository root:

```console
./examples/run.sh
```

## Building

With EiffelStudio:

```console
ec -config tomelle.ecf -target tomelle -finalize
```

With Gobo Eiffel:

```console
gec tomelle.ecf
```

## Tests

Run the unit tests from the repository root:

```console
getest tests/getest.ge
```

Compile the library and run both examples with EiffelStudio:

```console
./scripts/test-eiffelstudio.sh
```

Run the complete TOML 1.1 conformance suite:

```console
./scripts/toml-test.sh
```

The conformance script builds the decoder and encoder adapters, downloads
`toml-test` v2.2.0 for macOS or Linux, verifies its SHA-256 checksum, and runs
all valid, invalid, and encoder cases. Set `TOML_TEST_PARALLEL` to change the
default parallelism of 4.
