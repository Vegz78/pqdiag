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


# Exit codes: 0=OK, 1=Failed (retryable), 2=Invalid argument, 3=Sent, ACK timed out (do not auto-retry)

MAX_TIME=10
CONNECT_TIMEOUT=5

IP_REGEX='^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'
HOST_REGEX='^([a-zA-Z0-9-]+\.)*[a-zA-Z][a-zA-Z0-9-]*$'

if [[ "$1" =~ $IP_REGEX || "$1" =~ $HOST_REGEX ]]; then
        echo "Sending print quality diagnostics job to HP_printer@$1!"
        curl -f --max-time $MAX_TIME --connect-timeout $CONNECT_TIMEOUT -H "User-Agent:" -H "Host: localhost" -H "Accept:" -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" --data-binary "<?xml version=\"1.0\" encoding=\"UTF-8\"?><ipdyn:InternalPrintDyn xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>" --http1.1 http://$1:8080/DevMgmt/InternalPrintDyn.xml 2> /dev/null
        CURL_EXIT=$?
        if [[ $CURL_EXIT == 0 ]]; then
                echo "PQ diagnostics printed OK!"
                exit 0
        elif [[ $CURL_EXIT == 28 ]]; then
                echo "PQ diagnostics sent, but confirmation timed out (check printer)." >&2
                exit 3
        else
                echo "PQ diagnostics did NOT print!" >&2
                exit 1
        fi
else
        {
                echo "The argument \"$1\" is not a valid IPv4 address/hostname or is missing..."
                echo "Please try again like this: ./pqdiag.sh 192.0.0.10 (or printer-hostname.local)"
                echo "(Using your HP printer's IP address or hostname)"
        } >&2
        exit 2
fi
