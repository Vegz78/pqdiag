# pqdiag
Scripts for scheduling print quality diagnostics reports (PQ Diagnostics) on HP printers, for Windows, MacOS and Linux.<BR>
(At least these scripts work on my HP OfficeJet Pro 8710 / 8715 series printer from Windows, MacOS and Linux devices. Appreciate feedbacks in the [issues](https://github.com/Vegz78/pqdiag/issues) section on whether the scripts work or not for other HP printers!)

## Table of Contents:
Intro<BR>
Installation<BR>
Usage<BR>
Scheduling<BR>

## Intro
Having grown tired of dried and clogged up printhead nozzles on my HP OfficeJet Pro 8715 printer, and unsatisfied with the tremendous waste of ink from periodically running the printhead cleaning program or scheduling weekly power cycles in the printer's EWS (embedded web server), I set out on a small journey to see if there was some way to schedule the printer's ink-efficient internal print quality diagnostic report to run often enough from my always-on SBC (Rasperry Pi) or NAS servers to prevent clogging through prolonged periods of little printing.

The journey led me first to 
