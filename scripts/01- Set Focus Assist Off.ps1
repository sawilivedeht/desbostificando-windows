# ==============================================================================
# SILENCIAMENTO TOTAL DE INTERFACE E BLOQUEIO DE DISTRAÇÕES (FOCUS MODE)
# Contexto: Desativação de notificações de aplicativos, ocultação da Central de Ações 
# e bloqueio de pop-ups nativos da Microsoft para um ambiente 100% livre de distrações.
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       SILENCIAMENTO DE INTERFACE E BLOQUEIO DE DISTRAÇÕES           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DO SISTEMA DE NOTIFICAÇÕES (TOASTS)
# ==============================================================================
Write-Host "`n[*] Desativando motor de Notificações (Toasts)..." -ForegroundColor DarkGray

 $NotifyPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (-not (Test-Path $NotifyPath)) { New-Item -Path $NotifyPath -Force | Out-Null }

 $prop = "NOC_GLOBAL_SETTING_TOASTS_ENABLED"; $val = 0
if ((Get-ItemProperty -Path $NotifyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $NotifyPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Notificações: App Toasts"; Acao = "Desativados globalmente"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Notificações: App Toasts"; Acao = "Já estavam desativados"; Status = "OK" }
}

# ==============================================================================
# 2. OCULTAR O ÍCONE DA CENTRAL DE AÇÕES (ACTION CENTER)
# Contexto: Mesmo sem notificações, o ícone da Central de Ações na bandeja do sistema 
# pode ser clicado acidentalmente durante jogos, abrindo um painel que rouba o foco.
# ==============================================================================
Write-Host "[*] Ocultando ícone da Central de Ações..." -ForegroundColor DarkGray

 $ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $ExplorerPath)) { New-Item -Path $ExplorerPath -Force | Out-Null }

 $prop = "DisableNotificationCenter"; $val = 1
if ((Get-ItemProperty -Path $ExplorerPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $ExplorerPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Central de Ações"; Acao = "Ícone oculto da bandeja"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Central de Ações"; Acao = "Já estava oculto"; Status = "OK" }
}

# ==============================================================================
# 3. BLOQUEAR SUGESTÕES E DISTRACÇÕES NATIVAS DA MICROSOFT
# Contexto: Corta os pop-ups nativos irritantes pedindo para configurar o PC ou usar o Edge.
# ==============================================================================
Write-Host "[*] Bloqueando pop-ups de sugestões do Windows..." -ForegroundColor DarkGray

 $CDMPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $CDMPath)) { New-Item -Path $CDMPath -Force | Out-Null }

 $DistractSettings = @{
    "SubscribedContent-338389" = 0 # "Dê sua opinião sobre o Windows"
    "SubscribedContent-310093" = 0 # "Sugestões sobre como configurar meu dispositivo"
    "SubscribedContent-338388" = 0 # Dicas e sugestões ao usar o Windows
}

foreach ($setting in $DistractSettings.Keys) {
    $val = $DistractSettings[$setting]
    if ((Get-ItemProperty -Path $CDMPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
        Set-ItemProperty -Path $CDMPath -Name $setting -Value $val -Type DWord -Force
        $LogTweaks += [PSCustomObject]@{ Feature = "Telemetria UI: $setting"; Acao = "Bloqueado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Telemetria UI: $setting"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
}

# ==============================================================================
# ATUALIZAÇÃO SEGURA DA SHELL (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças no subsistema visual..." -ForegroundColor DarkGray
    
    # Utilizando WM_SETTINGCHANGE via SendMessageTimeout para forçar o Windows a reler as políticas
    # Esta é a forma mais segura e nativa de atualizar a UI sem reiniciar o Explorer
    try {
        $signature = @"
        [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
        public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
        $type = Add-Type -MemberDefinition $signature -Name "Win32SendMsg" -Namespace Win32 -PassThru -ErrorAction SilentlyContinue
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $result = [UIntPtr]::Zero
        
        # Envia o broadcast. O "Policy" no lParam avisa que mudanças de configuração ocorreram
        $null = $type::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Policy", 2, 5000, [ref]$result)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API SendMessageTimeout"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Falha ao atualizar via API"; Status = "ERRO" }
    }
    
    # Notificação silenciosa para o usuário
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $balloon = New-Object System.Windows.Forms.NotifyIcon
        $balloon.Icon = [System.Drawing.SystemIcons]::Information
        $balloon.BalloonTipText = "O modo foco foi aplicado. Nenhuma notificação aparecerá."
        $balloon.BalloonTipTitle = "Silenciamento Concluído"
        $balloon.Visible = $true
        $balloon.ShowBalloonTip(3000)
        
        # Pausa para garantir que o balão seja exibido antes de ser destruído
        Start-Sleep -Seconds 4
        $balloon.Dispose() # CRÍTICO: Libera o ícone da bandeja do sistema e limpa a memória
    } catch {
        # Ignora silenciosamente se a notificação não puder ser exibida
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

Write-Host "`n[!] NOTA: Aplicativos de terceiros (como Discord ou Steam) possuem suas próprias configurações de notificação internas." -ForegroundColor Yellow
Write-Host "[!] Este script removeu a capacidade do Windows de mostrá-las na tela, mas eles ainda podem emitir sons. Desative os sons nas configurações específicas de cada app se necessário.`n" -ForegroundColor Yellow