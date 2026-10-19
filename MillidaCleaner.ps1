# ==============================================================================
# MILLIDA LAUNCHER CLEANER & REMOVER
# Полная очистка системы от Millida Launcher, скрытых служб, кэша и следов
# Разработчик: Seiiertags
# Telegram-канал: https://t.me/JesterCoderi
# ==============================================================================

$Host.UI.RawUI.WindowTitle = "Millida Launcher Complete Cleaner"
Clear-Host

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               MILLIDA LAUNCHER COMPLETE CLEANER                  " -ForegroundColor Yellow
Write-Host "     Автоматическое удаление лаунчера, скрытых служб и следов     " -ForegroundColor White
Write-Host "   Разработчик: Seiiertags | ТГ: https://t.me/JesterCoderi        " -ForegroundColor DarkCyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$removedCount = 0
$killedCount = 0

# 1. ЗАВЕРШЕНИЕ ПРОЦЕССОВ
Write-Host "[1/6] Поиск и завершение активных процессов..." -ForegroundColor Yellow

$procsToKill = @("millida-launcher", "MillidaLauncherSetup", "millida-launcher-setup")
foreach ($p in $procsToKill) {
    $found = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($found) {
        $found | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Завершен процесс: $p" -ForegroundColor Green
        $killedCount++
    }
}

# Поиск зависших WebView2 процессов, привязанных к Millida
try {
    $webviews = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
        $_.CommandLine -match "net\.millida\.launcher" -or $_.CommandLine -match "Millida Launcher"
    }
    foreach ($wv in $webviews) {
        Stop-Process -Id $wv.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Завершен скрытый подпроцесс WebView2 (PID: $($wv.ProcessId))" -ForegroundColor Green
        $killedCount++
    }
} catch {}

if ($killedCount -eq 0) {
    Write-Host "  [*] Активных процессов Millida не обнаружено." -ForegroundColor Gray
}
Start-Sleep -Milliseconds 600

# 2. УДАЛЕНИЕ ОСНОВНЫХ ДИРЕКТОРИЙ
Write-Host ""
Write-Host "[2/6] Удаление директорий лаунчера и баз данных..." -ForegroundColor Yellow

$dirs = @(
    "$env:LOCALAPPDATA\Millida Launcher",
    "$env:LOCALAPPDATA\Millida",
    "$env:LOCALAPPDATA\net.millida.launcher",
    "$env:APPDATA\net.millida.launcher"
)

foreach ($d in $dirs) {
    if (Test-Path $d) {
        try {
            Remove-Item -Path $d -Recurse -Force -ErrorAction Stop
            Write-Host "  [+] Успешно удалена папка: $d" -ForegroundColor Green
            $removedCount++
        } catch {
            Write-Host "  [!] Ошибка при удалении $d : $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [*] Папка отсутствует: $d" -ForegroundColor Gray
    }
}

# 3. ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ И ДРОППЕРОВ ИЗ TEMP
Write-Host ""
Write-Host "[3/6] Сканирование и очистка временных файлов (Temp)..." -ForegroundColor Yellow

$tempPaths = @(
    "$env:LOCALAPPDATA\Temp",
    "$env:TEMP"
) | Select-Object -Unique

foreach ($tp in $tempPaths) {
    if (Test-Path $tp) {
        $staleItems = Get-ChildItem -Path $tp -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "^millida" -or $_.Name -match "^nsc[0-9a-fA-F]+\.tmp"
        }
        foreach ($item in $staleItems) {
            try {
                Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "  [+] Удален временный файл инсталлятора: $($item.FullName)" -ForegroundColor Green
                $removedCount++
            } catch {}
        }
    }
}

# 4. ПРОВЕРКА И ОЧИСТКА ВНЕДРЕННЫХ МОДОВ В .MINECRAFT
Write-Host ""
Write-Host "[4/6] Проверка папки модов игры на скрытые трекеры..." -ForegroundColor Yellow

$mcModsPath = "$env:APPDATA\.minecraft\mods"
if (Test-Path $mcModsPath) {
    $injectedMods = Get-ChildItem -Path $mcModsPath -Filter "*millida*" -ErrorAction SilentlyContinue
    foreach ($mod in $injectedMods) {
        try {
            Remove-Item -Path $mod.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Удален внедренный мод игры: $($mod.FullName)" -ForegroundColor Green
            $removedCount++
        } catch {}
    }
    if (-not $injectedMods) {
        Write-Host "  [*] В .minecraft\mods следов мода Millida не найдено." -ForegroundColor Gray
    }
} else {
    Write-Host "  [*] Папка .minecraft\mods не обнаружена." -ForegroundColor Gray
}

# 5. ОЧИСТКА РЕЕСТРА WINDOWS
Write-Host ""
Write-Host "[5/6] Очистка веток реестра (Deep Link и автоустановка)..." -ForegroundColor Yellow

$regKeys = @(
    "HKCU:\Software\Classes\millida",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Millida Launcher"
)

foreach ($rk in $regKeys) {
    if (Test-Path $rk) {
        try {
            Remove-Item -Path $rk -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  [+] Удален ключ реестра: $rk" -ForegroundColor Green
            $removedCount++
        } catch {
            Write-Host "  [!] Не удалось удалить ключ $rk" -ForegroundColor Red
        }
    } else {
        Write-Host "  [*] Запись в реестре отсутствует: $rk" -ForegroundColor Gray
    }
}

# 6. УДАЛЕНИЕ ЯРЛЫКОВ И УСТАНОВЩИКА
Write-Host ""
Write-Host "[6/6] Удаление ярлыков и загруженного инсталлятора..." -ForegroundColor Yellow

$shortcuts = @(
    "$env:USERPROFILE\Desktop\Millida Launcher.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Millida Launcher.lnk"
)

foreach ($sc in $shortcuts) {
    if (Test-Path $sc) {
        Remove-Item -Path $sc -Force -ErrorAction SilentlyContinue
        Write-Host "  [+] Удален ярлык: $sc" -ForegroundColor Green
        $removedCount++
    }
}

$downloadedInstaller = "$env:USERPROFILE\Downloads\MillidaLauncherSetup.exe"
if (Test-Path $downloadedInstaller) {
    Remove-Item -Path $downloadedInstaller -Force -ErrorAction SilentlyContinue
    Write-Host "  [+] Удален установщик из загрузок: $downloadedInstaller" -ForegroundColor Green
    $removedCount++
}

# ИТОГОВЫЙ ОТЧЕТ
Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "                      ОЧИСТКА ЗАВЕРШЕНА!                          " -ForegroundColor Green
Write-Host "  Завершено процессов: $killedCount" -ForegroundColor White
Write-Host "  Удалено компонентов, файлов и веток: $removedCount" -ForegroundColor White
Write-Host "  Ваш компьютер полностью очищен от следов Millida Launcher." -ForegroundColor Green
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
try {
    Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {}
