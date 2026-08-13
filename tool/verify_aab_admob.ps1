param(
    [Parameter(Mandatory = $true)][string]$AabPath,
    [Parameter(Mandatory = $true)][string]$ExpectAppId,
    [Parameter(Mandatory = $true)][string]$ExpectBannerId,
    [Parameter(Mandatory = $true)][string]$ExpectInterstitialId
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $AabPath)) { throw "AAB not found: $AabPath" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path $env:TEMP ("aab_admob_verify_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($AabPath, $tmp)

    $haystack = New-Object System.Text.StringBuilder
    Get-ChildItem -Path $tmp -Recurse -File | ForEach-Object {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
        $sb = New-Object System.Text.StringBuilder
        foreach ($b in $bytes) {
            if ($b -ge 32 -and $b -le 126) { [void]$sb.Append([char]$b) }
            else { [void]$sb.Append(' ') }
        }
        [void]$haystack.Append(' ')
        [void]$haystack.Append($sb.ToString())
    }
    $text = $haystack.ToString()

    $testPub = '3940256099942544'
    $testHits = @()
    if ($text.Contains("ca-app-pub-$testPub")) { $testHits += "ca-app-pub-$testPub" }
    if ($text.Contains($testPub)) { $testHits += $testPub }

    $missing = @()
    foreach ($id in @($ExpectAppId, $ExpectBannerId, $ExpectInterstitialId)) {
        if (-not $text.Contains($id)) { $missing += $id }
    }

    Write-Host ("Expect App ID present: " + (-not ($missing -contains $ExpectAppId)))
    Write-Host ("Expect Banner ID present: " + (-not ($missing -contains $ExpectBannerId)))
    Write-Host ("Expect Interstitial ID present: " + (-not ($missing -contains $ExpectInterstitialId)))
    Write-Host ("Google test publisher leak: " + ($testHits.Count -gt 0))

    if ($testHits.Count -gt 0) {
        throw ("FAIL: Google test AdMob ID(s) found in release AAB: " + ($testHits -join ', '))
    }
    if ($missing.Count -gt 0) {
        throw ("FAIL: Expected production AdMob ID(s) not found in AAB payload: " + ($missing -join ', '))
    }

    Write-Host 'PASS: production AdMob App/Banner/Interstitial IDs present; no Google test publisher ID.'
}
finally {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
