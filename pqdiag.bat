<# :
@echo off
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
rem
rem Scripts for scheduling print quality diagnostics reports (PQ Diagnostics)
rem on HP printers, for Windows, MacOS and Linux.
rem
rem Exit codes: 0=OK, 1=Failed (retryable), 2=Invalid argument, 3=Sent, ACK timed out (do not auto-retry)

setlocal enableextensions enabledelayedexpansion
set /a MAX_TIME=10, CONNECT_TIMEOUT=5
set "SCHEMA_HOST=www.hp.com"
set "SCHEMA_PATH=/schemas/imaging/con/ledm/internalprintdyn/2008/03/21"
set "XML=<?xml version="1.0" encoding="UTF-8"?><ipdyn:InternalPrintDyn xmlns:ipdyn="http://!SCHEMA_HOST!!SCHEMA_PATH!"><ipdyn:JobType>pqDiagnosticsPage</ipdyn:JobType></ipdyn:InternalPrintDyn>"

rem --- Branch 1: USB target ("usb" or "usb:N") -> run embedded PowerShell USB handler below ---
set "ARG=%~1"
if /i "!ARG!"=="usb" set "USB_MODE=1" & set "USB_IDX=0"
if /i "!ARG:~0,4!"=="usb:" if not "!ARG:~4!"=="" set "USB_MODE=1" & set /a "USB_IDX=!ARG:~4!-1" 2>nul
if defined USB_MODE (
    if !USB_IDX! LSS 0 ( >&2 echo Invalid USB index "%~1". Use "usb" or "usb:1", "usb:2", ... & endlocal & exit /b 2 )
    set "BAT_PATH=%~f0"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([IO.File]::ReadAllText($env:BAT_PATH))"
    set "PS_EXIT=!errorlevel!"
    endlocal & exit /b !PS_EXIT!
)

rem --- Branch 2: Network target (IPv4 address or hostname) -> send LEDM XML via curl ---
call :validateTarget "%~1" ret
if !ret! EQU 0 (
    echo Sending print quality diagnostics job to HP_printer@%~1^^!
    curl -f --max-time !MAX_TIME! --connect-timeout !CONNECT_TIMEOUT! -H "User-Agent:" -H "Host: localhost" -H "Accept:" -H "X-HP-AR-INFO: chunk-correct" -H "Content-Type: text/xml" -H "Content-Length: 220" --data-binary "!XML:"=\"!" --http1.1 http://%~1:8080/DevMgmt/InternalPrintDyn.xml >nul 2>&1
    set "CURL_EXIT=!errorlevel!"
    if !CURL_EXIT! EQU 0 ( echo PQ diagnostics printed OK^^! & endlocal & exit /b 0 )
    if !CURL_EXIT! EQU 28 ( >&2 echo PQ diagnostics sent, but confirmation timed out (check printer^). & endlocal & exit /b 3 )
    >&2 echo PQ diagnostics did NOT print^^! & endlocal & exit /b 1
)

rem --- Branch 3: Invalid or missing argument ---
>&2 echo The argument "%~1" is not a valid IPv4 address, hostname, or "usb"...
>&2 echo Please try again like this: pqdiag.bat 192.0.0.10 (using your printer's IP, hostname, or "usb"^)
endlocal & exit /b 2

rem --- Helper: Validate IPv4 address or hostname ---
:validateTarget target [returnVariable]
    setlocal & set "_return=1"
    if "%~1"=="" goto :endValidateTarget
    echo %~1| findstr /b /e /r "\.\.\.*" >nul && goto :endValidateTarget
    echo %~1| findstr /e /r "\.\.*" >nul && goto :endValidateTarget
    echo %~1| findstr /b /r "\.\.*" >nul && goto :endValidateTarget
    echo %~1| findstr /b /e /r "[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*" >nul
    if not errorlevel 1 (
        for /f "tokens=1-4 delims=." %%a in ("%~1") do if %%a gtr -1 if %%a lss 255 if %%b leq 255 if %%c leq 255 if %%d gtr -1 if %%d leq 254 set "_return=0"
        goto :endValidateTarget
    )
    echo %~1| findstr /r "[^a-zA-Z0-9.-]" >nul && goto :endValidateTarget
    echo %~1| findstr /r "[a-zA-Z]" >nul && set "_return=0"
:endValidateTarget
    endlocal & ( if not "%~2"=="" set "%~2=%_return%" ) & exit /b %_return%
#>

# ==============================================================================
# Embedded PowerShell USB Handler (executed only for "usb" / "usb:N" targets)
# ==============================================================================

# Low-level WinUSB & USBPRINT bulk-pipe HTTP sender
Add-Type -TypeDefinition @"
using System; using System.IO; using System.Runtime.InteropServices; using System.Text; using System.Threading; using Microsoft.Win32.SafeHandles;
public class HpUsb {
    [StructLayout(LayoutKind.Sequential)] struct Pipe { public int T; public byte Id; public ushort M; public byte I; }
    [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern SafeFileHandle CreateFile(string n, uint a, uint s, IntPtr sec, uint d, uint f, IntPtr t);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_Initialize(SafeFileHandle h, out IntPtr u);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_Free(IntPtr u);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_QueryPipe(IntPtr u, byte a, byte i, out Pipe p);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_SetPipePolicy(IntPtr u, byte p, uint pol, uint l, ref uint v);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_WritePipe(IntPtr u, byte p, byte[] b, uint l, out uint s, IntPtr o);
    [DllImport("winusb.dll", SetLastError=true)] static extern bool WinUsb_ReadPipe(IntPtr u, byte p, byte[] b, uint l, out uint r, IntPtr o);
    public static bool Exists(string path) { using (var h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero)) return !h.IsInvalid; }
    public static string Send(string path, string req, int rMs, int wMs) {
        byte[] data = Encoding.ASCII.GetBytes(req), buf = (byte[])Array.CreateInstance(typeof(byte), 1024); IntPtr u;
        // 1. Try WinUSB (modern Win10/11 MS_COMP_WINUSB & IPP-over-USB interfaces)
        SafeFileHandle h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0x40000000, IntPtr.Zero);
        if (!h.IsInvalid && WinUsb_Initialize(h, out u)) {
            try {
                byte inP = 0, outP = 0; Pipe p;
                for (byte i = 0; i < 8 && WinUsb_QueryPipe(u, 0, i, out p); i++) { if (p.T == 2 && (p.Id & 0x80) != 0 && inP == 0) inP = p.Id; if (p.T == 2 && (p.Id & 0x80) == 0 && outP == 0) outP = p.Id; }
                uint r = (uint)rMs, w = (uint)wMs, s, g; WinUsb_SetPipePolicy(u, outP, 3, 4, ref w); WinUsb_SetPipePolicy(u, inP, 3, 4, ref r);
                if (!WinUsb_WritePipe(u, outP, data, (uint)data.Length, out s, IntPtr.Zero)) throw new IOException();
                // Read until full HTTP headers (\r\n\r\n) arrive, ignoring zero-length packets while printer wakes
                var sb = new StringBuilder(); int end = Environment.TickCount + rMs;
                while (Environment.TickCount < end && !sb.ToString().Contains("\r\n\r\n")) { if (!WinUsb_ReadPipe(u, inP, buf, (uint)buf.Length, out g, IntPtr.Zero)) throw (sb.Length == 0 && Marshal.GetLastWin32Error() == 121) ? (Exception)new TimeoutException() : new IOException(); if (g > 0) sb.Append(Encoding.ASCII.GetString(buf, 0, (int)g)); else Thread.Sleep(20); }
                return sb.ToString();
            } finally { WinUsb_Free(u); h.Dispose(); }
        }
        // 2. Fallback to synchronous FileStream (legacy usbprint.sys interfaces)
        if (!h.IsInvalid) h.Dispose(); h = CreateFile(path, 0xC0000000, 3, IntPtr.Zero, 3, 0, IntPtr.Zero);
        if (h.IsInvalid) throw new IOException();
        using (var fs = new FileStream(h, FileAccess.ReadWrite, 4096, false)) { fs.ReadTimeout = rMs; fs.WriteTimeout = wMs; fs.Write(data, 0, data.Length); fs.Flush(); return Encoding.ASCII.GetString(buf, 0, fs.Read(buf, 0, buf.Length)); }
    }
}
"@

# Discover connected HP (VID_03F0) LEDM/IPP USB interfaces (excluding raw Prot_02 print & USBSCAN)
$target = ("{dee824ef-729b-4a0e-9c14-b7117d33a817}", "{28d78fad-5a12-11d1-ae5b-0000f803a8c2}" | ForEach-Object { Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceClasses\$_" -EA SilentlyContinue } | ForEach-Object {
    $inst = (Get-ItemProperty $_.PSPath).DeviceInstance; $ids = (Get-PnpDeviceProperty -InstanceId $inst -KeyName "DEVPKEY_Device_CompatibleIds" -EA SilentlyContinue).Data
    if ($inst -match "VID_03F0" -and ($ids -contains "USB\Class_07&SubClass_01&Prot_04" -or $ids -contains "USB\Class_FF&SubClass_04&Prot_01") -and ($ids -notcontains "USB\MS_COMP_USBSCAN")) { $_.PSChildName -replace '^##\?#', '\\?\' }
} | Select-Object -Unique | Where-Object { [HpUsb]::Exists($_) } | Select-Object -Skip ([int]$env:USB_IDX) -First 1)

if (-not $target) { [Console]::Error.WriteLine("PQ diagnostics did NOT print! (No responsive HP LEDM USB printer found)"); exit 1 }

# Send POST trigger with shared LEDM XML payload and map HTTP response to exit codes
Write-Output "Sending print quality diagnostics job to HP_printer@USB!"
$post = "POST /DevMgmt/InternalPrintDyn.xml HTTP/1.1`r`nHost: localhost`r`nX-HP-AR-INFO: chunk-correct`r`nContent-Type: text/xml`r`nContent-Length: $($env:XML.Length)`r`nConnection: close`r`n`r`n$($env:XML)"
try {
    if ([HpUsb]::Send($target, $post, [int]$env:MAX_TIME * 1000, [int]$env:CONNECT_TIMEOUT * 1000) -match "^HTTP/\d\.\d 2\d\d") { Write-Output "PQ diagnostics printed OK!"; exit 0 }
    [Console]::Error.WriteLine("PQ diagnostics did NOT print!"); exit 1
} catch [TimeoutException] { [Console]::Error.WriteLine("PQ diagnostics sent, but confirmation timed out (check printer)."); exit 3 }
catch { [Console]::Error.WriteLine("PQ diagnostics did NOT print!"); exit 1 }
