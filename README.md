# pqdiag
Scripts for running and scheduling print quality diagnostics reports (PQ Diagnostics) on HP printers, for Windows, MacOS and Linux.

(At least these scripts work on my HP OfficeJet Pro 8710 / 8715 series printer from Windows, MacOS and Linux devices. Appreciate feedbacks in the [issues](https://github.com/Vegz78/pqdiag/issues) section on whether the scripts work or not for other HP printers!)

![pqdiagnostics](https://github.com/user-attachments/assets/6a3ebff2-4577-4307-806d-72edec964e55)

## Table of Contents:
[Intro](https://github.com/Vegz78/pqdiag#intro)<BR>
[Prerequisites](https://github.com/Vegz78/pqdiag#prerequisites)<BR>
[Installation](https://github.com/Vegz78/pqdiag#installation)<BR>
[Usage](https://github.com/Vegz78/pqdiag#usage)<BR>
[Scheduling](https://github.com/Vegz78/pqdiag#scheduling)<BR>
[Support (or lack thereof)](https://github.com/Vegz78/pqdiag#support-or-lack-thereof)

## Intro
Having grown tired of dried and clogged up printhead nozzles on my HP OfficeJet Pro 8715 printer, and unsatisfied with the tremendous waste of ink from periodically running the printhead cleaning program or scheduling weekly power cycles in the printer's EWS (embedded web server), I set out on a small journey to see if there was some way to schedule the printer's ink-efficient internal print quality diagnostic report to run often enough from my always-on SBC (Rasperry Pi) or NAS servers to prevent clogging through prolonged periods of little printing.

The journey initially led me to _luksfuks'_ [Epson nozzle-check script](https://www.reddit.com/r/Epson/comments/160yq1g/comment/jxr6572/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button) on Reddit, which convinced me to use the printer's own embedded print quality report, since it activates every nozzle while still using a fairly miniscule amount of ink, with no need to install drivers or anything in addition to tools already provided by most vanilla OS installations.

Then, I stumbled across Jonathan Yang's [article on Medium about doing just this from an ESP32-DevKit](https://medium.com/@ttrolololll/printer-pulse-check-to-prevent-dry-ink-with-esp32-devkit-338874d21445), which revealed to me the magic XML that needed to be sent to an HP printer to achieve this, which also probably was possible to replicate in an http POST command with ```curl```, that comes preinstalled on most Windows (starting with W10), MacOS and Linux installations.

Lastly, capturing the https package in question from the HP Utility using Wireshark, comparing the captured package to Yang's above mentioned article and similar XML code in the ```hp-pqdiag``` tool in the Fossies opensource [HPLIP (HP Linux Imaging and Printing) repository](https://fossies.org/linux/hplip/base/maint.py), studying a bit ```curl``` and ```cron```, relearning somewhat bat and bash scripting and regex, and playing a little around, it finally resulted in this repo, which I hope will keep my printer operating smoothly going forward by running the scripts biweekly or weekly, and that I also hope others might benefit from...

Additional thanks to:
- _MC ND_ on Stack Overflow for showing the way [how to check an argument containing an IP address using regex with ```findstr``` in at bat script](https://stackoverflow.com/a/20301111/12802435)!
- _Danail Gabensky_ for the superb answer on Stack Overflow on [how to most efficiently check an argument containing an IP address using regex in a bash script](https://stackoverflow.com/a/36760050/12802435)!
- _pilcrow_ for a solution on Stack Overflow for [how to make biweekly cron jobs](https://stackoverflow.com/a/19278657/12802435)!
- [grontab.guru](https://crontab.guru) for a handy online tool for experimenting with crontab schedules!
- [regex101.com](https://regex101.com) for a handy online tool for experimenting with regex patterns!

## Prerequisites
- A device running Windows, MacOS or Linux, preferably always on or able to wake up periodically to run the script
- _curl_ (comes preinstalled on the above OSes, also on W10 and above)
- A scheduling service, like _Windows Task Scheduler_ or _cron_ on MacOS and Linux (the scripts can of course also be executed manually on demand)

## Installation
1. Clone or download this repo from a release, or just the raw [script file](https://github.com/Vegz78/pqdiag/blob/main/pqdiag.sh) that you need
2. Take note of the scripts' download location/path or copy it to somewhere accessible in your _PATH_ system environment variables
3. On MacOS and Linux, make the bash script executable, e.g.: ```sudo chmod 755 ./pqdiag.sh```

## Usage
### MacOS and Linux
From inside the folder where _pqdiag.sh_ is located, run the script like this:<BR>
```./pqdiag.sh 192.168.0.10```<BR>, where _192.168.0.10 must be substituted with the actual IP address of your HP printer.
### Windows
From inside the folder where _pqdiag.bat_ is located, run the script like this:<BR>
```pqdiag.bat 192.168.0.10```<BR>, where _192.168.0.10 must be substituted with the actual IP address of your HP printer.

## Scheduling
### MacOS and Linux
Using _cron_:
1. ```sudo crontab -e```
2. Add whichever of these cron entries suits you the best to the and of the file and substitue _/path/to/pqdiag.sh_ with the actual folder location and _192.168.0.10_ with the HP printer's actual IP address:<BR>
   (or exeriment with your own here: https://crontab.guru)
    1. Wednesdays at 07:00 biweekly (odd week numbers as shown in Norwegian calendars):<BR>
       ```0 7 * * Wed expr \( `date +\%s` + 302400 \) / 604800 \% 2 >/dev/null || /path/to/pqdiag.sh 192.168.0.10```
    2. Wednesdays at 07:00 biweekly (even week numbers as shown in Norwegian calendars):<BR>
       ```0 7 * * Wed expr `date +\%s` / 604800 \% 2 >/dev/null || /path/to/pqdiag.sh 192.168.0.10```
    3. Wdnesdays at 07:00 weekly:<BR>
       ```0 7 * * Wed /path/to/pqdiag.sh 192.168.0.10```    
4. Save and close the _crontab_ file

### Windows
https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page

## Support (or lack thereof)
Since everything works as planned already for me and I have spent some time writing this [_README.md_](https://github.com/Vegz78/pqdiag/edit/main/README.md) with everything there is to know, this repository will not regularly be visited and updated, and it will NOT be user supported.

However, I have some interest in making this a general and available tool for HP printer users with similar needs, so I will visit now and then and maybe fix some errors or help make it work for other printers than the HP OfficeJet Pro 8710 / 8715.

Please post such feedbacks in the [issues section](https://learn.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page) and/or contribute with concrete pull requests.
