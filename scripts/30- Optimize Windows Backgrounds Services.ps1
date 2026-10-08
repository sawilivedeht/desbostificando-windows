# ==============================================================================
# DEBLOATING DE SEGUNDO PLANO: SERVIÇOS, TELEMETRIA E CLOUD CONTENT
# Contexto: Eliminação de processos de monitoramento, telemetria e sugestões 
# para maximizar recursos de CPU, RAM e I/O de Disco.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar serviços e tarefas agendadas."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DE TELEMETRIA, SERVIÇOS REDUNDANTES E CLOUD CONTENT      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO INTELIGENTE DE SERVIÇOS (SOMENTE O NECESSÁRIO)
# ==============================================================================
Write-Host "`n[*] Otimizando serviços em segundo plano..." -ForegroundColor DarkGray

 $ServicesToDisable = @(
    "SysMain",          # Otimização de disco (Inútil em NVMe, causa I/O)
    "WbioSrvc",         # Biometria do Windows (Se não usa leitor de impressão digital do Windows Hello)
    "DiagTrack",        # Serviço de Telemetria Conectado (O maior culpado por I/O aleatório)
    "dmwappushservice", # Roteamento de Mensagens WAP (Telemetria de UWP)
    "WerSvc",           # Relatório de Erros do Windows (Congela o PC para escrever .dmp)
    "PcaSvc",           # Assistente de Compatibilidade (Verifica apps velhos em segundo plano)
    "MapsBroker",       # Mapas Baixados (100% inútil em Desktops/Gaming)
    "RetailDemo",       # Modo Loja (Inútil para usuários finais)
    "TrkWks",           # Rastreamento de Link NTFS (Inútil fora de servidores corporativos)
    "WpcSvc",           # Controle dos Pais (Consome validação de janela)
    "SensrSvc",         # Dados de Sensor (Inútil sem acelerômetros/giroscópios)
    "XblAuthManager",   # Gerenciador de Autenticação Xbox
    "XblGameSave",      # Serviço de Salvamento em Nuvem Xbox
    "XboxNetApiSvc"     # API de Rede Xbox
)

foreach ($ServiceName in $ServicesToDisable) {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($service) {
        $changed = $false
        try {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction Stop
                $changed = $true
            }
            if ($service.StartType -ne 'Disabled') {
                Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
                $changed = $true
            }

            if ($changed) {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Já estava desativado"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Falha (Protegido pelo sistema?)"; Status = "ERRO" }
        }
    }
}

# ==============================================================================
# 2. SUSPENSÃO SEGURA DE TAREFAS AGENDADAS
# ==============================================================================
Write-Host "[*] Desativando tarefas agendadas de telemetria..." -ForegroundColor DarkGray

 $TasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Speech\SpeechModelDownloadTask",
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo"
)

foreach ($TaskFullPath in $TasksToDisable) {
    $TaskName = Split-Path $TaskFullPath -Leaf
    $TaskPath = Split-Path $TaskFullPath
    
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue
    
    if ($task) {
        try {
            if ($task.State -ne 'Disabled') {
                Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
                $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Desativada"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Já estava desativada"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Falha ao desativar"; Status = "ERRO" }
        }
    }
}

# ==============================================================================
# 3. BLOQUEIO DO APPCOMPAT ENGINE (REGISTRO)
# ==============================================================================
Write-Host "[*] Bloqueando motores de compatibilidade e inventário..." -ForegroundColor DarkGray

 $AppCompatPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
if (-not (Test-Path $AppCompatPath)) { New-Item -Path $AppCompatPath -Force | Out-Null }

 $AppCompatSettings = @{
    "DisablePCA" = 1
    "DisableInventory" = 1
}

foreach ($setting in $AppCompatSettings.Keys) {
    try {
        if ((Get-ItemProperty -Path $AppCompatPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $AppCompatSettings[$setting]) {
            Set-ItemProperty -Path $AppCompatPath -Name $setting -Value $AppCompatSettings[$setting] -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AppCompat $setting"; Acao = "Bloqueado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AppCompat $setting"; Acao = "Já estava bloqueado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AppCompat $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 4. DESATIVAÇÃO DO CLOUD CONTENT E SOFT LANDING
# ==============================================================================
Write-Host "[*] Bloqueando Cloud Content e Sugestões da Microsoft..." -ForegroundColor DarkGray

 $CloudPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $CloudPath)) { New-Item -Path $CloudPath -Force | Out-Null }

 $CloudSettings = @{
    "DisableSoftLanding" = 1           
    "DisableWindowsConsumerFeatures" = 1 
    "DisableCloudOptimizedContent" = 1  
}

foreach ($setting in $CloudSettings.Keys) {
    try {
        if ((Get-ItemProperty -Path $CloudPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $CloudSettings[$setting]) {
            Set-ItemProperty -Path $CloudPath -Name $setting -Value $CloudSettings[$setting] -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Cloud $setting"; Acao = "Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Cloud $setting"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Cloud $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Alguns serviços (como o DiagTrack) são protegidos pelo Windows e podem continuar rodando até a próxima reinicialização." -ForegroundColor White
Write-Host "2. Ao reiniciar, a flag 'Disabled' os impedirá de iniciar novamente.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"