# Upload keystore oluşturucu (Windows)
# Kullanım: powershell -ExecutionPolicy Bypass -File tool/create_upload_keystore.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keystoreDir = Join-Path $root 'android\keystore'
$keystorePath = Join-Path $keystoreDir 'upload-keystore.jks'
$propsPath = Join-Path $root 'android\key.properties'

if (Test-Path $keystorePath) {
  Write-Host "Keystore zaten var: $keystorePath"
  Write-Host "Üzerine yazmak istemiyorsan Ctrl+C ile çık."
  Pause
}

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

$storePass = Read-Host 'storePassword (keystore sifresi)' -AsSecureString
$keyPass = Read-Host 'keyPassword (genelde ayni)' -AsSecureString
$cn = Read-Host 'Ad Soyad / CN (orn: Tyreest Studio)'
if ([string]::IsNullOrWhiteSpace($cn)) { $cn = 'Tyreest Studio' }

$bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass)
$bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPass)
try {
  $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr1)
  $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr2)
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
}

if ([string]::IsNullOrWhiteSpace($storePassword) -or [string]::IsNullOrWhiteSpace($keyPassword)) {
  throw 'Sifreler bos olamaz.'
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
  # Android Studio JBR fallback
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
    "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $keytool = $c; break }
  }
}
if (-not $keytool) { throw 'keytool bulunamadi. JDK veya Android Studio kurulu olmali.' }

$kt = if ($keytool -is [string]) { $keytool } else { $keytool.Source }

& $kt -genkeypair -v `
  -keystore $keystorePath `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname "CN=$cn, OU=Mobile, O=Tyreest Studio, L=Istanbul, ST=Istanbul, C=TR"

@"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=upload
storeFile=../keystore/upload-keystore.jks
"@ | Set-Content -Path $propsPath -Encoding ASCII

Write-Host ""
Write-Host "OK: $keystorePath"
Write-Host "OK: $propsPath  (git ignore)"
Write-Host "Sirada: flutter build appbundle --release"
Write-Host "AAB: build\app\outputs\bundle\release\app-release.aab"
