# ==============================================================================
# OTIMIZAÇÃO E HARDENING DE AUTENTICAÇÃO E TELA DE BLOQUEIO
# Contexto: Limpeza de vetores de UI na tela de login, privacidade de contas 
# locais e supressão de processos de rede/ CPU durante o estágio de bloqueio.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas Locais."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     HARDENING DE AUTENTICAÇÃO E TELA DE BLOQUEIO (LOGIN/UI)         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. POLÍTICAS DE SISTEMA E CONTAS LOCAIS (HKLM)
# ==============================================================================
 $SystemPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $SystemPolicyPath)) { New-Item -Path $SystemPolicyPath -Recurse -Force | Out-Null }

# Desativa as perguntas de segurança locais (Anti-Social Engineering)
 $prop = "NoLocalPasswordResetQuestions"; $val = 1
try {
    if ((Get-ItemProperty -Path $SystemPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Perguntas Segurança"; Acao = "Desativadas"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Perguntas Segurança"; Acao = "Já estavam desativadas"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Perguntas Segurança"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Oculta detalhes da conta de usuário (Email/Nome) na tela de login
# Impede que o Windows exponha seu email do Microsoft Account na tela de bloqueio
 $prop = "BlockUserFromShowingAccountDetailsOnSignin"; $val = 1
try {
    if ((Get-ItemProperty -Path $SystemPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Detalhes do Usuário"; Acao = "Ocultos na tela de login"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Detalhes do Usuário"; Acao = "Já estavam ocultos"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Detalhes do Usuário"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. LIMPEZA DE REDE E CPU NA TELA DE BLOQUEIO (HKLM)
# ==============================================================================
 $LogonPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Logon"
if (-not (Test-Path $LogonPath)) { New-Item -Path $LogonPath -Force | Out-Null }

# Desativa notificações de aplicativos na tela de bloqueio
# Impede que a interface acorde processos em segundo plano e faça requisições de rede
 $prop = "DisableLockScreenAppNotifications"; $val = 1
try {
    if ((Get-ItemProperty -Path $LogonPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LogonPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: App Notifications"; Acao = "Desativadas (Economia de Rede)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: App Notifications"; Acao = "Já estavam desativadas"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: App Notifications"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. DESATIVAÇÃO DO SLIDESHOW (HKCU - Configuração do Usuário)
# ==============================================================================
 $LockScreenPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path $LockScreenPath)) { New-Item -Path $LockScreenPath -Force | Out-Null }

# Impede que o Windows fique baixando imagens do Bing e consumindo GPU/CPU
 $prop = "SlideshowEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $LockScreenPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LockScreenPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow"; Acao = "Desativado (Economia de GPU/I/O)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. FORÇA A ATUALIZAÇÃO DE POLÍTICAS (SILENCIOSO)
# ==============================================================================
Write-Host "`n[*] Aplicando políticas no kernel (Aguarde, pode levar alguns segundos)..." -ForegroundColor DarkGray

# Redirecionamento de streams para silenciar o gpupdate nativo
 $null = cmd.exe /c "gpupdate /force >nul 2>&1"

if ($LASTEXITCODE -eq 0) {
    $LogTweaks += [PSCustomObject]@{ Feature = "GPUPDATE"; Acao = "Políticas aplicadas com sucesso"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "GPUPDATE"; Acao = "Falha na aplicação (Requer Reboot?)"; Status = "ERRO" }
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
Write-Host "1. As políticas de tela de login e bloqueio são aplicadas imediatamente pelo GPUPDATE." -ForegroundColor White
Write-Host "2. Elas só serão visíveis na próxima vez que você travar a tela (Win+L) ou reiniciar o PC.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"