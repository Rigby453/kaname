# Запуск Kaizen на телефоне через flutter run.
#
# ПРАВИЛО (по требованию пользователя): по умолчанию приложение подключается
# ТОЛЬКО к настроенному боевому бэкенду (Render), НЕ к localhost/LAN.
# Локальный backend поднимается лишь при явном флаге -Local.
#
# Использование (из корня репо или откуда угодно):
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1
#   # -> подключится к $DefaultApiBaseUrl (боевой Render)
#
#   # Переопределить адрес боевого бэкенда (если URL другой):
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1 -ApiBaseUrl https://<имя>.onrender.com
#
#   # ЛОКАЛЬНЫЙ режим (только если осознанно нужен localhost/LAN; требует npm run dev):
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1 -Local
#
#   # дополнительные аргументы уходят в flutter run, например выбор устройства:
#   powershell -ExecutionPolicy Bypass -File scripts\run-phone.ps1 -- -d <device-id>
#
# Требования: телефон подключён по USB (flutter devices его видит).
# Для боевого режима ничего локально поднимать не нужно — используется задеплоенный бэкенд.
# Для -Local: бэкенд запущен (cd backend; npm run dev), телефон и ноутбук в одной Wi-Fi сети.

param(
    [int]$Port = 3000,
    [string]$ApiBaseUrl = '',
    [switch]$Local,
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
    # Явно задан адрес бэкенда (например, другой Render-сервис).
    $apiUrl = $ApiBaseUrl.TrimEnd('/')
    Write-Host "API_BASE_URL (задан вручную): $apiUrl" -ForegroundColor Green
} elseif (-not $Local) {
    # По умолчанию — боевой сервер (НЕ localhost).
    $apiUrl = $DefaultApiBaseUrl.TrimEnd('/')
    Write-Host "API_BASE_URL (боевой Render): $apiUrl" -ForegroundColor Green
} else {
    # -Local: LAN IP ноутбука (только по явному запросу).
    $defaultRoute = Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric, ifMetric | Select-Object -First 1
    if ($null -eq $defaultRoute) {
        Write-Error 'Не найден маршрут по умолчанию — ноутбук не подключён к сети?'
    }
    $lanIp = (Get-NetIPAddress -InterfaceIndex $defaultRoute.InterfaceIndex -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike '169.254.*' -and $_.IPAddress -ne '127.0.0.1' } |
        Select-Object -First 1).IPAddress
    if ([string]::IsNullOrEmpty($lanIp)) {
        Write-Error 'Не удалось определить LAN IPv4-адрес.'
    }
    $apiUrl = "http://${lanIp}:${Port}"
    Write-Host "ЛОКАЛЬНЫЙ режим (-Local). LAN IP ноутбука: $lanIp" -ForegroundColor Yellow
    Write-Host "API_BASE_URL:    $apiUrl" -ForegroundColor Yellow
}

# --- 2. Проверка, что бэкенд отвечает (не блокирует запуск, только предупреждает) ---
try {
    $health = Invoke-RestMethod -Uri "$apiUrl/health" -TimeoutSec 5
    Write-Host "Бэкенд работает (health: $($health.status))" -ForegroundColor Green
} catch {
    Write-Host "ВНИМАНИЕ: бэкенд по адресу $apiUrl не отвечает." -ForegroundColor Yellow
    if ([string]::IsNullOrEmpty($ApiBaseUrl)) {
        Write-Host 'Запусти его: cd backend; npm run dev' -ForegroundColor Yellow
    }
    Write-Host '(flutter всё равно запустится — приложение работает offline-first)' -ForegroundColor Yellow
}

# --- 3. flutter run с нужным dart-define ---
# Короткий git-хэш → показывается в Профиле как тег сборки (чтобы видеть, какая версия на телефоне).
$buildTag = ''
try { $buildTag = (git -C $repoRoot rev-parse --short HEAD).Trim() } catch { $buildTag = '' }
if (-not [string]::IsNullOrEmpty($buildTag)) {
    Write-Host "APP_BUILD_TAG:   $buildTag" -ForegroundColor Green
}

# Если устройство не указано — берём конкретный ID телефона.
if (-not ($FlutterArgs -contains '-d')) {
    $FlutterArgs = @('-d', '69KFKRQOPJBITGC6') + $FlutterArgs
}
Push-Location $appDir
try {
    flutter run --dart-define=API_BASE_URL=$apiUrl --dart-define=APP_BUILD_TAG=$buildTag @FlutterArgs
} finally {
    Pop-Location
}
