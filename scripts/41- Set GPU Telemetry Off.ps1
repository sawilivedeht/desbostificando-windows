# ==============================================================================
# OTIMIZAÇÃO DE HARDWARE: EXPURGO DE TELEMETRIA DE DRIVERS DE VÍDEO (GPU)
# Contexto: Desativação de serviços de telemetria, tarefas agendadas ocultas e 
# binários de envio de dados para NVIDIA (NvTelemetry), AMD (AUEP) e Intel.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         EXPURGO DE TELEMETRIA: DRIVERS DE VÍDEO (GPU)                " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. EXPURGO DE COMPONENTES DE TELEMETRIA NVIDIA (NvTelemetry)
# ==============================================================================
Write-Host "`n[*] Verificando serviços de telemetria da NVIDIA..." -ForegroundColor DarkGray

 $NvidiaServices = @(
    "NvTelemetryContainer",
    "NVDisplay.ContainerLocalSystem"
)

foreach ($Service in $NvidiaServices) {
    try {
        $svc = Get-Service -Name $Service -ErrorAction Stop
        $changed = $false
        
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name $Service -Force -ErrorAction Stop
            $changed = $true
        }
        if ($svc.StartType -ne 'Disabled') {
            Set-Service -Name $Service -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço NV: $Service"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço NV: $Service"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Serviço NV: $Service"; Acao = "Não encontrado (Driver não instalado?)"; Status = "AVISO" }
    }
}

Write-Host "[*] Removendo Tarefas Agendadas da NVIDIA..." -ForegroundColor DarkGray

 $NvidiaTasks = @(
    "\NvTmRep_CrashReport1_{B2FE19EE-0557-4183-8783-1561FC21F1B5}",
    "\NvTmRep_CrashReport2_{B2FE19EE-0557-4183-8783-1561FC21F1B5}",
    "\NvTmRep_CrashReport3_{B2FE19EE-0557-4183-8783-1561FC21F1B5}",
    "\NvTmMon_{B2FE19EE-0557-4183-8783-1561FC21F1B5}"
)

foreach ($TaskPath in $NvidiaTasks) {
    $TaskName = Split-Path $TaskPath -Leaf
    $TaskFolder = Split-Path $TaskPath
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop
        if ($task.State -ne 'Disabled') {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa NV: $TaskName"; Acao = "Desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa NV: $TaskName"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa NV: $TaskName"; Acao = "Não encontrada"; Status = "AVISO" }
    }
}

# ==============================================================================
# 2. EXPURGO DE COMPONENTES DE TELEMETRIA AMD (Radeon Adrenalin)
# ==============================================================================
Write-Host "[*] Removendo Tarefas Agendadas da AMD..." -ForegroundColor DarkGray

 $AmdTasks = @(
    "\AMD\StartDVR",
    "\AMD\RadeonSoftwareImageSharpening",
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipHashes" # Injetada pela AMD
)

foreach ($TaskPath in $AmdTasks) {
    $TaskName = Split-Path $TaskPath -Leaf
    $TaskFolder = Split-Path $TaskPath
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop
        if ($task.State -ne 'Disabled') {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa AMD: $TaskName"; Acao = "Desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa AMD: $TaskName"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Tarefa AMD: $TaskName"; Acao = "Não encontrada"; Status = "AVISO" }
    }
}

Write-Host "[*] Neutralizando binário de telemetria AMD (AMDAUEP)..." -ForegroundColor DarkGray

 $AmdAuepPath = "C:\Program Files\AMD\Performance Profile Client\AMDAUEP.exe"
 $AmdAuepBakPath = "C:\Program Files\AMD\Performance Profile Client\AMDAUEP.bak"

try {
    if (Test-Path $AmdAuepPath) {
        Stop-Process -Name "AMDAUEP" -Force -ErrorAction SilentlyContinue
        Rename-Item -Path $AmdAuepPath -NewName "AMDAUEP.bak" -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "AMD AUEP (Executável)"; Acao = "Processo morto e renomeado para .bak"; Status = "SUCESSO" }
    } elseif (Test-Path $AmdAuepBakPath) {
        $LogTweaks += [PSCustomObject]@{ Feature = "AMD AUEP (Executável)"; Acao = "Já estava neutralizado (.bak)"; Status = "OK" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "AMD AUEP (Executável)"; Acao = "Não encontrado (Driver limpo ou não instalado)"; Status = "AVISO" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "AMD AUEP (Executável)"; Acao = "Falha ao renomear (Permissão negada?)"; Status = "ERRO" }
}

# ==============================================================================
# 3. EXPURGO DE COMPONENTES DE TELEMETRIA INTEL (Graphics Driver Helpers)
# ==============================================================================
Write-Host "[*] Verificando serviços de background da Intel..." -ForegroundColor DarkGray

 $IntelServices = @(
    "Intel(R) GfxCUIServiceService",
    "cphs"
)

foreach ($Service in $IntelServices) {
    try {
        $svc = Get-Service -Name $Service -ErrorAction Stop
        $changed = $false
        
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name $Service -Force -ErrorAction Stop
            $changed = $true
        }
        if ($svc.StartType -ne 'Disabled') {
            Set-Service -Name $Service -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço Intel: $Service"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço Intel: $Service"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Serviço Intel: $Service"; Acao = "Não encontrado (Driver não instalado?)"; Status = "AVISO" }
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
Write-Host "1. É normal que vários itens apareçam como 'AVISO - Não encontrado'. Isso significa que seu PC já está limpo ou você não possui a GPU específica." -ForegroundColor White
Write-Host "2. O arquivo AMDAUEP.bak pode ser excluído manualmente no futuro se desejar." -ForegroundColor White
Write-Host "3. Atualizações de drivers via GeForce Experience ou Adrenalin podem reativar esses serviços. Recomenda-se rodar este script após atualizar drivers.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"