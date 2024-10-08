@ECHO OFF
SET /A MAX_TIME=5
SET /A CONNECT_TIMEOUT=5

    setlocal enableextensions enabledelayedexpansion
    call :validateIP %1 ret
    if !ret! EQU 0 (
        echo Sending print quality diagnostics job to HP_printer@%1!
        curl --max-time !MAX_TIME! --connect-timeout !CONNECT_TIMEOUT! -H "User-Agent:" -H "Host: localhost" -H "Accept:" -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" --data-binary "<?xml version=\"1.0\" encoding=\"UTF-8\"?><ipdyn:InternalPrintDyn xmlns:ipdyn=\"http://www.hp.com/schemas/imaging/con/ledm/internalprintdyn/2008/03/21\"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>" --http1.1 http://%1%:8080/DevMgmt/InternalPrintDyn.xml >nul 2>&1
    if not errorlevel 1 (
        echo "PQ diagnostics printed OK!"
    ) else (
        echo "PQ diagnostics did NOT print!"
    )
	) else (
        echo "The argument \"%1\" is not a valid IPv4 address or missing..."
	    echo "Please try again like this: pqdiag.bat 192.0.0.10"
	    echo "(Using your HP printer's IP address)"
    )
    exit /b 

rem :validateIP below was inspired by MC ND's answer here: https://stackoverflow.com/a/20301111/12802435
:validateIP ipAddress [returnVariable]
    rem prepare environment
    setlocal 

    rem asume failure in tests : 0=pass 1=fail : same for errorlevel
    set "_return=1"
    
    echo %~1| findstr /b /e /r "\.\.\.*" >nul
    if not errorlevel 1 (goto :endValidateIP)
    echo %~1| findstr /e /r "\.\.*" >nul
    if not errorlevel 1 (goto :endValidateIP)
    echo %~1| findstr /b /r "\.\.*" >nul
    if not errorlevel 1 (goto :endValidateIP)


    rem test if address conforms to ip address structure
    echo %~1| findstr /b /e /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
 
    rem if it conforms to structure, test each octet for range values
    if not errorlevel 1 for /f "tokens=1-4 delims=." %%a in ("%~1") do (
        if %%a gtr -1 if %%a lss 255 if %%b leq 255 if %%c leq 255 if %%d gtr -1 if %%d leq 254 set "_return=0"
    )

:endValidateIP
    rem clean and return data/errorlevel to caller
    endlocal & ( if not "%~2"=="" set "%~2=%_return%" ) & exit /b %_return%