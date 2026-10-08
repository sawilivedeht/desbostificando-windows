# ==============================================================================
# OTIMIZAÇÃO DA TELA DE LOGON E BLOQUEIO (GPU / CPU / REDE)
# Contexto: Remoção de efeitos visuais (Mica/Acrylic), desativação de download de 
# imagens em segundo plano (Slideshow) e bloqueio de notificações para garantir 
# consumo de recursos zero quando o PC está travado, deslogado ou na tela de login.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas do Sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        OTIMIZAÇÃO DE TELA DE LOGON E BLOQUEIO (GPU / REDE)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DE EFEITOS VISUAIS (ACRYLIC E MICA) NO LOGON
# ==============================================================================
Write-Host "`n[*] Desativando efeitos de desfoque na tela de logon..." -ForegroundColor DarkGray

 $LogonSystemPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $LogonSystemPath)) { New-Item -Path $LogonSystemPath -Force | Out-Null }

# DisableAcrylicBackgroundOnLogon = 1 desativa tanto o Acrylic (Win10) quanto o Mica (Win11)
 $prop = "DisableAcrylicBackgroundOnLogon"
 $val = 1
if ((Get-ItemProperty -Path $LogonSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $LogonSystemPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Acrylic/Mica Blur"; Acao = "Desativado (Economia de GPU)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Acrylic/Mica Blur"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO SLIDESHOW NA TELA DE BLOQUEIO
# Contexto: O Windows baixa imagens em alta resolução da Microsoft e faz transições 
# suaves (crossfade) na tela de bloqueio. Isso mantém a GPU acordada consumindo 
# energia mesmo com o monitor desligado ou o PC ocioso.
# ==============================================================================
Write-Host "[*] Desativando Slideshow de imagens na tela de bloqueio..." -ForegroundColor DarkGray

 $LockScreenPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path $LockScreenPath)) { New-Item -Path $LockScreenPath -Force | Out-Null }

 $prop = "SlideshowEnabled"
 $val = 0
if ((Get-ItemProperty -Path $LockScreenPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $LockScreenPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow"; Acao = "Desativado (Fim do Crossfade de GPU)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 3. BLOQUEIO DE NOTIFICAÇÕES DE APPS NA TELA DE BLOQUEIO
# Contexto: Quando a tela está travada, o Windows continua permitindo que aplicativos 
# como Discord, Spotify e Mail enviem notificações. Isso acorda a GPU e a placa de rede.
# ==============================================================================
Write-Host "[*] Bloqueando notificações de aplicativos na tela de bloqueio..." -ForegroundColor DarkGray

# CORREÇÃO CRÍTICA: Adicionado os dois pontos (:) no HKLM para que o PowerShell reconheça o drive do registro
 $LogonPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Logon"
if (-not (Test-Path $LogonPolicyPath)) { New-Item -Path $LogonPolicyPath -Force | Out-Null }

 $prop = "DisableLockScreenAppNotifications"
 $val = 1
if ((Get-ItemProperty -Path $LogonPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $LogonPolicyPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: App Notifications"; Acao = "Bloqueadas (Reduz atividade de Rede)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: App Notifications"; Acao = "Já estavam bloqueadas"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: As alterações na tela de Logon só serão visíveis na PRÓXIMA vez que você fizer logoff, bloquear a tela ou reiniciar o computador. O fundo da tela de login ficará com a cor sólida padrão, sem desfoque ou animações." -ForegroundColor Yellow
Write-Host "[!] Isso é excelente para notebooks, pois evita que a tela de bloqueio gaste bateria processando gráficos em segundo plano.`n" -ForegroundColor White

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"