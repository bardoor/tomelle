#!/usr/bin/env sh
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/.." && pwd)
OUTPUT_DIRECTORY="$PROJECT_DIRECTORY/.cache/examples"

mkdir -p "$OUTPUT_DIRECTORY"
cd "$PROJECT_DIRECTORY"

gec --finalize --target=parse_string examples/system.ecf
mv tomelle_examples "$OUTPUT_DIRECTORY/parse_string"
"$OUTPUT_DIRECTORY/parse_string"

gec --finalize --target=parse_file examples/system.ecf
mv tomelle_examples "$OUTPUT_DIRECTORY/parse_file"
"$OUTPUT_DIRECTORY/parse_file"
