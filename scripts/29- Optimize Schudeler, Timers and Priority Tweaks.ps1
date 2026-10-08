# ==============================================================================
# OTIMIZAÇÃO DE ESCALONAMENTO DE CPU E TEMPORIZADORES (LOW-LATENCY)
# Contexto: Redução máxima de DPC Latency, Input Lag e estabilidade de FPS.
# Requer: Execução como Administrador e REINICIALIZAÇÃO DO SISTEMA.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar o registro e usar o bcdedit."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     OTIMIZAÇÃO DE ESCALONADOR MMCSS, CPU QUANTUM E TIMERS         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar 'Dynamic Tick' prejudica drasticamente a bateria de NOTEBOOKS. Recomendado apenas para Desktops."

 $LogTweaks = @()

# ==============================================================================
# 1. OTIMIZAÇÃO DO ESCALONADOR MULTIMÍDIA (MMCSS - Perfil Games)
# ==============================================================================
 $GamesProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
if (-not (Test-Path $GamesProfilePath)) { New-Item -Path $GamesProfilePath -Recurse -Force | Out-Null }

# GPU Priority (8 = Máximo)
 $prop = "GPU Priority"; $val = 8
try {
    if ((Get-ItemProperty -Path $GamesProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GamesProfilePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Definido para $val"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Priority (6 = High)
 $prop = "Priority"; $val = 6
try {
    if ((Get-ItemProperty -Path $GamesProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GamesProfilePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Definido para $val"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Scheduling Category ("High")
 $prop = "Scheduling Category"; $val = "High"
try {
    if ((Get-ItemProperty -Path $GamesProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GamesProfilePath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Definido para $val"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Affinity (0 = Todos os núcleos disponíveis)
 $prop = "Affinity"; $val = 0
try {
    if ((Get-ItemProperty -Path $GamesProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GamesProfilePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop (Afinidade)"; Acao = "Definido para 0 (Todos os núcleos)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop (Afinidade)"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "MMCSS: $prop (Afinidade)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. PERFIL DO SISTEMA (Reserva de CPU e Throttling de Rede)
# ==============================================================================
 $SystemProfilePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"

 $prop = "NetworkThrottlingIndex"; $val = 0xFFFFFFFF # Desativado (Sem limite de pacotes)
try {
    if ((Get-ItemProperty -Path $SystemProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemProfilePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Network Throttling"; Acao = "Desativado (0xFFFFFFFF)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Network Throttling"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Network Throttling"; Acao = "Falha ao gravar"; Status = "ERRO" } }

 $prop = "SystemResponsiveness"; $val = 0 # 0% de CPU reservada para background
try {
    if ((Get-ItemProperty -Path $SystemProfilePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemProfilePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "System Responsiveness"; Acao = "Definido para 0 (Foco total no jogo)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "System Responsiveness"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "System Responsiveness"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. DIRETIVAS DE ALLOCATION DE CPU (Win32PrioritySeparation)
# ==============================================================================
 $PriorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
 $prop = "Win32PrioritySeparation"; $val = 26 # 0x1A

try {
    if ((Get-ItemProperty -Path $PriorityPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PriorityPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "CPU Quantum (Priority Sep.)"; Acao = "Definido para 26 (Curto/Focado)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "CPU Quantum (Priority Sep.)"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "CPU Quantum (Priority Sep.)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. MODO DE TEMPORIZADOR DE ALTA PRECISÃO (Platform Timers via bcdedit)
# ==============================================================================
# Desativa temporizador dinâmico synthetic (fixa o tick da CPU)
 $null = bcdedit /set disabledynamictick yes 2>&1
if ($LASTEXITCODE -eq 0) {
    $LogTweaks += [PSCustomObject]@{ Feature = "Timer: Dynamic Tick"; Acao = "Desativado"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Timer: Dynamic Tick"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# Força o uso de TSC ou HPET puro (melhora precisão do QueryPerformanceCounter)
 $null = bcdedit /set useplatformtick yes 2>&1
if ($LASTEXITCODE -eq 0) {
    $LogTweaks += [PSCustomObject]@{ Feature = "Timer: Platform Tick"; Acao = "Ativado (Alta Precisão)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Timer: Platform Tick"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 5. GARANTIR PLANO DE ENERGIA "ALTO DESEMPENHO"
# ==============================================================================
# Pega a primeira linha que contém o nome do plano para evitar arrays
 $highPerfLine = powercfg /l | Where-Object { $_ -match "Alto Desempenho|High Performance|Ultimate Performance|Desempenho Máximo" } | Select-Object -First 1

if (-not [string]::IsNullOrWhiteSpace($highPerfLine)) {
    # Extrai o GUID com segurança
    $highPerfGuid = [regex]::Match($highPerfLine, "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})").Value
    
    if (-not [string]::IsNullOrWhiteSpace($highPerfGuid)) {
        $currentSchemeLine = powercfg /getactivescheme
        $currentSchemeGuid = [regex]::Match($currentSchemeLine, "([a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12})").Value
        
        if ($currentSchemeGuid -ne $highPerfGuid) {
            $null = powercfg /setactive $highPerfGuid 2>&1
            $LogTweaks += [PSCustomObject]@{ Feature = "Plano de Energia"; Acao = "Alterado para Alto Desempenho"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Plano de Energia"; Acao = "Alto Desempenho já estava ativo"; Status = "OK" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Plano de Energia"; Acao = "GUID não encontrado na linha"; Status = "AVISO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Plano de Energia"; Acao = "Plano 'Alto Desempenho' não encontrado"; Status = "AVISO" }
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
Write-Host "1. As mudanças no bcdedit e no escalonador EXIGEM a reinicialização do computador para fazerem efeito." -ForegroundColor White
Write-Host "2. Em notebooks, reative o 'Dynamic Tick' (bcdedit /set disabledynamictick no) se notar perda severa de bateria.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"