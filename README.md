# pqdiag
Scripts for scheduling print quality diagnostics reports (PQ Diagnostics) on HP printers, for Windows, MacOS and Linux.<BR>
(At least these scripts work on my HP OfficeJet Pro 8710 / 8715 series printer from Windows, MacOS and Linux devices. Appreciate feedbacks in the [issues](https://github.com/Vegz78/pqdiag/issues) section on whether the scripts work or not for other HP printers!)

## Table of Contents:
Intro<BR>
Prerequisites<BR>
Installation<BR>
Usage<BR>
Scheduling<BR>
Support

## Intro
Having grown tired of dried and clogged up printhead nozzles on my HP OfficeJet Pro 8715 printer, and unsatisfied with the tremendous waste of ink from periodically running the printhead cleaning program or scheduling weekly power cycles in the printer's EWS (embedded web server), I set out on a small journey to see if there was some way to schedule the printer's ink-efficient internal print quality diagnostic report to run often enough from my always-on SBC (Rasperry Pi) or NAS servers to prevent clogging through prolonged periods of little printing.

The journey initially led me to _luksfuks'_ [Epson nozzle-check script](https://www.reddit.com/r/Epson/comments/160yq1g/comment/jxr6572/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button) on Reddit, which convinced me to use the printer's own embedded, since it activates every nozzle while still using a fairly miniscule amount of ink, with no need to install drivers or anything in addition to tools already provided by most vanilla OS installations.

Then, I stumbled across Jonathan Yang's [article on Medium about doing just this from an ESP32-DevKit](https://medium.com/@ttrolololll/printer-pulse-check-to-prevent-dry-ink-with-esp32-devkit-338874d21445), which revealed to me the magic XML that needed to be sent to an HP printer to achieve this, and also which probably was possible to replicate in an http POST command with ```curl```, which comes preinstalled on most Windows (starting with W10), MacOS and Linux installations.

Lastly, capturing the https package in question from the HP Utility using Wireshark, comparing the captured package to Yang's above mentioned article and similar XML code in the ```hp-pqdiag``` tool in the Fossies opensource [HPLIP (HP Linux Imaging and Printing) repository](https://fossies.org/linux/hplip/base/maint.py), studying a bit ```curl``` and ```cron```, relearning somewhat bat and bash scripting and regex, and playing a little around, it finally resulted in this repo, which I hope will keep my printer operating smoothly going forward by running the scripts biweekly or weekly, and that I also hope others might benefit from...

## Prerequisites
- A device running Windows, MacOS or Linux, preferably always on or able to wake up periodically to run the script
- _curl_ (comes preinstalled on the above OSes, also on W10 and above)
- A scheduling service, like _Windows Task Scheduler_ or _cron_ on MacOS and Linux (the scripts can of course also be executed manually on demand)

## Installation
1. Clone or download this repo from a release, or just the raw [script file]()https://github.com/Vegz78/pqdiag/blob/main/pqdiag.sh that you need
2. Take note of the scripts' download location/path or copy it to somewhere accessible in your _PATH_ system environment variables
3. On MacOS and Linux, make the bash script executable, e.g.: ```sudo chmod 755 ./pqdiag.sh```

## Usage
### MacOS and Linux
From inside the folder where _pqdiag.sh_ is located, run the script like this:<BR>
```./pqdiag.sh 192.168.0.10```<BR>, where _192.168.0.1 must be substituted with the actual IP address of your HP printer.
### Windows
From inside the folder where _pqdiag.bat_ is located, run the script like this:<BR>
```./pqdiag.bat 192.168.0.10```<BR>, where _192.168.0.1 must be substituted with the actual IP address of your HP printer.

## Scheduling
