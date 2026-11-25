@ECHO OFF
rem Scripts for scheduling print quality diagnostics reports (PQ Diagnostics) 
rem on HP printers, for Windows, MacOS and Linux.
rem 
rem This file is a part of the https://github.com/vegz78/pqdiag repository.
rem
rem Feel free to use and develop, but don't forget to inlcude proper attribution
rem to the developer.
rem
rem MIT License * * Copyright (c) 2024 Vegz78
rem
rem Permission is hereby granted, free of charge, to any person obtaining a copy
rem of this software and associated documentation files (the "Software"), to deal
rem in the Software without restriction, including without limitation the rights
rem to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
rem copies of the Software, and to permit persons to whom the Software is
rem furnished to do so, subject to the following conditions:
rem
rem The above copyright notice and this permission notice shall be included in all
rem copies or substantial portions of the Software.
rem
rem THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
rem IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
rem FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
rem AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
rem LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
rem OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
rem SOFTWARE.

rem Exit codes: 0=OK, 1=Failed (retryable), 2=Invalid argument, 3=Sent, ACK timed out (do not auto-retry)

setlocal enableextensions enabledelayedexpansion
SET /A MAX_TIME=10
SET /A CONNECT_TIMEOUT=5

call :validateTarget "%~1" ret
if !ret! EQU 0 (
    echo Sending print quality diagnostics job to HP_printer@%~1^^!
    curl -f --max-time !MAX_TIME! --connect-timeout !CONNECT_TIMEOUT! -H "User-Agent:" -H "Host: localhost" -H "Accept:" -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" --data-binary "<?xml version=\"1.0\" encoding=\"UTF-8\"?><ipdyn:InternalPrintDyn xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>" --http1.1 http://%~1:8080/DevMgmt/InternalPrintDyn.xml >nul 2>&1
    set "CURL_EXIT=!errorlevel!"
    if !CURL_EXIT! EQU 0 (
        echo PQ diagnostics printed OK^^!
        endlocal & exit /b 0
    ) else if !CURL_EXIT! EQU 28 (
        >&2 echo PQ diagnostics sent, but confirmation timed out (check printer^).
        endlocal & exit /b 3
    ) else (
        >&2 echo PQ diagnostics did NOT print^^!
        endlocal & exit /b 1
    )
) else (
    >&2 echo The argument "%~1" is not a valid IPv4 address/hostname or is missing...
    >&2 echo Please try again like this: pqdiag.bat 192.0.0.10 (or printer-hostname.local^)
    >&2 echo (Using your HP printer's IP address or hostname^)
    endlocal & exit /b 2
)

rem :validateIP below was inspired by MC ND's answer here: https://stackoverflow.com/a/20301111/12802435
:validateTarget target [returnVariable]
    setlocal
    set "_return=1"

    if "%~1"=="" goto :endValidateTarget

    echo %~1| findstr /b /e /r "\.\.\.*" >nul
    if not errorlevel 1 (goto :endValidateTarget)
    echo %~1| findstr /e /r "\.\.*" >nul
    if not errorlevel 1 (goto :endValidateTarget)
    echo %~1| findstr /b /r "\.\.*" >nul
    if not errorlevel 1 (goto :endValidateTarget)

    rem test if address conforms to IPv4 structure and octet ranges
    echo %~1| findstr /b /e /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
    if not errorlevel 1 (
        for /f "tokens=1-4 delims=." %%a in ("%~1") do (
            if %%a gtr -1 if %%a lss 255 if %%b leq 255 if %%c leq 255 if %%d gtr -1 if %%d leq 254 set "_return=0"
        )
        goto :endValidateTarget
    )

    rem otherwise test if target conforms to a valid hostname (rejects invalid characters, leading/trailing dots/hyphens, and all-numeric TLDs)
    echo %~1| findstr /r "[^a-zA-Z0-9.-]" >nul
    if not errorlevel 1 (goto :endValidateTarget)
    echo %~1| findstr "\.\." >nul
    if not errorlevel 1 (goto :endValidateTarget)
    echo %~1| findstr /b /r "[\.-]" >nul
    if not errorlevel 1 (goto :endValidateTarget)
    echo %~1| findstr /e /r "[\.-]" >nul
    if not errorlevel 1 (goto :endValidateTarget)

    echo %~1| findstr /b /e /r "[a-zA-Z][a-zA-Z0-9-]*" >nul
    if not errorlevel 1 set "_return=0"
    echo %~1| findstr /b /e /r "[a-zA-Z0-9.-]*\.[a-zA-Z][a-zA-Z0-9-]*" >nul
    if not errorlevel 1 set "_return=0"

:endValidateTarget
    endlocal & ( if not "%~2"=="" set "%~2=%_return%" ) & exit /b %_return%
