# Запуск Kaizen в браузере на компьютере через flutter run -d chrome.
#
# ПРАВИЛО (по требованию пользователя): по умолчанию веб подключается
# ТОЛЬКО к настроенному боевому бэкенду (Render), НЕ к localhost.
# Локальный backend используется лишь при явном флаге -Local.
#
# Использование:
#   powershell -ExecutionPolicy Bypass -File scripts\run-web.ps1
#   # -> откроет Chrome и подключится к $DefaultApiBaseUrl (боевой Render)
#
#   # Переопределить адрес боевого бэкенда:
#   powershell -ExecutionPolicy Bypass -File scripts\run-web.ps1 -ApiBaseUrl https://<имя>.onrender.com
#
#   # ЛОКАЛЬНЫЙ режим (только если осознанно нужен localhost; требует npm run dev):
#   powershell -ExecutionPolicy Bypass -File scripts\run-web.ps1 -Local

param(
    [int]$Port = 3000,
    [string]$ApiBaseUrl = '',
    [switch]$Local,
    [string]$Device = 'chrome',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $repoRoot 'app'

# Боевой бэкенд по умолчанию. Если реальный URL другой — задавай через -ApiBaseUrl
# или поправь это значение. НЕ заменять на localhost.
$DefaultApiBaseUrl = 'https://kaizen-backend-d5fr.onrender.com'

# --- 1. Определяем API_BASE_URL ---
if (-not [string]::IsNullOrEmpty($ApiBaseUrl)) {
    $apiUrl = $ApiBaseUrl.TrimEnd('/')
    Write-Host "API_BASE_URL (задан вручную): $apiUrl" -ForegroundColor Green
} elseif (-not $Local) {
    $apiUrl = $DefaultApiBaseUrl.TrimEnd('/')
    Write-Host "API_BASE_URL (боевой Render): $apiUrl" -ForegroundColor Green
} else {
    $apiUrl = "http://localhost:${Port}"
    Write-Host "ЛОКАЛЬНЫЙ режим (-Local). API_BASE_URL: $apiUrl" -ForegroundColor Yellow
}

# --- 2. git-хэш как тег сборки (виден в Профиле) ---
$buildTag = ''
try { $buildTag = (git -C $repoRoot rev-parse --short HEAD).Trim() } catch { $buildTag = '' }
if (-not [string]::IsNullOrEmpty($buildTag)) {
    Write-Host "APP_BUILD_TAG:   $buildTag" -ForegroundColor Green
}

# --- 3. flutter run -d <device> ---
Push-Location $appDir
try {
    flutter run -d $Device --dart-define=API_BASE_URL=$apiUrl --dart-define=APP_BUILD_TAG=$buildTag @FlutterArgs
} finally {
    Pop-Location
}
