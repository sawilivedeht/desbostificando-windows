# ==============================================================================
# DESATIVAÇÃO COMPLETA DO SMARTSCREEN E PROTEÇÃO CONTRA PHISHING
# Contexto: Remoção de gargalos de rede/disco ao baixar arquivos, eliminação de 
# bloqueios de stream (Zone.Identifier) e supressão de alertas de reputação.
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
Write-Host "     DESATIVAÇÃO DO SMARTSCREEN, PHISHING E BLOQUEIOS DE DOWNLOAD     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar o SmartScreen remove uma camada de segurança contra arquivos maliciosos baixados da internet."

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO NO EXPLORER DE ARQUIVOS (VERIFICAÇÃO DE DOWNLOADS)
# ==============================================================================
Write-Host "`n[*] Configurando políticas do Explorer..." -ForegroundColor DarkGray

 $ExplorerPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $ExplorerPath)) { New-Item -Path $ExplorerPath -Force | Out-Null }

 $prop = "EnableSmartScreen"
 $val = "ShellSmartScreenDisabled"
if ((Get-ItemProperty -Path $ExplorerPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $ExplorerPath -Name $prop -Value $val -Type String -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: SmartScreen"; Acao = "Desativado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: SmartScreen"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAÇÃO NA REPOSIÇÃO DE APPS DA MICROSOFT STORE (APPHOST)
# ==============================================================================
 $AppXPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost"
if (-not (Test-Path $AppXPath)) { New-Item -Path $AppXPath -Force | Out-Null }

 $prop = "EnableWebWebContentEvaluation"
 $val = 0
if ((Get-ItemProperty -Path $AppXPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $AppXPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Store: AppHost Evaluation"; Acao = "Desativado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Store: AppHost Evaluation"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 3. DESATIVAÇÃO NO MOTOR CENTRAL DO WINDOWS DEFENDER
# Contexto: No Windows 11, a interface do Windows Security gerencia o SmartScreen 
# como "Proteção contra Phishing". Desativar aqui garante que a UI fique verde/oculta.
# ==============================================================================
Write-Host "[*] Desativando motor de Phishing do Windows Defender..." -ForegroundColor DarkGray

 $DefenderSSPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen"
if (-not (Test-Path $DefenderSSPath)) { New-Item -Path $DefenderSSPath -Force | Out-Null }

 $prop = "Enabled"
 $val = 0
if ((Get-ItemProperty -Path $DefenderSSPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $DefenderSSPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Defender: Phishing Engine"; Acao = "Desativado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Defender: Phishing Engine"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 4. DESATIVAÇÃO NO MICROSOFT EDGE (CHROMIUM)
# Contexto: O Edge possui seu próprio SmartScreen independente. É ele quem coloca 
# a barra amarela "O arquivo não é comumente baixado" e atrasa downloads de .exe/.zip.
# ==============================================================================
Write-Host "[*] Desativando SmartScreen no Microsoft Edge..." -ForegroundColor DarkGray

 $EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }

# Desativa o motor de verificação de reputação
 $prop = "SmartScreenEnabled"
 $val = 0
if ((Get-ItemProperty -Path $EdgePolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $EdgePolicyPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Edge: SmartScreen Engine"; Acao = "Desativado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Edge: SmartScreen Engine"; Acao = "Já estava desativado"; Status = "OK" }
}

# Impede que o usuário seja impedido de clicar em "Manter assim mesmo" (Bypass de aviso)
 $prop = "PreventSmartScreenPromptOverride"
 $val = 0
if ((Get-ItemProperty -Path $EdgePolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $EdgePolicyPath -Name $prop -Value $val -Type DWord -Force
    # CORREÇÃO: Adicionado o log que estava faltando para esta propriedade
    $LogTweaks += [PSCustomObject]@{ Feature = "Edge: Prompt Override"; Acao = "Definido para 0 (Permite Bypass)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Edge: Prompt Override"; Acao = "Já estava configurado"; Status = "OK" }
}

# ==============================================================================
# 5. INTERRUPÇÃO DO PROCESSO ATIVO (CASO ESTEJA RODANDO)
# ==============================================================================
Write-Host "[*] Encerrando daemons residuais..." -ForegroundColor DarkGray

 $smartscreenProc = Get-Process -Name "smartscreen" -ErrorAction SilentlyContinue
if ($smartscreenProc) {
    Stop-Process -Name "smartscreen" -Force -ErrorAction SilentlyContinue
    $LogTweaks += [PSCustomObject]@{ Feature = "Process: smartscreen.exe"; Acao = "Processo morto"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Process: smartscreen.exe"; Acao = "Não estava em execução"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Se você baixou um arquivo recentemente e ele ainda está bloqueado (ícone com cadeado ou aviso amarelo), clique com o botão direito no arquivo -> Propriedades -> Marque 'Desbloquear' na parte inferior (General) -> Aplicar." -ForegroundColor Yellow
Write-Host "[!] Os próximos arquivos baixados não sofrerão mais essa checagem.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"