#!/bin/bash

# Scripts for scheduling print quality diagnostics reports (PQ Diagnostics)
# on HP printers, for Windows, MacOS and Linux.
#
# This file is a part of the https://github.com/vegz78/pqdiag repository.
#
# Feel free to use and develop, but don't forget to inlcude proper attribution
# to the developer.
#
# MIT License * * Copyright (c) 2024 Vegz78
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# Scripts for scheduling print quality diagnostics reports (PQ Diagnostics)
# on HP printers, for Windows, MacOS and Linux.
#
# Exit codes:
#   0 = OK (printed and acknowledged)
#   1 = Failed (printer unreachable, busy, or rejected request - safe to retry)
#   2 = Invalid argument (bad IP, hostname, or missing parameter)
#   3 = Ambiguous (job sent, but acknowledgment timed out - do not auto-retry)

MAX_TIME=10
CONNECT_TIMEOUT=5
SCHEMA_HOST="www.hp.com"
SCHEMA_PATH="/schemas/imaging/con/ledm/internalprintdyn/2008/03/21"
XML="<?xml version=\"1.0\" encoding=\"UTF-8\"?><ipdyn:InternalPrintDyn xmlns:ipdyn=\"http://${SCHEMA_HOST}${SCHEMA_PATH}\"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>"

validate_target() {
    local t="$1"
    [ -z "$t" ] && return 1
    case "$t" in .*|*..*|*.) return 1 ;; esac

    # Check IPv4 format and valid octet ranges (0-254.0-255.0-255.0-254)
    if printf '%s\n' "$t" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        local IFS=.
        set -- $t
        [ "$1" -ge 0 ] && [ "$1" -le 254 ] &&
        [ "$2" -ge 0 ] && [ "$2" -le 255 ] &&
        [ "$3" -ge 0 ] && [ "$3" -le 255 ] &&
        [ "$4" -ge 0 ] && [ "$4" -le 254 ]
        return $?
    fi

    # Check valid hostname (alphanumeric, dots, hyphens, must contain at least one letter)
    printf '%s\n' "$t" | grep -Eq '^[a-zA-Z0-9.-]+$' && printf '%s\n' "$t" | grep -Eq '[a-zA-Z]'
}

# Branch 1: USB target ("usb" or "usb:N") -> resolve local ipp-usb (Linux) or ippusbd (macOS) port
ARG_LOWER=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
if [ "$ARG_LOWER" = "usb" ] || [ "${ARG_LOWER#usb:}" != "$ARG_LOWER" ]; then
    USB_IDX=1
    case "$ARG_LOWER" in usb:*) USB_IDX="${ARG_LOWER#usb:}" ;; esac
    if ! printf '%s\n' "$USB_IDX" | grep -Eq '^[1-9][0-9]*$'; then
        echo "Invalid USB index \"$1\". Use \"usb\" or \"usb:1\", \"usb:2\", ..." >&2
        exit 2
    fi

    USB_PORT=""
    case "$(uname -s)" in
        Darwin)
            # macOS built-in ippusbd runs on-demand and binds ephemeral localhost TCP ports
            get_macos_port() { lsof -iTCP -sTCP:LISTEN -nP 2>/dev/null | awk '/ippusbd/ {print $9}' | sed 's/.*://' | awk '!seen[$0]++' | sed -n "${USB_IDX}p"; }
            USB_PORT=$(get_macos_port)
            if [ -z "$USB_PORT" ] && command -v ippfind >/dev/null 2>&1; then
                ippfind -T 1 >/dev/null 2>&1
                USB_PORT=$(get_macos_port)
            fi
            ;;
        *)
            # Linux ipp-usb binds sequential localhost ports starting at 60000
            CANDIDATE=$((59999 + USB_IDX))
            if curl -s -o /dev/null --connect-timeout 1 --max-time "$MAX_TIME" "http://localhost:${CANDIDATE}/DevMgmt/ProductStatusDyn.xml" 2>/dev/null; then
                USB_PORT="$CANDIDATE"
            fi
            ;;
    esac
    if [ -z "$USB_PORT" ]; then
        echo "PQ diagnostics did NOT print! (No active ipp-usb/ippusbd USB printer found)" >&2
        exit 1
    fi
    TARGET_LABEL="USB"
    TARGET_URL="http://localhost:${USB_PORT}/DevMgmt/InternalPrintDyn.xml"

# Branch 2: Network target (IPv4 address or hostname) -> direct LEDM HTTP on port 8080
elif validate_target "$1"; then
    TARGET_LABEL="$1"
    TARGET_URL="http://$1:8080/DevMgmt/InternalPrintDyn.xml"

# Branch 3: Invalid or missing argument
else
    echo "The argument \"$1\" is not a valid IPv4 address, hostname, or \"usb\"..." >&2
    echo "Please try again like this: ./pqdiag.sh 192.0.0.10 (using your HP printer's IP, hostname, or \"usb\")" >&2
    exit 2
fi

# Send POST trigger with LEDM XML payload and map curl exit code to script exit codes
echo "Sending print quality diagnostics job to HP_printer@${TARGET_LABEL}!"
curl -f --max-time "$MAX_TIME" --connect-timeout "$CONNECT_TIMEOUT" \
    -H "User-Agent:" -H "Host: localhost" -H "Accept:" \
    -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" \
    --data-binary "$XML" --http1.1 "$TARGET_URL" >/dev/null 2>&1
CURL_EXIT=$?

if [ "$CURL_EXIT" -eq 0 ]; then
    echo "PQ diagnostics printed OK!"
    exit 0
elif [ "$CURL_EXIT" -eq 28 ]; then
    echo "PQ diagnostics sent, but confirmation timed out (check printer)." >&2
    exit 3
else
    echo "PQ diagnostics did NOT print!" >&2
    exit 1
fi
