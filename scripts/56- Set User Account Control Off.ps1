# ==============================================================================
# OTIMIZAÇÃO DO UAC: ELEVAÇÃO SILENCIOSA E DESATIVAÇÃO DO SECURE DESKTOP
# Contexto: Evitar o "congelamento" do Secure Desktop (tela escura) que causa 
# micro-stutters e Alt-Tab forçado quando aplicativos pedem permissão de Admin.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar as políticas do UAC."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "           REFINAMENTO DO UAC (SILENT ELEVATION / ANTI-STUTTER)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Configurar o UAC para elevar silenciosamente reduz a segurança do sistema contra malware que execute no contexto do seu usuário."

 $LogTweaks = @()
 $UacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

# Verificação de segurança: garante que a chave do registro existe antes de tentar gravar nela
if (-not (Test-Path $UacPath)) { New-Item -Path $UacPath -Force | Out-Null }

# ==============================================================================
# 1. COMPORTAMENTO DE ELEVAÇÃO (SILENT ADMIN)
# ==============================================================================
Write-Host "`n[*] Configurando comportamento de elevação..." -ForegroundColor DarkGray

# ConsentPromptBehaviorAdmin = 0: Eleva automaticamente sem pop-up para Admins
 $prop = "ConsentPromptBehaviorAdmin"
 $val = 0
if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Admin Prompt"; Acao = "Silencioso (Auto-Elevate)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Admin Prompt"; Acao = "Já estava silencioso"; Status = "OK" }
}

# ConsentPromptBehaviorUser = 0: Nega silenciosamente para usuários padrão
 $prop = "ConsentPromptBehaviorUser"
 $val = 0
if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: User Prompt"; Acao = "Negado silenciosamente"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: User Prompt"; Acao = "Já estava configurado"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO SECURE DESKTOP (O CULPADO PELO STUTTER)
# ==============================================================================
# PromptOnSecureDesktop = 0: Impede o Windows de congelar a tela e escurecer o fundo
 $prop = "PromptOnSecureDesktop"
 $val = 0
if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Secure Desktop"; Acao = "Desativado (Anti-Stutter)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Secure Desktop"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 3. O PARADOXO DO ENABLELUA (CORREÇÃO DE LÓGICA)
# ==============================================================================
# CORREÇÃO: NÃO mudamos EnableLUA para 0. Se fizermos isso, quebramos o Edge, o Menu 
# Iniciar e todos os apps UWP (Windows Store). O valor DEVE permanecer 1. 
# A "mágica" de não ter pop-up acontece pela combinação dos valores acima.
 $prop = "EnableLUA"
 $val = 1
 $currentLUA = (Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop
if ($null -eq $currentLUA -or $currentLUA -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Core (LUA)"; Acao = "Forçado para 1 (Protege Apps UWP)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Core (LUA)"; Acao = "Correto (Mantido em 1)"; Status = "OK" }
}

# ==============================================================================
# 4. DESATIVAR VIRTUALIZAÇÃO DE ARQUIVOS (UAC VIRTUALSTORE)
# Contexto: Quando um app legado tenta escrever em C:\Arquivos de Programas sem ser 
# Admin, o UAC redireciona isso para %LocalAppData%\VirtualStore. Isso cria uma 
# camada de abstração que gera I/O extra e confunde usuários. Desativar falha 
# o write de forma limpa, economizando processamento de emulação.
# ==============================================================================
Write-Host "[*] Desativando camada de emulação de arquivos..." -ForegroundColor DarkGray

 $prop = "EnableVirtualization"
 $val = 0
if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Virtualization"; Acao = "Desativada (Reduz I/O de disco)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Virtualization"; Acao = "Já estava desativada"; Status = "OK" }
}

# ==============================================================================
# 5. DESATIVAR DETECÇÃO DE INSTALADORES LEGADOS
# Contexto: O Windows verifica heuristicamente se um .exe é um instalador para 
# aplicar um ícone de escudo e exigir Admin. Desativar isso acelera a abertura 
# de executáveis antigos que não precisam de instalação.
# ==============================================================================
Write-Host "[*] Desativando heurística de instalação..." -ForegroundColor DarkGray

 $prop = "EnableInstallerDetection"
 $val = 0
if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Installer Detect"; Acao = "Desativado (Abertura rápida de .exe)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UAC: Installer Detect"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Você não será mais incomodado por pop-ups ou escurecimento de tela ao abrir apps que pedem Admin." -ForegroundColor Yellow
Write-Host "[!] No entanto, se você clicar em um arquivo malicioso que peça Admin, ele será instalado silenciosamente. Tenha certeza de que seu antivírus está ativo ou confia nos softwares que executa." -ForegroundColor Yellow
Write-Host "[!] ATENÇÃO: Alterações no UAC exigem REINICIAR o computador para surtirem efeito completamente.`n" -ForegroundColor Cyan