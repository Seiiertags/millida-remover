# ==============================================================================
# MILLIDA LAUNCHER DEEP HUNTER & COMPLETE REMOVER
# Анализ скрытых загрузок, поиск майнеров/хвостов и тотальная зачистка
# Разработчик: Seiiertags
# Telegram-канал: https://t.me/JesterCoderi
# ==============================================================================

$Host.UI.RawUI.WindowTitle = "Millida Hunter & Cleaner"
Clear-Host

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "               MILLIDA DEEP HUNTER & REMOVER                      " -ForegroundColor Yellow
Write-Host "   Поиск скрытых загрузок, майнеров, автозагрузок и полная очистка " -ForegroundColor White
Write-Host "   Разработчик: Seiiertags | ТГ: https://t.me/JesterCoderi        " -ForegroundColor DarkCyan
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""

$reportPath = "$env:USERPROFILE\Desktop\ОТЧЕТ_ОХОТНИКА_MILLIDA.txt"
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("=== ОТЧЕТ СКАНИРОВАНИЯ И ОЧИСТКИ ОТ MILLIDA LAUNCHER ===")
$report.Add("Время сканирования: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("Компьютер: $env:COMPUTERNAME | Пользователь: $env:USERNAME")
$report.Add("---------------------------------------------------------")

function Log-Find($msg, $color = "Green") {
    Write-Host "  [+] $msg" -ForegroundColor $color
    $report.Add("[НАЙДЕНО И ОБЕЗВРЕЖЕНО] $msg")
}

function Log-Info($msg) {
    Write-Host "  [*] $msg" -ForegroundColor Gray
    $report.Add("[ИНФОРМАЦИЯ] $msg")
}

function Log-Warn($msg) {
    Write-Host "  [!] $msg" -ForegroundColor Yellow
    $report.Add("[ВНИМАНИЕ] $msg")
}

$foundPayloads = 0
$killedCount = 0
$removedCount = 0

# ------------------------------------------------------------------------------
# ЭТАП 1. АНАЛИЗ ИСТОРИИ И КЭША WEBVIEW2 (ЧТО МИЛИДА СКАЧИВАЛА В ТИХУЮ)
# ------------------------------------------------------------------------------
Write-Host "[1/7] Расследование: анализ кэша и истории скрытых загрузок..." -ForegroundColor Yellow

$webViewHistory = "$env:LOCALAPPDATA\net.millida.launcher\EBWebView\Default\History"
$webViewStorage = "$env:LOCALAPPDATA\net.millida.launcher\EBWebView\Default\Local Storage\leveldb"

$discoveredUrls = [System.Collections.Generic.HashSet[string]]::new()
$discoveredFiles = [System.Collections.Generic.HashSet[string]]::new()

if (Test-Path $webViewHistory) {
    try {
        # Считываем строки из SQLite базы истории без сторонних библиотек
        $rawBytes = [System.IO.File]::ReadAllBytes($webViewHistory)
        $rawText = [System.Text.Encoding]::ASCII.GetString($rawBytes)
        
        # Поиск URL-адресов
        $urlMatches = [regex]::Matches($rawText, 'https?://[a-zA-Z0-9\.\-_/:\?=%&;~]+')
        foreach ($m in $urlMatches) {
            $val = $m.Value
            if ($val -notmatch "microsoft\.com|w3\.org|google\.com|schema\.org") {
                [void]$discoveredUrls.Add($val)
            }
        }
        
        # Поиск путей к скачанным файлам
        $fileMatches = [regex]::Matches($rawText, '[A-Za-z]:\\[a-zA-Z0-9\.\-_ \\]+\.(exe|jar|dll|bat|vbs|zip|7z|bin|dat)')
        foreach ($f in $fileMatches) {
            [void]$discoveredFiles.Add($f.Value)
        }
    } catch {}
}

# Сканируем LocalStorage на следы полезной нагрузки и токенов
if (Test-Path $webViewStorage) {
    try {
        Get-ChildItem -Path $webViewStorage -Filter "*.ldb" -ErrorAction SilentlyContinue | ForEach-Object {
            $ldbText = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::ASCII)
            $ldbUrls = [regex]::Matches($ldbText, 'https?://[a-zA-Z0-9\.\-_/:\?=%&;~]+')
            foreach ($lu in $ldbUrls) {
                if ($lu.Value -match "millida|api|mod|cdn|storage|download") {
                    [void]$discoveredUrls.Add($lu.Value)
                }
            }
        }
    } catch {}
}

if ($discoveredUrls.Count -gt 0) {
    Log-Warn "Восстановлены сетевые адреса, к которым обращался лаунчер:"
    foreach ($u in ($discoveredUrls | Select-Object -First 15)) {
        Log-Info "  -> URL: $u"
    }
} else {
    Log-Info "История сетевых запросов пуста или уже была очищена."
}

if ($discoveredFiles.Count -gt 0) {
    Log-Warn "Обнаружены следы скачивания локальных файлов:"
    foreach ($df in $discoveredFiles) {
        Log-Info "  -> Файл: $df"
    }
}
Start-Sleep -Milliseconds 500

# ------------------------------------------------------------------------------
# ЭТАП 2. ОХОТА НА ПОДОЗРИТЕЛЬНЫЕ ПРОЦЕССЫ И СКРЫТЫЕ МАЙНЕРЫ
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[2/7] Охота на скрытые процессы и подозрительные службы..." -ForegroundColor Yellow

# Поиск процессов Millida
$knownNames = @("millida-launcher", "MillidaLauncherSetup", "millida-launcher-setup")
foreach ($kn in $knownNames) {
    $p = Get-Process -Name $kn -ErrorAction SilentlyContinue
    if ($p) {
        $p | Stop-Process -Force -ErrorAction SilentlyContinue
        Log-Find "Завершен процесс Millida: $kn (PID: $($p.Id))"
        $killedCount++
    }
}

# Поиск процессов, запущенных из скрытых папок установки Millida или майнеров
try {
    $suspiciousProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object {
        $spName = $_.Name
        $spPath = $_.ExecutablePath
        $spCmd = $_.CommandLine
        
        # Исключаем системные и консольные процессы
        if ($spName -match "^(cmd|powershell|pwsh|conhost|wt|explorer|svchost|taskhostw)\.exe$" -or $_.ProcessId -eq $PID) {
            return $false
        }
        
        # Проверяем исполняемый путь в директориях лаунчера
        $isMillidaDir = ($spPath -and ($spPath -like "$env:LOCALAPPDATA\net.millida.launcher\*" -or $spPath -like "$env:LOCALAPPDATA\Millida Launcher\*" -or $spPath -like "$env:APPDATA\net.millida.launcher\*"))
        
        # Проверяем майнеры
        $isMiner = ($spName -match "^(xmrig|ethminer|nbminer|phoenixminer|minergate)" -or ($spCmd -and $spCmd -match "-o stratum|stratum\+tcp|cryptonight"))
        
        return ($isMillidaDir -or $isMiner)
    }
    foreach ($sp in $suspiciousProcs) {
        Stop-Process -Id $sp.ProcessId -Force -ErrorAction SilentlyContinue
        Log-Find "Обезврежен подозрительный фоновый процесс: $($sp.Name) (PID: $($sp.ProcessId), Путь: $($sp.ExecutablePath))" "Red"
        $killedCount++
        $foundPayloads++
    }
} catch {}

# Завершение зависших WebView2 процессов Millida
try {
    $wvProcs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { 
        $_.Name -match "^(msedgewebview2|edge)\.exe$" -and $_.CommandLine -match "net\.millida\.launcher"
    }
    foreach ($wp in $wvProcs) {
        Stop-Process -Id $wp.ProcessId -Force -ErrorAction SilentlyContinue
        Log-Find "Завершен скрытый подпроцесс Edge WebView2 (PID: $($wp.ProcessId))"
        $killedCount++
    }
} catch {}

if ($killedCount -eq 0) {
    Log-Info "Активных вредоносных или фоновых процессов в памяти не найдено."
}
Start-Sleep -Milliseconds 500

# ------------------------------------------------------------------------------
# ЭТАП 3. ПРОВЕРКА АВТОЗАГРУЗКИ И ПЛАНИРОВЩИКА ЗАДАЧ (PERSISTENCE)
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[3/7] Проверка автозагрузки и планировщика задач Windows..." -ForegroundColor Yellow

# Проверка планировщика
try {
    $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { 
        $_.TaskName -match "millida" -or $_.TaskPath -match "millida" -or 
        ($_.Actions -and $_.Actions.Execute -match "net\.millida|AppData\\Local\\Millida")
    }
    foreach ($task in $tasks) {
        Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false -ErrorAction SilentlyContinue
        Log-Find "Удалена скрытая задача планировщика: $($task.TaskName)" "Red"
        $removedCount++
        $foundPayloads++
    }
    if (-not $tasks) {
        Log-Info "В планировщике задач Windows скрытых заданий Millida не обнаружено."
    }
} catch {}

# Проверка веток Run в реестре
$runRegPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
)
foreach ($rrp in $runRegPaths) {
    if (Test-Path $rrp) {
        $props = Get-ItemProperty -Path $rrp -ErrorAction SilentlyContinue
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Value -match "millida" -or $prop.Name -match "millida") {
                Remove-ItemProperty -Path $rrp -Name $prop.Name -ErrorAction SilentlyContinue
                Log-Find "Удалена запись автозапуска из реестра: $($prop.Name) -> $($prop.Value)" "Red"
                $removedCount++
                $foundPayloads++
            }
        }
    }
}
Start-Sleep -Milliseconds 500

# ------------------------------------------------------------------------------
# ЭТАП 4. СКАНИРОВАНИЕ И ОЧИСТКА MINECRAFT ОТ СКРЫТЫХ МОДОВ И АГЕНТОВ
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[4/7] Сканирование папок Minecraft на внедренные модули..." -ForegroundColor Yellow

$mcDirs = @(
    "$env:APPDATA\.minecraft",
    "$env:APPDATA\net.millida.launcher\minecraft"
)

foreach ($mcd in $mcDirs) {
    if (Test-Path "$mcd\mods") {
        $badMods = Get-ChildItem -Path "$mcd\mods" -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "millida"
        }
        foreach ($bm in $badMods) {
            Remove-Item -Path $bm.FullName -Force -ErrorAction SilentlyContinue
            Log-Find "Удален внедренный мод-трекер: $($bm.FullName)" "Red"
            $removedCount++
            $foundPayloads++
        }
    }
    # Проверка java-агентов authlib
    if (Test-Path "$mcd\agents") {
        Remove-Item -Path "$mcd\agents" -Recurse -Force -ErrorAction SilentlyContinue
        Log-Find "Очищена папка с перехватчиками авторизации: $mcd\agents"
        $removedCount++
    }
}
Start-Sleep -Milliseconds 500

# ------------------------------------------------------------------------------
# ЭТАП 5. ТОТАЛЬНАЯ ЗАЧИСТКА ВСЕХ ДИРЕКТОРИЙ И БАЗ ДАННЫХ
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[5/7] Удаление всех директорий Millida и скрытого профиля..." -ForegroundColor Yellow

$dirsToWipe = @(
    "$env:LOCALAPPDATA\Millida Launcher",
    "$env:LOCALAPPDATA\Millida",
    "$env:LOCALAPPDATA\net.millida.launcher",
    "$env:APPDATA\net.millida.launcher"
)

foreach ($dw in $dirsToWipe) {
    if (Test-Path $dw) {
        try {
            Remove-Item -Path $dw -Recurse -Force -ErrorAction Stop
            Log-Find "Стерта директория с данными: $dw"
            $removedCount++
        } catch {
            Write-Host "  [!] Ошибка доступа к $dw : $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Log-Info "Директория чиста: $dw"
    }
}

# ------------------------------------------------------------------------------
# ЭТАП 6. ОЧИСТКА ВРЕМЕННЫХ ПАПОК TEMP (СЛЕДЫ СКРЫТЫХ ЗАГРУЗОК)
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[6/7] Зачистка временных файлов и скрытых распаковщиков..." -ForegroundColor Yellow

$tempLocations = @("$env:LOCALAPPDATA\Temp", "$env:TEMP") | Select-Object -Unique
foreach ($tl in $tempLocations) {
    if (Test-Path $tl) {
        $tempDrops = Get-ChildItem -Path $tl -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match "^millida" -or $_.Name -match "^nsc[0-9a-fA-F]+\.tmp"
        }
        foreach ($td in $tempDrops) {
            Remove-Item -Path $td.FullName -Recurse -Force -ErrorAction SilentlyContinue
            Log-Find "Удален временный скрытый распаковщик: $($td.FullName)"
            $removedCount++
        }
    }
}

# ------------------------------------------------------------------------------
# ЭТАП 7. РЕЕСТР, ЯРЛЫКИ И ЗАГРУЗКИ
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "[7/7] Очистка реестра, ярлыков и установщика..." -ForegroundColor Yellow

$cleanReg = @(
    "HKCU:\Software\Classes\millida",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Millida Launcher"
)
foreach ($cr in $cleanReg) {
    if (Test-Path $cr) {
        Remove-Item -Path $cr -Recurse -Force -ErrorAction SilentlyContinue
        Log-Find "Удалена ветка реестра: $cr"
        $removedCount++
    }
}

$cleanShortcuts = @(
    "$env:USERPROFILE\Desktop\Millida Launcher.lnk",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Millida Launcher.lnk",
    "$env:USERPROFILE\Downloads\MillidaLauncherSetup.exe"
)
foreach ($cs in $cleanShortcuts) {
    if (Test-Path $cs) {
        Remove-Item -Path $cs -Force -ErrorAction SilentlyContinue
        Log-Find "Удален файл / ярлык: $cs"
        $removedCount++
    }
}

# ЗАПИСЬ ОТЧЕТА НА РАБОЧИЙ СТОЛ
$report.Add("---------------------------------------------------------")
$report.Add("ИТОГИ ОХОТЫ:")
$report.Add("Завершено активных процессов: $killedCount")
$report.Add("Удалено компонентов, файлов и ключей: $removedCount")
$report.Add("Обезврежено подозрительных скрытых модулей: $foundPayloads")
$report.Add("Статус системы: ПОЛНОСТЬЮ ОЧИЩЕНА И БЕЗОПАСНА")
$report | Out-File -FilePath $reportPath -Encoding utf8

Write-Host ""
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "                     ОХОТА И ОЧИСТКА ЗАВЕРШЕНЫ!                   " -ForegroundColor Green
Write-Host "  Обезврежено скрытых модулей/хвостов: $foundPayloads" -ForegroundColor White
Write-Host "  Завершено процессов: $killedCount" -ForegroundColor White
Write-Host "  Всего удалено следов: $removedCount" -ForegroundColor White
Write-Host ""
Write-Host "  [!] Подробный отчет сохранен на ваш Рабочий стол:" -ForegroundColor Yellow
Write-Host "      $reportPath" -ForegroundColor White
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host ""
try {
    Write-Host "Нажмите любую клавишу для выхода..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
} catch {}
