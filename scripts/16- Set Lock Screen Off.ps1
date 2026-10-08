# ==============================================================================
# OTIMIZAÇÃO EXTREMA DE VELOCIDADE DE LOGON (SKIP LOCK SCREEN / FAST BOOT)
# Contexto: Remoção de camadas de interface no caminho de boot para minimizar o tempo 
# entre a BIOS e a Área de Trabalho. Inclui bypass de Ctrl+Alt+Del (AVISO: Reduz segurança).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas de Logon."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         OTIMIZAÇÃO DE LOGON: SKIP LOCK SCREEN E FAST BOOT            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. SUPRESSÃO DA TELA DE BLOQUEIO (NO LOCK SCREEN)
# ==============================================================================
Write-Host "`n[*] Suprimindo Tela de Bloqueio..." -ForegroundColor DarkGray

 $PersonalizationPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization"
if (-not (Test-Path $PersonalizationPath)) { New-Item -Path $PersonalizationPath -Force | Out-Null }

 $prop = "NoLockScreen"
 $val = 1
if ((Get-ItemProperty -Path $PersonalizationPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $PersonalizationPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Lock Screen UI"; Acao = "Suprimida"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Lock Screen UI"; Acao = "Já estava suprimida"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO CTRL+ALT+DEL (DISABLE CAD)
# ==============================================================================
Write-Host "[*] Desativar exigência de CTRL+ALT+DEL..." -ForegroundColor DarkGray

 $SystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $SystemPath)) { New-Item -Path $SystemPath -Force | Out-Null }

 $prop = "DisableCAD"
 $val = 1
if ((Get-ItemProperty -Path $SystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $SystemPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Secure Attention Seq"; Acao = "Desativada (Pula Ctrl+Alt+Del)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: Secure Attention Seq"; Acao = "Já estava desativada"; Status = "OK" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DO WINDOWS SPOTLIGHT (DOWNLOAD EM BACKGROUND)
# Contexto: Mesmo sem a UI da tela de bloqueio, o Windows continuava usando a banda 
# larga para baixar imagens 4K do Windows Spotlight e "Dicas divertidas". 
# Desativar isso impede downloads ociosos de rede e I/O de disco.
# ==============================================================================
Write-Host "[*] Bloqueando download de imagens do Windows Spotlight..." -ForegroundColor DarkGray

 $CloudPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $CloudPath)) { New-Item -Path $CloudPath -Force | Out-Null }

 $prop = "DisableWindowsSpotlight"
 $val = 1
if ((Get-ItemProperty -Path $CloudPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $CloudPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Background: Win Spotlight"; Acao = "Downloads bloqueados"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Background: Win Spotlight"; Acao = "Já estava bloqueado"; Status = "OK" }
}

# ==============================================================================
# 4. CORREÇÃO DA "TELA PRETA" DO LOGONUI
# Contexto: Quando removemos a tela de bloqueio, o Windows exibe uma tela preta 
# estática por 2 a 5 segundos enquanto carrega o LogonUI em background. Desativar a 
# animação do primeiro logon corta essa pausa, fazendo a transição ser quase instantânea.
# ==============================================================================
Write-Host "[*] Otimizando transição de carga do LogonUI..." -ForegroundColor DarkGray

 $prop = "EnableFirstLogonAnimation"
 $val = 0
if ((Get-ItemProperty -Path $SystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $SystemPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: UI Animation"; Acao = "Desativada (Fim da tela preta pausada)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Logon: UI Animation"; Acao = "Já estava desativada"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] AVISO DE SEGURANÇA: A desativação do Ctrl+Alt+Del (DisableCAD) remove uma camada de segurança." -ForegroundColor Red
Write-Host "Se um malware conseguir se executar antes do login, ele poderá simular a tela de senha com mais facilidade. Use por sua conta e risco em PCs estritamente controlados." -ForegroundColor White

Write-Host "`n[!] PRÓXIMO PASSO: As mudanças no caminho de boot EXIGEM que você faça LOGOFF ou REINICIE o PC para fazer efeito." -ForegroundColor Yellow
Write-Host "[!] Na próxima vez que você ligar o PC, ele pulará a tela de bloqueio e o logon será quase instantâneo.`n" -ForegroundColor White

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"