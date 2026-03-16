# scripts-duty

This folder contains quick triage and event log scripts.

## Contents
- `SystemTriageSnapshot.sh`: Linux triage. Checks compatibility, shows CPU/memory/disk/network snapshot, critical journal entries, recent and pending updates, reboot requirement, boot history, and recent logins.
- `Get-SystemTriageSnapshot.ps1`: Windows triage. Checks compatibility, OS/uptime/disk/process/network info, critical/system/app events, pending updates, reboot requirement, boot history, installed updates, and successful/failed logons.
- `Get-EventLogReport.ps1`: Windows event log fetcher with level filtering, CSV export, and fallback to Get-EventLog if needed.

## Quick start
- Linux: `bash SystemTriageSnapshot.sh`
- Windows (PowerShell): `./Get-SystemTriageSnapshot.ps1`
- Windows event log report (e.g., Application, newest 50, CSV): `./Get-EventLogReport.ps1 -LogName Application -Newest 50 -OutFile ./out/app.csv`

**Note**: Run with elevated privileges if required (sudo/PowerShell admin) and prefer testing in non-production first.

## Help
- PowerShell: `Get-Help ./Get-SystemTriageSnapshot.ps1 -Detailed` and `Get-Help ./Get-EventLogReport.ps1 -Examples` for parameters and samples.
- Bash script is flagless; open the file or run with `bash SystemTriageSnapshot.sh` to see section outputs.
