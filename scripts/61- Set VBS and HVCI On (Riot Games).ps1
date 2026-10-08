# ==============================================================================
# ASSISTENTE DE PREPARAÇÃO: RIOT VANGUARD ANTI-CHEAT (VBS / HVCI / SECURE BOOT)
# Contexto: O Vanguard opera no Kernel (Ring 0) e exige uma cadeia de confiança 
# de hardware e software intacta. Este script reativa o VBS/HVCI e audita a BIOS.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar o Device Guard."
    exit
}

Write-Host "======================================================================" -ForegroundColor Red
Write-Host "       ASSISTENTE DE PRÉ-REQUISITOS: RIOT VANGUARD ANTI-CHEAT          " -ForegroundColor Red
Write-Host "======================================================================" -ForegroundColor Red
Write-Warning "AVISO: Reativar o VBS/HVCI reduzirá levemente o FPS e aumentará a latência DPC."
Write-Host "Isso é OBRIGATÓRIO para jogar Valorant/League of Legends, mas afeta a performance." -ForegroundColor Yellow

 $LogTweaks = @()

# ==============================================================================
# 1. REATIVAÇÃO DO VBS E HVCI NO REGISTRO (COM VALIDAÇÃO)
# ==============================================================================
Write-Host "`n[*] Verificando estado do Device Guard..." -ForegroundColor DarkGray

 $VbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
 $HvciPath = "$VbsPath\Scenarios\HypervisorEnforcedCodeIntegrity"

if (-not (Test-Path $VbsPath)) { New-Item -Path $VbsPath -Force | Out-Null }
if (-not (Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }

# Reativa o VBS (EnableVirtualizationBasedSecurity = 1)
 $prop = "EnableVirtualizationBasedSecurity"; $val = 1
try {
    if ((Get-ItemProperty -Path $VbsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $VbsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Core Engine"; Acao = "Reativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Core Engine"; Acao = "Já estava ativo"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Core Engine"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# Reativa o HVCI / Memory Integrity (Enabled = 1)
 $prop = "Enabled"; $val = 1
try {
    if ((Get-ItemProperty -Path $HvciPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $HvciPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Memory Integrity (HVCI)"; Acao = "Reativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Memory Integrity (HVCI)"; Acao = "Já estava ativo"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "VBS: Memory Integrity (HVCI)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. AUDITORIA DO SECURE BOOT (REQUISITO VITAL DO VANGUARD)
# ==============================================================================
Write-Host "[*] Auditando Secure Boot da UEFI..." -ForegroundColor DarkGray

try {
    $SecureBootEnabled = Confirm-SecureBootUEFI -ErrorAction Stop
    
    if ($SecureBootEnabled) {
        $LogTweaks += [PSCustomObject]@{ Feature = "Firmware: Secure Boot"; Acao = "ATIVO (OK para Vanguard)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Firmware: Secure Boot"; Acao = "DESATIVADO (Requer BIOS)"; Status = "ERRO" }
    }
} catch {
    # Ocorre em PCs mais antigos (BIOS Legado) que não suportam a API do Windows
    $LogTweaks += [PSCustomObject]@{ Feature = "Firmware: Secure Boot"; Acao = "Não suportado ou Inacessível"; Status = "AVISO" }
}

# ==============================================================================
# 3. VERIFICAÇÃO DE VIRTUALIZAÇÃO NO WINDOWS
# ==============================================================================
Write-Host "[*] Verificando módulo de Virtualização do Windows..." -ForegroundColor DarkGray

# ADIÇÃO: Parâmetro -Online é obrigatório em instalações nativas do Windows 10/11
 $HyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V-All" -ErrorAction SilentlyContinue
if ($HyperVFeature -and $HyperVFeature.State -eq "Enabled") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Windows: Hyper-V Feature"; Acao = "Instalado (OK para VBS)"; Status = "OK" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Windows: Hyper-V Feature"; Acao = "Desinstalado (Pode impedir VBS)"; Status = "AVISO" }
}

# ==============================================================================
# 4. VALIDAÇÃO DOS SERVIÇOS DO VANGUARD
# ==============================================================================
Write-Host "[*] Verificando integridade dos serviços do Riot Vanguard..." -ForegroundColor DarkGray

 $VanguardServices = @("vgc")
foreach ($SvcName in $VanguardServices) {
    $service = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
    
    if ($service) {
        if ($service.StartType -eq 'Disabled') {
            try {
                Set-Service -Name $SvcName -StartupType Automatic -ErrorAction Stop
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Riot Vanguard ($SvcName)"; Acao = "Reativado (Estava Desativado)"; Status = "SUCESSO" }
            } catch {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Riot Vanguard ($SvcName)"; Acao = "Falha ao reativar"; Status = "ERRO" }
            }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Riot Vanguard ($SvcName)"; Acao = "OK (Permitido)"; Status = "OK" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Riot Vanguard ($SvcName)"; Acao = "Não encontrado (Jogo não instalado?)"; Status = "INFO" }
    }
}

# ==============================================================================
# RESULTADO FINAL E INSTRUÇÕES DE BIOS
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

# Instruções baseadas no resultado do Secure Boot
 $SecureBootFailed = $LogTweaks | Where-Object { $_.Feature -match "Secure Boot" -and $_.Status -ne "SUCESSO" }

Write-Host "`n======================================================================" -ForegroundColor Red
Write-Host "                    PRÓXIMOS PASSOS OBRIGATÓRIOS                      " -ForegroundColor Red
Write-Host "======================================================================" -ForegroundColor Red

if ($SecureBootFailed) {
    Write-Host "[!] FALHA CRÍTICA: O Secure Boot está DESATIVADO." -ForegroundColor Yellow
    Write-Host "O Riot Vanguard NÃO IRÁ FUNCIONAR até você ligar o Secure Boot." -ForegroundColor White
    Write-Host "Como ligar:" -ForegroundColor Cyan
    Write-Host "1. Reinicie o PC e pressione F2, F12, DEL ou F8 (depende da sua placa-mãe) para entrar na BIOS/UEFI." -ForegroundColor White
    Write-Host "2. Vá em 'Security' ou 'Boot'." -ForegroundColor White
    Write-Host "3. Altere 'Secure Boot' para 'Enabled'." -ForegroundColor White
    Write-Host "4. Salve e saia (F10)." -ForegroundColor White
} else {
    Write-Host "[+] O Secure Boot está ATIVO. Excelente." -ForegroundColor Green
}

Write-Host "`n[!] AVISO SOBRE DRIVERS: Ao ligar o HVCI (Memory Integrity), seu PC recusará rodar drivers antigos sem assinatura digital válida." -ForegroundColor Yellow
Write-Host "Se você tiver placa de som de 10 anos, ou mouse/teclado genérico, o PC pode dar TELA AZUL ao reiniciar." -ForegroundColor Yellow
Write-Host "Se isso acontecer, reinicie em 'Modo Seguro' e desative o HVCI novamente." -ForegroundColor Yellow

Write-Host "`n[*] REINICIE O COMPUTADOR AGORA para que o Contêiner VBS seja reconstruído na memória e o Vanguard passe a funcionar.`n" -ForegroundColor Cyan