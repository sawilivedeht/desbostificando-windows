# ==============================================================================
# CONTROLE RÍGIDO DO WINDOWS UPDATE E OTIMIZAÇÃO DE ENTREGA (I/O DE REDE)
# Contexto: Desativação de downloads/instalações automáticas, bloqueio de drivers 
# genéricos, assassinato de tarefas de reativação do WU e desativação do P2P de 
# atualizações para evitar picos de disco e rede em segundo plano.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas de Atualização e Tarefas Agendadas."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     CONTROLE RÍGIDO DO WINDOWS UPDATE E PURGA DE P2P (I/O)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar o Windows Update deixa o PC vulnerável a falhas de segurança descobertas. Faça verificações manuais periodicamente."

 $LogTweaks = @()

# ==============================================================================
# 1. INJEÇÃO DE DIRETIVAS DE ATUALIZAÇÃO AUTOMÁTICA (AU POLICY)
# ==============================================================================
Write-Host "`n[*] Configurando diretivas de atualização..." -ForegroundColor DarkGray

 $AuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
if (-not (Test-Path $AuPolicyPath)) { New-Item -Path $AuPolicyPath -Force | Out-Null }

# NoAutoUpdate = 1: Impede o motor de baixar/instalar sozinho
 $prop = "NoAutoUpdate"; $val = 1
try {
    if ((Get-ItemProperty -Path $AuPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AuPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: NoAutoUpdate"; Acao = "Ativado (Bloqueio total)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: NoAutoUpdate"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: NoAutoUpdate"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# AUOptions = 2: Configura a interface para "Apenas notificar para download"
 $prop = "AUOptions"; $val = 2
try {
    if ((Get-ItemProperty -Path $AuPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AuPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AU Options"; Acao = "Modo Notificação"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AU Options"; Acao = "Já estava configurado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: AU Options"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. BLOQUEIO DE DOWNLOAD DE DRIVERS
# ==============================================================================
Write-Host "[*] Bloqueando injeção de drivers via WU..." -ForegroundColor DarkGray

 $WuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (-not (Test-Path $WuPolicyPath)) { New-Item -Path $WuPolicyPath -Force | Out-Null }

 $prop = "ExcludeWUDriversInQualityUpdate"; $val = 1
try {
    if ((Get-ItemProperty -Path $WuPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $WuPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Drivers"; Acao = "Bloqueado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Drivers"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Drivers"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. INTERRUPÇÃO DOS SERVIÇOS DO ECOSSISTEMA WU
# ==============================================================================
Write-Host "[*] Interrompendo serviços do ecossistema..." -ForegroundColor DarkGray

 $UpdateServices = @(
    "wuauserv",  # Windows Update Service
    "UsoSvc"     # Update Orchestrator Service
)

foreach ($ServiceName in $UpdateServices) {
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
        $changed = $false
        
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction Stop
            $changed = $true
        }
        # Altera para Manual (ao invés de Disabled) para permitir checagem manual
        if ($service.StartType -ne 'Manual') {
            Set-Service -Name $ServiceName -StartupType Manual -ErrorAction Stop
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Parado e colocado em Manual"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Já estava em Manual e parado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Falha ao desativar (Protegido?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 4. DESATIVAÇÃO DAS TAREFAS AGENDADAS DO UPDATE ORCHESTRATOR
# Contexto: O Windows 10/11 possui tarefas no Task Scheduler que rodam a cada 1 hora. 
# Elas verificam se o WU está ativo e, se você o desativou, elas REATIVAM o serviço 
# UsoSvc para "Automático". Desativar essas tarefas é o único jeito de manter o WU morto.
# ==============================================================================
Write-Host "[*] Desativando tarefas de reativação automática (UpdateOrchestrator)..." -ForegroundColor DarkGray

 $WUTasks = @(
    "\Microsoft\Windows\UpdateOrchestrator\Reboot_AC",
    "\Microsoft\Windows\UpdateOrchestrator\Reboot_Battery",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Retry Scan",
    "\Microsoft\Windows\UpdateOrchestrator\UpdateOrchestrator"
)

foreach ($TaskPath in $WUTasks) {
    $TaskName = Split-Path $TaskPath -Leaf
    $TaskFolder = Split-Path $TaskPath
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop
        if ($task.State -ne 'Disabled') {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Não encontrada ou bloqueada"; Status = "AVISO" }
    }
}

# ==============================================================================
# 5. DESATIVAÇÃO DO P2P DO DELIVERY OPTIMIZATION (I/O DE REDE)
# Contexto: O Delivery Optimization (DO) usa seu PC como um "Torrent" para 
# distribuir atualizações da Microsoft para outros PCs da internet. Isso consome 
# seu disco e sua rede de upload.
# DODownloadMode = 0 significa "Baixar apenas da Microsoft" (Sem P2P).
# ==============================================================================
Write-Host "[*] Desativando P2P de Atualizações (Delivery Optimization)..." -ForegroundColor DarkGray

 $DOPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
if (-not (Test-Path $DOPath)) { New-Item -Path $DOPath -Force | Out-Null }

 $prop = "DODownloadMode"; $val = 0
try {
    if ((Get-ItemProperty -Path $DOPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DOPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Delivery Opt. P2P"; Acao = "Desativado (Sem uploads de rede)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Delivery Opt. P2P"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Delivery Opt. P2P"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Quando você abrir o 'Windows Update', ele exibirá uma mensagem vermelha:" -ForegroundColor White
Write-Host "   'Algumas configurações são gerenciadas pela sua organização' OU 'O dispositivo está em risco'." -ForegroundColor White
Write-Host "2. Isto é PERFEITAMENTE NORMAL e significa que o script funcionou. Para atualizar, basta clicar no botão 'Procurar atualizações' manualmente.`n" -ForegroundColor Yellow

Read-Host "Pressione ENTER para fechar"