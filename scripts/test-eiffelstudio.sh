#!/usr/bin/env sh
set -eu

SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/.." && pwd)

command -v ec >/dev/null 2>&1 || {
    echo "ec is required; install EiffelStudio and add its bin directory to PATH" >&2
    exit 2
}
command -v finish_freezing >/dev/null 2>&1 || {
    echo "finish_freezing is required; add EiffelStudio's bin directory to PATH" >&2
    exit 2
}

cd "$PROJECT_DIRECTORY"

# Compile every library class, including classes not used by the examples.
ec -batch -config tomelle.ecf -target tomelle -finalize

build_and_run () {
    target=$1
    ec -batch -config examples/system.ecf -target "$target" -finalize
    (cd "EIFGENs/$target/F_code" && finish_freezing)
    "EIFGENs/$target/F_code/tomelle_examples"
}

build_and_run parse_string
build_and_run parse_file
