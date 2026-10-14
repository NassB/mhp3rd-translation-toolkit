# Crée apps/mh_studio (Flutter desktop) avec FVM et l'intègre au pub workspace.
# Usage (depuis la racine du dépôt) : pwsh scripts/setup_studio.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Get-Command fvm -ErrorAction SilentlyContinue)) { throw 'fvm introuvable dans le PATH' }

# 1. Fixe la version de Flutter du projet (.fvmrc, à commiter ; .fvm/ est ignoré)
if (-not (Test-Path '.fvmrc')) { fvm use stable --force }
fvm flutter --version

# 2. Crée l'application
if (-not (Test-Path 'apps/mh_studio/pubspec.yaml')) {
  fvm flutter create --org dev.mh3rd --project-name mh_studio --platforms=windows,linux,macos apps/mh_studio
}

# 3. Intègre au workspace (idempotent)
$p = 'apps/mh_studio/pubspec.yaml'
$t = Get-Content $p -Raw
if ($t -notmatch '(?m)^resolution: workspace') {
  $t = $t -replace "(?m)^(publish_to:.*)$", "`$1`nresolution: workspace"
  Set-Content $p $t -NoNewline -Encoding utf8
}
$r = Get-Content 'pubspec.yaml' -Raw
if ($r -notmatch 'apps/mh_studio') {
  $r = $r -replace '(?m)^(\s*- apps/mh_cli)\s*$', "`$1`n  - apps/mh_studio"
  Set-Content 'pubspec.yaml' $r -NoNewline -Encoding utf8
}
Set-Content 'apps/mh_studio/analysis_options.yaml' "include: ../../analysis_options.yaml`n" -Encoding utf8

# 4. Résolution, format, tests
fvm flutter pub get
fvm dart format apps/mh_studio
Push-Location apps/mh_studio
fvm flutter test
Pop-Location
Write-Host "`nOK : apps/mh_studio créé. Lance ensuite : fvm dart format --output=none --set-exit-if-changed . ; fvm dart analyze --fatal-infos"
