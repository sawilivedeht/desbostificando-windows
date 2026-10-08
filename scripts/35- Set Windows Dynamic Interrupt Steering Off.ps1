# ==============================================================================
# OTIMIZAÇÃO DE ESTADOS DE ENERGIA DE CPU (ANTI-DPC LATENCY / LOW-LATENCY)
# Contexto: Fixação de interrupções de hardware, prevenção de desligamento de núcleos 
# (Core Parking) e bloqueio de estados de sono profundo (C-States) para garantir 
# tempo de resposta de microssegundos da CPU.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar esquemas de energia."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      HARDENING DE ENERGIA DE CPU (INTERRUPT STEERING / C-STATES)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar C-States e Core Parking aumentará ligeiramente o consumo elétrico e a temperatura da CPU em repouso. Recomendado para Desktops/Gaming."

 $LogTweaks = @()

# GUID fixo do SubGrupo de Processadores (Funciona em qualquer idioma do Windows)
 $SubProcessorsGuid = "54533251-82be-4824-96c1-47b60b740d00"

# Função auxiliar usando apenas GUIDs (Evita erros de tradução do Windows)
function Set-PowerCfgSetting {
    param (
        [string]$SettingGuid,
        [int]$Value
    )
    try {
        $out1 = & powercfg /setacvalueindex SCHEME_CURRENT $SubProcessorsGuid $SettingGuid $Value 2>&1
        $out2 = & powercfg /setdcvalueindex SCHEME_CURRENT $SubProcessorsGuid $SettingGuid $Value 2>&1
        
        # Verifica se o powercfg cuspiu algum erro textual
        if ($out1 -match "Invalid|Error|not found" -or $out2 -match "Invalid|Error|not found") {
            return "ERRO"
        }
        return "SUCESSO"
    } catch {
        return "ERRO"
    }
}

# ==============================================================================
# 1. DESATIVAR CORE PARKING (DESLIGAMENTO DE NÚCLEOS)
# ==============================================================================
Write-Host "`n[*] Desativando estacionamento de núcleos (Core Parking)..." -ForegroundColor DarkGray

# GUID do Core Parking Min Cores
 $CoreParkGuid = "0cc5b647-c1df-4637-891a-dec35c318583"
 $CoreParkPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$SubProcessorsGuid\$CoreParkGuid"

if (-not (Test-Path $CoreParkPath)) { New-Item -Path $CoreParkPath -Force | Out-Null }
try {
    $currentAttr = (Get-ItemProperty -Path $CoreParkPath -Name "Attributes" -ErrorAction SilentlyContinue).Attributes
    if ($null -eq $currentAttr -or $currentAttr -ne 2) {
        Set-ItemProperty -Path $CoreParkPath -Name "Attributes" -Value 2 -Type DWord -Force -ErrorAction Stop
    }
} catch {}

 $status = Set-PowerCfgSetting -SettingGuid $CoreParkGuid -Value 100
 $LogTweaks += [PSCustomObject]@{ Feature = "Power: Core Parking"; Acao = "Desativado (100% Núcleos Ativos)"; Status = $status }

# ==============================================================================
# 2. DESATIVAR ESTADOS DE SONO PROFUNDO (C-STATES / IDLE SLEEP)
# ==============================================================================
Write-Host "[*] Desativando estados de economia profunda (C-States)..." -ForegroundColor DarkGray

# GUID do Idle Disable (C-States)
 $CStateGuid = "5d76a2ca-e8c0-402f-a133-2158492d58ad"
 $CStatePath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings\$SubProcessorsGuid\$CStateGuid"

if (-not (Test-Path $CStatePath)) { New-Item -Path $CStatePath -Force | Out-Null }
try {
    $currentAttr = (Get-ItemProperty -Path $CStatePath -Name "Attributes" -ErrorAction SilentlyContinue).Attributes
    if ($null -eq $currentAttr -or $currentAttr -ne 2) {
        Set-ItemProperty -Path $CStatePath -Name "Attributes" -Value 2 -Type DWord -Force -ErrorAction Stop
    }
} catch {}

 $status = Set-PowerCfgSetting -SettingGuid $CStateGuid -Value 1
 $LogTweaks += [PSCustomObject]@{ Feature = "Power: C-States (Idle)"; Acao = "Desativado (CPU Sempre Accordada)"; Status = $status }

# ==============================================================================
# 3. ESTADO MÍNIMO DO PROCESSADOR (ANTI-LATÊNCIA DE CLOCK)
# ==============================================================================
Write-Host "[*] Fixando clock mínimo da CPU (Anti-Ramp-up Latency)..." -ForegroundColor DarkGray

# GUID do Processor Minimum State (Já é visível por padrão no painel)
 $MinStateGuid = "893dee8e-2bef-41e0-89c6-b55d0929964c"
 $status = Set-PowerCfgSetting -SettingGuid $MinStateGuid -Value 100
 $LogTweaks += [PSCustomObject]@{ Feature = "Power: Min CPU State"; Acao = "Fixado em 100% (Zero Downclock)"; Status = $status }

# ==============================================================================
# 4. FORÇAR APLICAÇÃO IMEDIATA DO PERFIL
# ==============================================================================
Write-Host "[*] Consolidando alterações no perfil de energia..." -ForegroundColor DarkGray
 $null = powercfg /setactive SCHEME_CURRENT 2>&1

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Agora você pode abrir o Painel de Controle > Opções de Energia > Alterar configurações avançadas." -ForegroundColor White
Write-Host "2. Você verá que as opções 'Estacionamento de núcleos' e 'Estado de inatividade' foram reveladas e estão desativadas." -ForegroundColor White
Write-Host "3. IMPORTANTE: Se você tem um processador AMD Ryzen de gerações antigas (ex: 1000/2000), desativar C-States pode causar instabilidade. Em Intel e Ryzen modernos, funciona perfeitamente.`n" -ForegroundColor Red

Read-Host "Pressione ENTER para fechar"