# ==============================================================================
# BYPASS COMPLETO DE REQUISITOS DO WINDOWS 11 (INSTALLER & WINDOWS UPDATE)
# Contexto: Permite a instalação/atualização do Win 11 em hardwares não suportados 
# oficialmente (Falta de TPM 2.0, CPUs antigas, Secure Boot desligado).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar chaves do Sistema (HKLM\SYSTEM)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        BYPASS DE REQUISITOS DE HARDWARE DO WINDOWS 11               " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Instalar o Windows 11 fora dos requisitos oficiais pode impedir que você receba futuras atualizações de segurança da Microsoft."

 $LogTweaks = @()

# ==============================================================================
# 1. BYPASS DO INSTALADOR (LABCONFIG - SETUP.EXE VIA USB/ISO)
# ==============================================================================
Write-Host "`n[*] Configurando bypass para o Instalador (Setup.exe)..." -ForegroundColor DarkGray

 $SetupPath = "HKLM:\SYSTEM\Setup\LabConfig"
if (-not (Test-Path $SetupPath)) { 
    New-Item -Path $SetupPath -Force | Out-Null 
}

 $LabConfigKeys = @{
    "BypassTPMCheck"        = 1
    "BypassSecureBootCheck" = 1
    "BypassCPUCheck"        = 1
    "BypassRAMCheck"        = 1
    "BypassStorageCheck"    = 1
}

foreach ($key in $LabConfigKeys.Keys) {
    $val = $LabConfigKeys[$key]
    try {
        if ((Get-ItemProperty -Path $SetupPath -Name $key -ErrorAction SilentlyContinue).$key -ne $val) {
            Set-ItemProperty -Path $SetupPath -Name $key -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Setup: $key"; Acao = "Ativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Setup: $key"; Acao = "Já estava ativado"; Status = "OK" }
        }
    } catch { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Setup: $key"; Acao = "Falha ao gravar"; Status = "ERRO" } 
    }
}

# ==============================================================================
# 2. BYPASS DO WINDOWS UPDATE (ATUALIZAÇÃO DIRETA PELA REDE)
# Contexto: Engana o serviço Windows Update para que ele ofereça o Windows 11 
# mesmo consultando os servidores da Microsoft, sem precisar de um pen drive.
# ==============================================================================
Write-Host "[*] Configurando bypass para o Windows Update..." -ForegroundColor DarkGray

 $WUPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators"
if (-not (Test-Path $WUPath)) { New-Item -Path $WUPath -Force | Out-Null }

 $prop = "REDSTONE"; $val = "Disabled"
try {
    if ((Get-ItemProperty -Path $WUPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $WUPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "WU: Upgrade Blocker"; Acao = "Removido (Oferecerá Win11 via Update)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "WU: Upgrade Blocker"; Acao = "Já estava removido"; Status = "OK" }
    }
} catch { 
    $LogTweaks += [PSCustomObject]@{ Feature = "WU: Upgrade Blocker"; Acao = "Falha ao gravar"; Status = "ERRO" } 
}

# ==============================================================================
# 3. DESATIVAR BLOQUEIO DE DRIVERS VULNERÁVEIS (VULNERABLE DRIVER BLOCKLIST)
# Contexto: O Windows 11 recusa-se a instalar se detectar drivers antigos na lista 
# de bloqueio da Microsoft (comum em placas mãe antigas). Desativar isso permite 
# que o instalador prossiga sem abortar a tela azul.
# ==============================================================================
Write-Host "[*] Desativando blocklist de drivers incompatíveis..." -ForegroundColor DarkGray

 $DriverBlockPath = "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Config"
if (-not (Test-Path $DriverBlockPath)) { New-Item -Path $DriverBlockPath -Force | Out-Null }

 $prop = "VulnerableDriverBlocklistEnable"; $val = 0
try {
    if ((Get-ItemProperty -Path $DriverBlockPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DriverBlockPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Security: Driver Blocklist"; Acao = "Desativada (Permite drivers antigos)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Security: Driver Blocklist"; Acao = "Já estava desativada"; Status = "OK" }
    }
} catch { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Security: Driver Blocklist"; Acao = "Falha ao gravar"; Status = "ERRO" } 
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] PRÓXIMOS PASSOS:" -ForegroundColor Yellow
Write-Host "1. Agora você pode iniciar a atualização diretamente pelo 'Windows Update' (Buscando atualizações), ou rodar o setup.exe pelo pendrive." -ForegroundColor White
Write-Host "2. O instalador ainda pode mostrar um pequeno aviso amarelo dizendo que o PC não é compatível, mas o botão 'Avançar/Continuar' estará desbloqueado." -ForegroundColor White
Write-Host "3. Após instalar o Windows 11, é normal aparecer uma marca d'água 'Requisitos do Windows não atendidos' na área de trabalho. Isso é apenas estético e não afeta o desempenho.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"