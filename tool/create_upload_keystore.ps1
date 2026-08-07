# Upload keystore olusturucu (Windows)
# Etkilesimli:
#   powershell -ExecutionPolicy Bypass -File tool/create_upload_keystore.ps1
# Otomatik:
#   $env:KIRA_STORE_PASSWORD='...'; $env:KIRA_KEY_PASSWORD='...'
#   powershell -ExecutionPolicy Bypass -File tool/create_upload_keystore.ps1 -NonInteractive

param(
  [switch]$NonInteractive,
  [string]$Cn = 'Tyreest Studio'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keystoreDir = Join-Path $root 'android\keystore'
$keystorePath = Join-Path $keystoreDir 'upload-keystore.jks'
$propsPath = Join-Path $root 'android\key.properties'

if ((Test-Path $keystorePath) -and -not $NonInteractive) {
  Write-Host "Keystore zaten var: $keystorePath"
  Write-Host "Uzerine yazmak istemiyorsan Ctrl+C ile cik."
  Pause
}

if ((Test-Path $keystorePath) -and $NonInteractive) {
  Write-Host "Keystore mevcut, yeniden uretilmedi: $keystorePath"
  if (-not (Test-Path $propsPath)) {
    throw 'key.properties eksik. Keystore var ama props yok - manuel olustur.'
  }
  Write-Host 'OK: mevcut keystore kullanilacak.'
  exit 0
}

New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null

if ($NonInteractive) {
  $storePassword = $env:KIRA_STORE_PASSWORD
  $keyPassword = $env:KIRA_KEY_PASSWORD
  if ([string]::IsNullOrWhiteSpace($keyPassword)) { $keyPassword = $storePassword }
  if ([string]::IsNullOrWhiteSpace($Cn) -and $env:KIRA_KEY_CN) { $Cn = $env:KIRA_KEY_CN }
  if ([string]::IsNullOrWhiteSpace($storePassword)) {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $bytes = New-Object byte[] 24
    $rng.GetBytes($bytes)
    $storePassword = [Convert]::ToBase64String($bytes)
    $keyPassword = $storePassword
    Write-Host 'UYARI: Rastgele sifre uretildi. android/key.properties ve keystore YEDEKLE.'
  }
} else {
  $storePassSecure = Read-Host 'storePassword (keystore sifresi)' -AsSecureString
  $keyPassSecure = Read-Host 'keyPassword (genelde ayni)' -AsSecureString
  $cnInput = Read-Host 'Ad Soyad / CN (orn: Tyreest Studio)'
  if (-not [string]::IsNullOrWhiteSpace($cnInput)) { $Cn = $cnInput }

  $bstr1 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassSecure)
  $bstr2 = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassSecure)
  try {
    $storePassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr1)
    $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr2)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr1)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr2)
  }
}

if ([string]::IsNullOrWhiteSpace($storePassword) -or [string]::IsNullOrWhiteSpace($keyPassword)) {
  throw 'Sifreler bos olamaz.'
}
if ([string]::IsNullOrWhiteSpace($Cn)) { $Cn = 'Tyreest Studio' }

$keytoolCmd = Get-Command keytool -ErrorAction SilentlyContinue
$kt = $null
if ($keytoolCmd) { $kt = $keytoolCmd.Source }
if (-not $kt) {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Android Studio\jbr\bin\keytool.exe",
    "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
  )
  foreach ($c in $candidates) {
    if (Test-Path $c) { $kt = $c; break }
  }
}
if (-not $kt) { throw 'keytool bulunamadi. JDK veya Android Studio kurulu olmali.' }

& $kt -genkeypair -v `
  -keystore $keystorePath `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload `
  -storepass $storePassword `
  -keypass $keyPassword `
  -dname "CN=$Cn, OU=Mobile, O=Tyreest Studio, L=Istanbul, ST=Istanbul, C=TR"

@(
  "storePassword=$storePassword"
  "keyPassword=$keyPassword"
  'keyAlias=upload'
  'storeFile=../keystore/upload-keystore.jks'
) | Set-Content -Path $propsPath -Encoding ASCII

Write-Host ''
Write-Host "OK: $keystorePath"
Write-Host "OK: $propsPath  (git ignore - ASLA commit etme)"
Write-Host 'Sirada: flutter build appbundle --release'
Write-Host 'AAB: build\app\outputs\bundle\release\app-release.aab'
