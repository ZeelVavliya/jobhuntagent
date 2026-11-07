# Registers the three job-hunt runs as Windows Scheduled Tasks that call Claude Code (CLI), no desktop app, no Docker.
# Run once:  powershell -ExecutionPolicy Bypass -File windows\register-tasks.ps1
# Remove:    powershell -ExecutionPolicy Bypass -File windows\register-tasks.ps1 -Remove
param([switch]$Remove)
$Root = Split-Path -Parent $PSScriptRoot
$jobs = @(
  @{ Name = 'JobHunt-Digest | 07:20';  Cmd = '/digest';          Times = '07:20' },
  @{ Name = 'JobHunt-Cycle';           Cmd = '/hunt-cycle';      Times = '07:40','12:40','17:40' },
  @{ Name = 'JobHunt-Submit';          Cmd = '/submit-approved'; Times = '08:10','13:10','18:10' }
)
foreach ($j in $jobs) {
  $name = $j.Name -replace ' \|.*', ''
  if ($Remove) { Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue; continue }
  # --chrome = Claude in Chrome for LinkedIn/portals; settings.json allowlist means no permission prompts
  $run = "Set-Location '$Root'; claude --chrome -p '$($j.Cmd)' --permission-mode acceptEdits *>> 'logs\task.log'"
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -WindowStyle Hidden -Command `"$run`"" -WorkingDirectory $Root
  $triggers = $j.Times | ForEach-Object { New-ScheduledTaskTrigger -Daily -At $_ }
  # Interactive logon only (Chrome needs your desktop session); catch up if the PC was asleep
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew
  Register-ScheduledTask -TaskName $name -Action $action -Trigger $triggers -Settings $settings -Force | Out-Null
  Write-Host "Registered $name ($($j.Times -join ', '))"
}
