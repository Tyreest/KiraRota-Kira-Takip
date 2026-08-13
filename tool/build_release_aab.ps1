# Builds a signed release AAB with production AdMob + optional review-access dart-defines.
# Usage: powershell -File tool/build_release_aab.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

function Read-Props([string]$path) {
    $map = @{}
    if (-not (Test-Path $path)) { return $map }
    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $i = $line.IndexOf('=')
        if ($i -lt 1) { return }
        $map[$line.Substring(0, $i).Trim()] = $line.Substring($i + 1).Trim()
    }
    return $map
}

$propsPath = Join-Path $root 'android\admob.properties'
if (-not (Test-Path $propsPath)) {
    throw "Missing android/admob.properties - copy from admob.properties.example and fill production IDs."
}

$map = Read-Props $propsPath

function Require([hashtable]$m, [string]$key) {
    if (-not $m.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($m[$key])) {
        throw "android/admob.properties missing value for $key"
    }
    return $m[$key]
}

$appId = Require $map 'admobAppId'
$bannerId = Require $map 'admobBannerUnitId'
$interstitialId = Require $map 'admobInterstitialUnitId'

$testPrefix = '3940256099942544'
foreach ($id in @($appId, $bannerId, $interstitialId)) {
    if ($id -like "*$testPrefix*") {
        throw "Refusing release build: AdMob ID contains Google test publisher ($testPrefix): $id"
    }
}

$reviewMap = Read-Props (Join-Path $root 'android\review_access.properties')
$reviewSha = ''
if ($reviewMap.ContainsKey('reviewAccessCodeSha256')) {
    $reviewSha = [string]$reviewMap['reviewAccessCodeSha256']
}
if ([string]::IsNullOrWhiteSpace($reviewSha)) {
    $envSha = [string]$env:REVIEW_ACCESS_CODE_SHA256
    if (-not [string]::IsNullOrWhiteSpace($envSha)) { $reviewSha = $envSha.Trim() }
}

$dartDefines = @(
    "--dart-define=ADMOB_APP_ID=$appId",
    "--dart-define=ADMOB_BANNER_ID=$bannerId",
    "--dart-define=ADMOB_INTERSTITIAL_ID=$interstitialId"
)

Write-Host "Building release AAB with production AdMob defines..."
Write-Host ("  ADMOB_APP_ID ends with: " + $appId.Substring([Math]::Max(0, $appId.Length - 8)))
Write-Host ("  ADMOB_BANNER_ID ends with: " + $bannerId.Substring([Math]::Max(0, $bannerId.Length - 8)))
Write-Host ("  ADMOB_INTERSTITIAL_ID ends with: " + $interstitialId.Substring([Math]::Max(0, $interstitialId.Length - 8)))

if (-not [string]::IsNullOrWhiteSpace($reviewSha)) {
    if ($reviewSha.Length -ne 64) {
        throw "reviewAccessCodeSha256 must be 64 hex chars (SHA-256)."
    }
    $dartDefines += "--dart-define=REVIEW_ACCESS_CODE_SHA256=$reviewSha"
    Write-Host "  REVIEW_ACCESS_CODE_SHA256: configured (hash only)"
} else {
    Write-Host "  REVIEW_ACCESS_CODE_SHA256: not set (review unlock disabled in this build)"
}

flutter build appbundle --release @dartDefines

$aab = Join-Path $root 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $aab)) {
    throw "AAB not found at $aab"
}

Write-Host ''
Write-Host 'Verifying AdMob IDs inside AAB...'
& (Join-Path $PSScriptRoot 'verify_aab_admob.ps1') -AabPath $aab -ExpectAppId $appId -ExpectBannerId $bannerId -ExpectInterstitialId $interstitialId

# Review plaintext must never appear in AAB
$plainPath = Join-Path $root 'store\secrets\REVIEW_ACCESS_CODE.txt'
if (Test-Path $plainPath) {
    $plain = (Get-Content $plainPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($plain)) {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $tmp = Join-Path $env:TEMP ("aab_review_check_" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp | Out-Null
        try {
            [System.IO.Compression.ZipFile]::ExtractToDirectory($aab, $tmp)
            $hay = New-Object System.Text.StringBuilder
            Get-ChildItem $tmp -Recurse -File | ForEach-Object {
                $bytes = [IO.File]::ReadAllBytes($_.FullName)
                foreach ($b in $bytes) {
                    if ($b -ge 32 -and $b -le 126) { [void]$hay.Append([char]$b) } else { [void]$hay.Append(' ') }
                }
            }
            if ($hay.ToString().Contains($plain)) {
                throw "FAIL: plaintext review access code found inside release AAB"
            }
            Write-Host "PASS: plaintext review code not present in AAB"
        } finally {
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }
}

$item = Get-Item $aab
$sizeMb = [math]::Round($item.Length / 1MB, 1)
Write-Host ''
Write-Host "AAB: $($item.FullName)"
Write-Host "Size: $sizeMb MB ($($item.Length) bytes)"
