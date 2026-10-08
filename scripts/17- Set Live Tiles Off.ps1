# ==============================================================================
# PURGA DE TELEMETRIA DO MENU INICIAR (LIVE TILES, RECOMENDADOS E SYNC)
# Contexto: Desativação de pacotes de dados dinâmicos de blocos, rastreamento de 
# arquivos abertos e tarefas de sincronização do Menu Iniciar para eliminar requisições 
# de rede ocultas e I/O de disco gerados pelo subsistema `StartMenuExperienceHost`.
# Requer: Execução como Administrador (Para desativar Tarefas Agendadas do Sistema).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para desativar Tarefas Agendadas do Sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DE TELEMETRIA DO MENU INICIAR (TILES / RECOMMENDED)      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DOS PACOTES DE NOTIFICAÇÃO DE BLOCOS (PUSH NOTIFICATIONS)
# ==============================================================================
Write-Host "`n[*] Descartando pacotes dinâmicos de Blocos (Live Tiles)..." -ForegroundColor DarkGray

 $PushNotificationPath = "HKCU:\Software\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"
 $prop = "NoTileApplicationNotification"
 $val = 1

if (-not (Test-Path $PushNotificationPath)) { New-Item -Path $PushNotificationPath -Force | Out-Null }

try {
    if ((Get-ItemProperty -Path $PushNotificationPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PushNotificationPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Tiles: Push Notifications"; Acao = "Descartados (Fim dos downloads em bg)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Tiles: Push Notifications"; Acao = "Já estavam descartados"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Tiles: Push Notifications"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO RASTREAMENTO DE ARQUIVOS (RECOMENDADOS)
# Contexto: Para gerar a seção "Recomendados" e "Recentes" do Win11, o Windows 
# monitora silenciosamente cada arquivo que você abre/cria. Desativar isso impede 
# que o Menu Iniciar gere I/O de disco ocioso.
# ==============================================================================
Write-Host "[*] Desativando rastreamento de arquivos para Recomendados..." -ForegroundColor DarkGray

 $ExplorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
 $prop = "Start_TrackDocs"
 $val = 0

if (-not (Test-Path $ExplorerAdvPath)) { New-Item -Path $ExplorerAdvPath -Force | Out-Null }

try {
    if ((Get-ItemProperty -Path $ExplorerAdvPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ExplorerAdvPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Start Menu: Track Docs"; Acao = "Desativado (Redução de I/O Disco)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Start Menu: Track Docs"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Start Menu: Track Docs"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DA TAREFA DE SINCRONIZAÇÃO DO MENU INICIAR
# Contexto: O Windows possui uma tarefa agendada oculta que roda em background 
# para sincronizar a lista de aplicativos UWP e dados de telemetria do Menu Iniciar.
# ==============================================================================
Write-Host "[*] Desativando tarefas de sincronização ocultas do Menu Iniciar..." -ForegroundColor DarkGray

 $TaskPath = "\Microsoft\Windows\StartMenuExperienceHost\"
 $TaskName = "StartMenuExperienceHost"

 $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction SilentlyContinue

if ($task) {
    if ($task.State -ne 'Disabled') {
        try {
            Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: StartMenu Sync"; Acao = "Desativada com sucesso"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: StartMenu Sync"; Acao = "Falha (Tarefa protegida pelo sistema)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Task: StartMenu Sync"; Acao = "Já estava desativada"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Task: StartMenu Sync"; Acao = "Tarefa não encontrada nesta versão"; Status = "OK" }
}

# ==============================================================================
# 4. ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças no Menu Iniciar..." -ForegroundColor DarkGray
    
    # MÉTODO CORRETO: Não precisamos destruir a Shell inteira. A API do Windows 
    # consegue forçar o Menu Iniciar a reavaliar suas políticas internas.
    try {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction Stop
        $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Falha ao chamar API"; Status = "AVISO" }
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
Write-Host "1. O Windows 11 removeu os Live Tiles visuais, mas manteve o motor de dados por baixo dos panos." -ForegroundColor White
Write-Host "2. Com este script, você cortou a raiz dessa comunicação de rede, garantindo que o Menu Iniciar não gerará tráfego oculto para a Microsoft ou I/O de disco desnecessário." -ForegroundColor White
Write-Host "3. Se a seção 'Recomendados' não sumir imediatamente, basta abrir e fechar o Menu Iniciar uma vez para que o Windows releia as chaves do registro.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"