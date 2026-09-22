#!/usr/bin/env bash

#                 AxonASP Caddy Module Build Script
#
# AxonASP Server - Caddy Module
# Copyright (C) 2026 G3pix Ltda. All rights reserved.
#
# Developed by Lucas Guimarães - G3pix Ltda
# Contact: https://g3pix.com.br
# Project URL: https://g3pix.com.br/axonasp
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.
#
# Attribution Notice:
# If this software is used in other projects, the name "AxonASP Server"
# must be cited in the documentation or "About" section.
#
# Contribution Policy:
# Modifications to the core source code of AxonASP Server must be
# made available under this same license terms.
#

# --- Defaults ---
PLATFORM="linux"
ARCHITECTURE="amd64"
CLEAN=0
TEST=0
TAGS=""

# --- Argument Parsing ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --platform|-p) PLATFORM="$2"; shift ;;
        --arch|-a) ARCHITECTURE="$2"; shift ;;
        --clean|-c) CLEAN=1 ;;
        --test|-t) TEST=1 ;;
        --tags|-g) TAGS="$2"; shift ;;
        *) echo -e "\033[0;31mUnknown parameter passed: $1\033[0m"; exit 1 ;;
    esac
    shift
done

# Normalize Go build tags so users can pass comma/semicolon/space-separated values.
NORMALIZED_TAGS=$(echo "$TAGS" | tr ',;' '  ' | xargs)

# --- Validate Parameters ---
if [[ ! "$PLATFORM" =~ ^(windows|linux|darwin|all)$ ]]; then
    echo "Invalid platform: $PLATFORM. Allowed: windows, linux, darwin, all."
    exit 1
fi
if [[ ! "$ARCHITECTURE" =~ ^(amd64|arm64|386|all)$ ]]; then
    echo "Invalid architecture: $ARCHITECTURE. Allowed: amd64, arm64, 386, all."
    exit 1
fi

# --- AUTOMATIC VERSION CONFIGURATION ---
MAJOR="2"
MINOR="3"
PATCH="0"
REVISION="0"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    GIT_TAG=$(git describe --tags --abbrev=0 2>/dev/null)
    
    REGEX="^v?([0-9]+)\.([0-9]+)\.([0-9]+)$"
    
    if [[ $GIT_TAG =~ $REGEX ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
    else
        PATCH=$(git rev-list --count HEAD | xargs)
    fi

    REVISION=$(git rev-parse --short HEAD | xargs)
else
    echo -e "\033[1;33mGit not found or not a valid repository. Using default versioning.\033[0m"
fi

FULL_VERSION="$MAJOR.$MINOR.$PATCH.$REVISION"

# --- Color output functions ---
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
MAGENTA='\033[0;35m'
WHITE='\033[1;37m'
DARKGRAY='\033[1;30m'
NC='\033[0m' # No Color

write_success() { echo -e "${GREEN}$1${NC}"; }
write_info() { echo -e "${CYAN}$1${NC}"; }
write_err() { echo -e "${RED}$1${NC}"; }
write_warn() { echo -e "${YELLOW}$1${NC}"; }

# Script header
echo ""
echo -e "${MAGENTA}=======================================================${NC}"
echo -e " ${WHITE} G3Pix ❖ AxonASP Caddy Module Build Script${NC}"
echo -e " ${CYAN} Version: $FULL_VERSION${NC}"
if [ -n "$NORMALIZED_TAGS" ]; then
    echo -e " ${YELLOW} Build Tags: $NORMALIZED_TAGS${NC}"
fi
echo -e "${MAGENTA}=======================================================${NC}"
echo ""

# Set Working Directory to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR" || exit 1

PARENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Clean previous builds
if [ "$CLEAN" -eq 1 ]; then
    write_info "Cleaning previous builds..."
    rm -f caddy caddy.exe caddy-*
    rm -rf build
    write_success "Cleaned."
    echo ""
fi

# Find or install xcaddy
if ! command -v xcaddy &> /dev/null; then
    write_info "xcaddy not found. Installing xcaddy..."
    go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    export PATH="$PATH:$(go env GOPATH)/bin"
fi

BUILD_SUCCESS=true

build_binary() {
    local target_os="$1"
    local target_arch="$2"
    local output_name="$3"
    local label="$4"

    export GOOS="$target_os"
    export GOARCH="$target_arch"
    export CGO_ENABLED=0

    local extension=""
    if [ "$target_os" == "windows" ]; then
        extension=".exe"
    fi

    local output_file="${output_name}${extension}"
    local output_dir
    output_dir="$(dirname "$output_file")"
    if [ -n "$output_dir" ] && [ "$output_dir" != "." ]; then
        mkdir -p "$output_dir"
    fi

    write_info "Building $label ($target_os/$target_arch) -> $output_file ..."

    # xcaddy resolves the Caddy core and every transitive dependency. The only
    # override required here is the local checkout of the runtime module, since
    # replace directives of dependency modules are ignored by the Go toolchain.
    local build_output
    build_output=$(xcaddy build \
        --output "$output_file" \
        --with g3pix.com.br/axonasp/caddy=. \
        --replace "g3pix.com.br/axonasp/v2=$PARENT_DIR" 2>&1)
    local exit_code=$?

    if [ $exit_code -eq 0 ] && [ -f "$output_file" ]; then
        local bytes
        bytes=$(wc -c < "$output_file")
        local size_mb
        size_mb=$(awk "BEGIN {printf \"%.2f\", $bytes / 1048576}")
        write_success "  [OK] $output_file ($size_mb MB)"

        # Populate root convenience binaries for standard targets
        if [ "$target_os" == "linux" ] && [ "$target_arch" == "amd64" ]; then
            cp -f "$output_file" "caddy-linux-amd64" 2>/dev/null || true
            if [ ! -f "caddy" ]; then
                cp -f "$output_file" "caddy" 2>/dev/null || true
            fi
        fi
        if [ "$target_os" == "windows" ] && [ "$target_arch" == "amd64" ] && [ ! -f "caddy.exe" ]; then
            cp -f "$output_file" "caddy.exe" 2>/dev/null || true
        fi
        return 0
    else
        write_err "  [FAIL] $label ($target_os/$target_arch)"
        if [ -n "$build_output" ]; then echo "$build_output"; fi
        return 1
    fi
}

# --- Fix, format and generate before any build pass ---
write_info "Fixing source..."
go fix ./... > /dev/null 2>&1

write_info "Formatting source..."
gofmt -w . > /dev/null 2>&1

write_info "Running go generate..."
go generate ./... > /dev/null 2>&1
echo ""

get_architectures() {
    local os="$1"
    local arch_input="$2"

    if [ "$arch_input" == "all" ]; then
        if [ "$os" == "darwin" ]; then
            echo "amd64 arm64"
        else
            echo "amd64 arm64 386"
        fi
    else
        echo "$arch_input"
    fi
}

run_platform() {
    local os="$1"
    local arch_input="$2"

    local arch_list
    arch_list=$(get_architectures "$os" "$arch_input")

    for arch in $arch_list; do
        if [ "$os" == "darwin" ] && [ "$arch" == "386" ]; then
            write_warn "Skipping darwin/386 (unsupported by Go runtime)"
            continue
        fi

        echo -e "${DARKGRAY}-------------------------------------------------------${NC}"
        echo -e " ${YELLOW}Building Caddy for $os/$arch${NC}"
        echo -e "${DARKGRAY}-------------------------------------------------------${NC}"

        local out_name="build/$os-$arch/caddy"
        if [ "$os" == "linux" ] && [ "$PLATFORM" == "linux" ] && [ "$arch" == "amd64" ]; then
            out_name="caddy"
        elif [ "$os" == "windows" ] && [ "$PLATFORM" == "windows" ] && [ "$arch" == "amd64" ]; then
            out_name="caddy"
        fi

        build_binary "$os" "$arch" "$out_name" "AxonASP Caddy Server"
        if [ $? -ne 0 ]; then
            BUILD_SUCCESS=false
        fi
        echo ""
    done
}

# Execute Platform Builds
if [[ "$PLATFORM" == "linux"   || "$PLATFORM" == "all" ]]; then run_platform "linux"   "$ARCHITECTURE"; fi
if [[ "$PLATFORM" == "windows" || "$PLATFORM" == "all" ]]; then run_platform "windows" "$ARCHITECTURE"; fi
if [[ "$PLATFORM" == "darwin"  || "$PLATFORM" == "all" ]]; then run_platform "darwin"  "$ARCHITECTURE"; fi

# Reset environment variables to native host
unset GOOS
unset GOARCH
unset CGO_ENABLED

# --- Tests ---
if [ "$TEST" -eq 1 ]; then
    echo -e "${DARKGRAY}-------------------------------------------------------${NC}"
    echo -e " ${YELLOW}Running Tests${NC}"
    echo -e "${DARKGRAY}-------------------------------------------------------${NC}"
    echo ""

    write_info "Running go test ./..."
    test_output=$(go test ./... 2>&1)
    test_exit=$?

    if [ $test_exit -eq 0 ]; then
        write_success "[OK] All tests passed"
    else
        write_err "[FAIL] Some tests failed"
        echo "$test_output"
        BUILD_SUCCESS=false
    fi
    echo ""
fi

# --- Summary ---
echo -e "${MAGENTA}=======================================================${NC}"

if [ "$BUILD_SUCCESS" = true ]; then
    write_success "  BUILD SUCCESSFUL  (v$FULL_VERSION)"
    echo ""
    echo -e " ${WHITE} Executables:${NC}"

    for file in caddy caddy.exe caddy-linux-amd64; do
        if [ -f "$file" ]; then echo -e "    - ${CYAN}$file${NC}"; fi
    done

    if [ -d "build" ]; then
        find build -type f | while read -r file; do
            echo -e "    - ${CYAN}$file${NC}"
        done
    fi

    echo ""
    echo -e " ${WHITE} Quick Start:${NC}"
    echo -e "    ${DARKGRAY}Run Server (Linux)   : ./caddy run --config ./Caddyfile${NC}"
    echo -e "    ${DARKGRAY}Run Server (Windows) : ./caddy.exe run --config ./Caddyfile${NC}"
    echo -e "    ${DARKGRAY}Run as systemd       : systemctl start caddy${NC}"

    echo -e "${MAGENTA}=======================================================${NC}"
    echo ""
    exit 0
else
    write_err "  BUILD FAILED!"
    echo ""
    echo -e "  ${YELLOW}Check the error messages above for details.${NC}"
    echo -e "${MAGENTA}=======================================================${NC}"
    echo ""
    exit 1
fi
