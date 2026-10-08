# ==============================================================================
# SILÊNCIAMENTO TOTAL DO SISTEMA DE NOTIFICAÇÕES E FOCO
# Contexto: Desativação completa da infraestrutura de Toasts, remoção do motor 
# WPN (Windows Push Notification) em execução, desativação do monitoramento 
# do Focus Assist e bloqueio de dicas nativas do sistema.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para matar serviços dinâmicos do sistema."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       DESATIVAÇÃO DO SISTEMA DE NOTIFICAÇÕES E WPN SERVICE          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO GLOBAL DE TOASTS NO REGISTRO (USER-LEVEL)
# ==============================================================================
Write-Host "`n[*] Desativando motor de Toasts no registro..." -ForegroundColor DarkGray

 $NotificationSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Notifications\Settings"
if (-not (Test-Path $NotificationSettingsPath)) { New-Item -Path $NotificationSettingsPath -Force | Out-Null }

 $prop = "NOC_GLOBAL_SETTING_TOASTS_ENABLED"; $val = 0
try {
    if ((Get-ItemProperty -Path $NotificationSettingsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $NotificationSettingsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Registry: Global Toasts"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Registry: Global Toasts"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Registry: Global Toasts"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAÇÃO CORRETA DO WPN USER SERVICE (INSTÂNCIAS DINÂMICAS)
# Contexto: O WpnUserService cria instâncias como "WpnUserService_1a2b3" por sessão. 
# O código antigo escrevia na chave base, que é ignorada. Agora vamos buscar as instâncias 
# reais em execução, matá-las e bloqueá-las no registro.
# ==============================================================================
Write-Host "[*] Caçando e desativando instâncias dinâmicas do WpnService..." -ForegroundColor DarkGray

# Busca todos os serviços que começam com "WpnUserService" (Ex: WpnUserService_12ab3)
 $WpnServices = Get-Service -Name "WpnUserService*" -ErrorAction SilentlyContinue

if ($WpnServices) {
    foreach ($Svc in $WpnServices) {
        $changed = $false
        
        # Para o serviço imediatamente se estiver rodando
        try {
            if ($Svc.Status -eq 'Running') {
                Stop-Service -Name $Svc.Name -Force -NoWait -ErrorAction Stop | Out-Null
                $changed = $true
            }
        } catch { Write-Warning "Falha ao parar o serviço $($Svc.Name)." }
        
        # Altera via API padrão
        try {
            if ($Svc.StartType -ne 'Disabled') {
                Set-Service -Name $Svc.Name -StartupType Disabled -ErrorAction Stop
                $changed = $true
            }
        } catch { Write-Warning "Falha ao desativar $($Svc.Name) via API. Tentando via registro..." }

        # BYPASS DE PPL (Proteção de Processo): Escreve no registro da instância exata
        $SvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)"
        $currentStart = (Get-ItemProperty -Path $SvcRegPath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -ne $currentStart -and $currentStart -ne 4) {
            try {
                Set-ItemProperty -Path $SvcRegPath -Name "Start" -Value 4 -Type DWord -Force -ErrorAction Stop
                $changed = $true
            } catch {}
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $($Svc.Name)"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $($Svc.Name)"; Acao = "Já estava inativo"; Status = "OK" }
        }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: WpnUserService"; Acao = "Nenhuma instância dinâmica encontrada"; Status = "INFO" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DO ASSISTENTE DE FOCO (FOCUS ASSIST)
# Contexto: O Focus Assist monitora aplicativos em tela cheia (jogos) e decide 
# automaticamente suprimir notificações. Esse monitoramento consome ciclos de CPU 
# ociosos. Desativá-lo corta esse overhead.
# ==============================================================================
Write-Host "[*] Desativando regras automáticas do Focus Assist..." -ForegroundColor DarkGray

 $FocusPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\FocusAssist"
if (-not (Test-Path $FocusPath)) { New-Item -Path $FocusPath -Force | Out-Null }

 $prop = "Enabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $FocusPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FocusPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Focus Assist"; Acao = "Desativado (Economia de CPU)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Focus Assist"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Focus Assist"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 4. BLOQUEIO DE NOTIFICAÇÕES NATIVAS (DICAS DA MICROSOFT)
# Contexto: O Windows mostra balões nativos persistentes pedindo para você fazer 
# backup no OneDrive, finalizar a configuração do PC ou usar o Microsoft Edge.
# ==============================================================================
Write-Host "[*] Bloqueando notificações nativas de sugestões..." -ForegroundColor DarkGray

 $CDMPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $CDMPath)) { New-Item -Path $CDMPath -Force | Out-Null }

 $prop = "SubscribedContent-338389Enabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $CDMPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $CDMPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Native Tips"; Acao = "Bloqueado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Native Tips"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Native Tips"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# ATUALIZAÇÃO SEGURA DA SHELL (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças no subsistema visual..." -ForegroundColor DarkGray
    
    try {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction Stop
    } catch {
        # A classe já foi carregada nesta sessão do PowerShell, podemos ignorar o erro e chamar a API.
    }
    
    $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
    $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Aplicativos como Discord, Steam ou Spotify possuem sistemas de notificação próprios." -ForegroundColor Yellow
Write-Host "[!] Este script removeu a capacidade do Windows de mostrá-los na tela, mas eles ainda podem emitir sons de notificação. Desative os sons nas configurações específicas de cada app se necessário.`n" -ForegroundColor Yellow