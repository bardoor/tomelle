#!/usr/bin/env sh
set -eu

TOML_TEST_VERSION=2.2.0
SCRIPT_DIRECTORY=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_DIRECTORY=$(CDPATH= cd -- "$SCRIPT_DIRECTORY/.." && pwd)
CACHE_DIRECTORY="$PROJECT_DIRECTORY/.cache/toml-test/$TOML_TEST_VERSION"
RUNNER="$CACHE_DIRECTORY/toml-test"
DECODER="$CACHE_DIRECTORY/toml_test_decoder"
ENCODER="$CACHE_DIRECTORY/toml_test_encoder"

case "$(uname -s):$(uname -m)" in
    Darwin:x86_64)
        PLATFORM=darwin-amd64
        CHECKSUM=17e0365948ab7da54e0541bf22dce7dc809e407cd1e14bf78576cfbfd48ffee1
        ;;
    Darwin:arm64)
        PLATFORM=darwin-arm64
        CHECKSUM=f36b1310b03a95dfa6b92ef535018db8ccc997ba20e79f3fd28d0f97c9174f35
        ;;
    Linux:x86_64)
        PLATFORM=linux-amd64
        CHECKSUM=08f9e0a97da1151c33debf01358a8f5ef45e2a56be201241ae5eb5c2e9323fef
        ;;
    Linux:aarch64 | Linux:arm64)
        PLATFORM=linux-arm64
        CHECKSUM=2f2e7f3e7cdbaa252bd6a3f1480f044b25aaf7a76353eb8f229ce8befa5a82b3
        ;;
    *)
        echo "Unsupported platform: $(uname -s) $(uname -m)" >&2
        exit 2
        ;;
esac

command -v gec >/dev/null 2>&1 || {
    echo "gec is required; install Gobo Eiffel and add GOBO/bin to PATH" >&2
    exit 2
}

mkdir -p "$CACHE_DIRECTORY"
ARCHIVE="$CACHE_DIRECTORY/toml-test-$PLATFORM.gz"
URL="https://github.com/toml-lang/toml-test/releases/download/v$TOML_TEST_VERSION/toml-test-v$TOML_TEST_VERSION-$PLATFORM.gz"

if [ ! -x "$RUNNER" ]; then
    curl --fail --location --silent --show-error "$URL" --output "$ARCHIVE"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL_CHECKSUM=$(sha256sum "$ARCHIVE" | awk '{print $1}')
    else
        ACTUAL_CHECKSUM=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
    fi
    if [ "$ACTUAL_CHECKSUM" != "$CHECKSUM" ]; then
        echo "Checksum mismatch for $URL" >&2
        exit 1
    fi
    gzip -dc "$ARCHIVE" > "$RUNNER"
    chmod +x "$RUNNER"
fi

cd "$PROJECT_DIRECTORY"
gec --finalize --target=toml_test_decoder conformance/system.ecf
mv tomelle_conformance "$DECODER"
gec --finalize --target=toml_test_encoder conformance/system.ecf
mv tomelle_conformance "$ENCODER"

NO_COLOR=1 "$RUNNER" test \
    -toml=1.1 \
    -decoder="$DECODER" \
    -encoder="$ENCODER" \
    -parallel="${TOML_TEST_PARALLEL:-4}" \
    -color=never
