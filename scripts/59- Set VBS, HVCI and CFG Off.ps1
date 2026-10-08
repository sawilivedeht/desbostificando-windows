# ==============================================================================
# OTIMIZAÇÃO EXTREMA DE DESEMPENHO (DESATIVAÇÃO DE VBS / MITIGAÇÕES)
# Contexto: Foco em redução de latência e aumento de FPS para Jogos/Esports.
# Requer: Execução como Administrador e REINICIALIZAÇÃO DO SISTEMA após a execução.
# ==============================================================================

# 1. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar o registro."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        OTIMIZAÇÃO DE DESEMPENHO: VBS, HVCI E MITIGAÇÕES            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar estes recursos reduz a segurança do sistema contra ataques de Kernel. Use por sua conta e risco."

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAR SEGURANÇA BASEADA EM VIRTUALIZAÇÃO (VBS)
# ==============================================================================
Write-Host "`n[*] Configurando VBS..." -ForegroundColor DarkGray
 $VbsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
 $VbsName = "EnableVirtualizationBasedSecurity"

if (-not (Test-Path $VbsPath)) { New-Item -Path $VbsPath -Force | Out-Null }

try {
    $currentVBS = (Get-ItemProperty -Path $VbsPath -Name $VbsName -ErrorAction SilentlyContinue).$VbsName
    if ($currentVBS -ne 0) {
        Set-ItemProperty -Path $VbsPath -Name $VbsName -Value 0 -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Virtualization Based Security)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Virtualization Based Security)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Virtualization Based Security)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAR INTEGRIDADE DE MEMÓRIA (HVCI / MEMORY INTEGRITY)
# ==============================================================================
Write-Host "[*] Configurando HVCI..." -ForegroundColor DarkGray
 $HvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
 $HvciName = "Enabled"

if (-not (Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }

try {
    $currentHVCI = (Get-ItemProperty -Path $HvciPath -Name $HvciName -ErrorAction SilentlyContinue).$HvciName
    if ($currentHVCI -ne 0) {
        Set-ItemProperty -Path $HvciPath -Name $HvciName -Value 0 -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 3. ATENUAR PROTEÇÃO DE FLUXO DE CONTROLE (CFG - CONTROL FLOW GUARD)
# ==============================================================================
Write-Host "[*] Configurando CFG..." -ForegroundColor DarkGray
 $CfgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
 $CfgName = "MitigationOptions"
 $ExpectedCfgBytes = [byte[]](0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)

if (-not (Test-Path $CfgPath)) { New-Item -Path $CfgPath -Force | Out-Null }

try {
    $currentCFG = (Get-ItemProperty -Path $CfgPath -Name $CfgName -ErrorAction SilentlyContinue).$CfgName
    $needsUpdate = $false
    
    # Lógica limpa de comparação de arrays de bytes
    if ($null -eq $currentCFG) {
        $needsUpdate = $true
    } elseif ((Compare-Object $currentCFG $ExpectedCfgBytes -SyncWindow 0).Count -gt 0) {
        $needsUpdate = $true
    }

    if ($needsUpdate) {
        Set-ItemProperty -Path $CfgPath -Name $CfgName -Value $ExpectedCfgBytes -Type Binary -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "CFG (Control Flow Guard)"; Acao = "Atenuado (Zerado)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "CFG (Control Flow Guard)"; Acao = "Já estava atenuado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "CFG (Control Flow Guard)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 4. ATIVAR HAGS (HARDWARE-ACCELERATED GPU SCHEDULING)
# Contexto: Permite que a placa de vídeo gerencie sua própria memória, reduzindo latência.
# ==============================================================================
Write-Host "[*] Configurando HAGS..." -ForegroundColor DarkGray
 $HagsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
 $HagsName = "HwSchMode"
 $HagsValue = 2 # 2 = Ativado, 1 = Desativado

if (-not (Test-Path $HagsPath)) { New-Item -Path $HagsPath -Force | Out-Null }

try {
    $currentHAGS = (Get-ItemProperty -Path $HagsPath -Name $HagsName -ErrorAction SilentlyContinue).$HagsName
    if ($currentHAGS -ne $HagsValue) {
        Set-ItemProperty -Path $HagsPath -Name $HagsName -Value $HagsValue -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "HAGS (GPU Scheduling)"; Acao = "Ativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "HAGS (GPU Scheduling)"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "HAGS (GPU Scheduling)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 5. DESATIVAR XBOX GAME DVR (Captura de tela em segundo plano)
# Contexto: O GameDVR consome recursos da CPU/GPU em segundo plano mesmo com jogos da Steam.
# ==============================================================================
Write-Host "[*] Configurando Xbox GameDVR..." -ForegroundColor DarkGray
 $DvrPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR"
 $DvrName = "AppCaptureEnabled"

if (-not (Test-Path $DvrPath)) { New-Item -Path $DvrPath -Force | Out-Null }

try {
    $currentDVR = (Get-ItemProperty -Path $DvrPath -Name $DvrName -ErrorAction SilentlyContinue).$DvrName
    if ($currentDVR -ne 0) {
        Set-ItemProperty -Path $DvrPath -Name $DvrName -Value 0 -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Xbox GameDVR"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Xbox GameDVR"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Xbox GameDVR"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] ATENÇÃO: As alterações de VBS e HVCI SÓ TERÃO EFEITO APÓS REINICIAR O COMPUTADOR.`n" -ForegroundColor Yellow