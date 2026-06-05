# Jury installer for Windows (PowerShell). Downloads the prebuilt jury.exe from
# GitHub Releases — no Rust toolchain required.
#
#   irm https://raw.githubusercontent.com/<owner>/<repo>/main/install.ps1 | iex
#
# Override repo/dir if needed:
#   $env:JURY_REPO="owner/repo"; $env:JURY_BIN_DIR="$HOME\bin"; irm ... | iex
$ErrorActionPreference = "Stop"

$repo   = if ($env:JURY_REPO)    { $env:JURY_REPO }    else { "morfestboy/Jury" }
$binDir = if ($env:JURY_BIN_DIR) { $env:JURY_BIN_DIR } else { "$env:LOCALAPPDATA\Jury\bin" }

$arch = (Get-CimInstance Win32_Processor).Architecture
$archPart = if ($arch -eq 12) { "aarch64" } else { "x86_64" }  # 12 = ARM64
$target = "$archPart-pc-windows-msvc"
$asset  = "jury-$target.zip"
$url    = "https://github.com/$repo/releases/latest/download/$asset"

Write-Host "Installing jury ($target) from $repo…"

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("jury-" + [guid]::NewGuid()))
try {
  $zip = Join-Path $tmp $asset
  Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

  # Optional checksum verification.
  try {
    $shaFile = "$zip.sha256"
    Invoke-WebRequest -Uri "$url.sha256" -OutFile $shaFile -UseBasicParsing
    $expected = (Get-Content $shaFile | Select-Object -First 1).Trim().Split()[0]
    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash
    if ($expected -and ($expected -ne $actual)) { throw "checksum mismatch — refusing to install." }
    Write-Host "Checksum verified."
  } catch { }

  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  New-Item -ItemType Directory -Force -Path $binDir | Out-Null
  Copy-Item -Path (Join-Path $tmp "jury.exe") -Destination (Join-Path $binDir "jury.exe") -Force

  Write-Host ""
  Write-Host "Installed jury.exe to $binDir"
  & (Join-Path $binDir "jury.exe") --version

  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -notlike "*$binDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$binDir", "User")
    Write-Host ""
    Write-Host "Added $binDir to your user PATH. Open a new terminal to use 'jury'."
  }
} finally {
  Remove-Item -Recurse -Force $tmp
}
