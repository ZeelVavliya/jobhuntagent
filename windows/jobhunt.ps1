<#
.SYNOPSIS
  Windows version of the job-hunt loop: runs the same Docker container as the Raspberry Pi,
  through Docker Desktop. Use from the job-hunt folder:  .\jobhunt <command>

.EXAMPLE
  .\jobhunt setup            # first time: checks Docker, writes .env, builds and starts
  .\jobhunt login-claude     # one-time Claude login (type /login, then /exit)
  .\jobhunt login-sites      # sign in to LinkedIn / Seek in the loop's browser
  .\jobhunt vercel-init      # create the tracker website
  .\jobhunt selftest -Full   # test run
#>
param(
  [Parameter(Position = 0)][string]$Command = 'help',
  [Parameter(Position = 1)][string]$Job = '',
  [switch]$Full,
  [string[]]$Url = @()
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Compose = Join-Path $Root 'docker-compose.windows.yml'
$EnvFile = Join-Path $Root '.env'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

$script:LastCode = 0
# Non-interactive compose call: output to the console, exit code in $script:LastCode.
function Dc {
  $ErrorActionPreference = 'Continue'
  & docker compose -f $Compose --project-directory $Root @args | Out-Host
  $script:LastCode = $LASTEXITCODE
}
# Interactive / streaming compose call (keeps the terminal attached: login, selftest, logs).
function DcTty {
  $ErrorActionPreference = 'Continue'
  & docker compose -f $Compose --project-directory $Root @args
  $script:LastCode = $LASTEXITCODE
}
function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Read-Secret([string]$prompt) {
  $s = Read-Host $prompt -AsSecureString
  $b = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($s)
  try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($b) }
  finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($b) }
}
function Read-Required([string]$prompt) {
  do { $v = Read-Secret $prompt; if (-not $v) { Say 'This one is required.' Yellow } } while (-not $v)
  return $v
}
function New-Token {
  $bytes = New-Object byte[] 24
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
function Get-EnvValue([string]$key) {
  if (-not (Test-Path $EnvFile)) { return '' }
  foreach ($line in [IO.File]::ReadAllLines($EnvFile)) {
    if ($line -match "^\s*$key=(.*)$") {
      $v = $Matches[1].Trim()
      if ($v -match "^'(.*)'$") { return $Matches[1] }
      return ($v -replace '\s+#.*$', '').Trim()
    }
  }
  return ''
}
function Set-EnvValue([string]$key, [string]$value) {
  # Single quotes keep Docker Compose from reading $, # or spaces in a value
  if ($value -notmatch '^[A-Za-z0-9._~:/@%+=-]*$') {
    if ($value.Contains("'")) { Say "The value for $key cannot contain a single quote ('). Try again." Red; exit 1 }
    $value = "'" + $value + "'"
  }
  $lines = @()
  if (Test-Path $EnvFile) { $lines = @([IO.File]::ReadAllLines($EnvFile)) }
  $found = $false
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match "^\s*$key=") { $lines[$i] = "$key=$value"; $found = $true }
  }
  if (-not $found) { $lines += "$key=$value" }
  # LF line endings and no BOM: the file is read inside the Linux container
  [IO.File]::WriteAllText($EnvFile, (($lines -join "`n") + "`n"), $Utf8NoBom)
}

function Test-Docker {
  $ErrorActionPreference = 'Continue'  # docker writes to stderr when the engine is down
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Say 'Docker Desktop is not installed.' Yellow
    Say '  Install it:  winget install -e --id Docker.DockerDesktop   (then restart Windows and open Docker Desktop once)'
    exit 1
  }
  & docker info *> $null
  if ($LASTEXITCODE -ne 0) {
    Say 'Docker Desktop is not running. Start it from the Start menu, wait for "Engine running", then try again.' Yellow
    exit 1
  }
}

function Invoke-Setup {
  Test-Docker
  foreach ($d in 'career-ops', 'ai-job-search') {
    if (-not (Test-Path (Join-Path $Root $d))) { Say "Missing $d\ in $Root. Run the original setup.ps1 first." Red; exit 1 }
  }
  if (-not (Test-Path $EnvFile)) {
    Copy-Item (Join-Path $Root '.env.example') $EnvFile
    $text = [IO.File]::ReadAllText($EnvFile) -replace "`r`n", "`n"
    [IO.File]::WriteAllText($EnvFile, $text, $Utf8NoBom)
    Say 'Created .env' Green
  }
  if (-not (Get-EnvValue 'VNC_PASSWORD')) { Set-EnvValue 'VNC_PASSWORD' (Read-Required 'Choose a password for the sign-in screen (noVNC)') }
  if (-not (Get-EnvValue 'TRACKER_PASSWORD')) { Set-EnvValue 'TRACKER_PASSWORD' (Read-Required 'Choose a password for your tracker website') }
  if (-not (Get-EnvValue 'PI_SYNC_TOKEN')) { Set-EnvValue 'PI_SYNC_TOKEN' (New-Token); Say 'Generated PI_SYNC_TOKEN' Green }
  if (-not (Get-EnvValue 'VERCEL_TOKEN')) {
    Say 'Vercel token: vercel.com -> Account Settings -> Tokens -> Create (leave empty to add later).'
    $t = Read-Secret 'VERCEL_TOKEN'
    if ($t) { Set-EnvValue 'VERCEL_TOKEN' $t }
  }
  Say 'Building the container (first time about 5-10 minutes)...' Cyan
  Dc up -d --build
  if ($script:LastCode -ne 0) { Say 'Build failed. See the messages above.' Red; exit 1 }
  Say ''
  Say 'Running. Next steps:' Green
  Say '  1. .\jobhunt login-claude    (type /login, follow the link, then /exit)'
  Say '  2. .\jobhunt login-sites     (sign in to LinkedIn and Seek, close the browser window)'
  Say '  3. .\jobhunt vercel-init     (creates the tracker website)'
  Say '  4. .\jobhunt selftest        (then: .\jobhunt selftest -Full)'
  Say '  5. .\jobhunt keep-awake      (stop the PC sleeping while plugged in)'
}

function Invoke-VercelInit {
  Test-Docker
  if (-not (Get-EnvValue 'VERCEL_TOKEN')) { Set-EnvValue 'VERCEL_TOKEN' (Read-Secret 'VERCEL_TOKEN'); Dc up -d }
  DcTty exec hunt bash bin/vercel-init.sh
  if ($script:LastCode -ne 0) { Say 'vercel-init failed; see above.' Red; exit 1 }
  $u = Read-Host 'Paste the tracker production URL (e.g. https://zeel-jobhunt-tracker.vercel.app), or Enter to skip'
  if ($u) {
    Set-EnvValue 'TRACKER_URL' $u.TrimEnd('/')
    Dc up -d
    Say 'Saved TRACKER_URL and restarted.' Green
  }
}

switch ($Command.ToLower()) {
  'setup'        { Invoke-Setup }
  'start'        { Test-Docker; Dc up -d; Say 'Started.' Green }
  'stop'         { Test-Docker; Dc down; Say 'Stopped. Scheduled runs are paused until .\jobhunt start.' Yellow }
  'rebuild'      { Test-Docker; Dc build --pull --no-cache; Dc up -d; Say 'Rebuilt and restarted.' Green }
  'login-claude' { Test-Docker; Say 'Type /login, open the link, paste the code back, then /exit.' Cyan; DcTty run --rm hunt claude }
  'login-sites'  {
    Test-Docker
    Say 'Opening the sign-in screen in your browser (password = VNC_PASSWORD). Sign in, then close the browser window inside it.' Cyan
    Start-Process 'http://localhost:6080/vnc.html?autoconnect=1&resize=scale'
    DcTty exec hunt bash bin/login-browser.sh @Url
  }
  'vercel-init'  { Invoke-VercelInit }
  'selftest'     {
    Test-Docker
    $a = @('exec', 'hunt', 'bash', 'bin/selftest.sh'); if ($Full) { $a += '--full' }
    DcTty @a
  }
  'run'          {
    Test-Docker
    $map = @{ 'cycle' = 'run-cycle.sh'; 'submit' = 'run-submit.sh'; 'digest' = 'run-digest.sh' }
    if (-not $map.ContainsKey($Job)) { Say 'Usage: .\jobhunt run cycle|submit|digest' Yellow; exit 1 }
    DcTty exec hunt bash ('bin/' + $map[$Job])
  }
  'status'       {
    Test-Docker
    Dc ps
    $log = Join-Path $Root 'logs\runs.log'
    if (Test-Path $log) { Say "`nLast runs:" Cyan; Get-Content $log -Tail 10 -Encoding UTF8 }
  }
  'logs'         { Test-Docker; DcTty logs -f --tail 100 }
  'tracker'      {
    $u = Get-EnvValue 'TRACKER_URL'
    if ($u) { Start-Process $u } else { Say 'TRACKER_URL is not set yet: run .\jobhunt vercel-init' Yellow }
  }
  'keep-awake'   {
    $ErrorActionPreference = 'Continue'
    & powercfg /change standby-timeout-ac 0
    Say 'Sleep on mains power is now off. Also: Docker Desktop -> Settings -> General -> "Start Docker Desktop when you sign in".' Green
  }
  default {
    Say 'Job-hunt loop for Windows (Docker Desktop). Commands:' Cyan
    Say '  setup          first time: check Docker, write .env, build and start'
    Say '  login-claude   one-time Claude login (brings your claude.ai Gmail connector)'
    Say '  login-sites    sign in to LinkedIn/Seek (add -Url <login page> for employer portals)'
    Say '  vercel-init    create the password-protected tracker website'
    Say '  selftest       check everything; -Full also runs one real cycle'
    Say '  run cycle|submit|digest   run a job now'
    Say '  status | logs | tracker | start | stop | rebuild | keep-awake'
    Say ''
    Say 'Schedule (Perth): digest 07:20, hunt 07:40/12:40/17:40, submit 08:10/13:10/18:10. The PC must be on and Docker Desktop running.'
  }
}
