# ==============================================================================
# OTIMIZAÇÃO DE RENDERIZAÇÃO GRÁFICA E FULLSCREEN EXCLUSIVO (FSE)
# Contexto: Remoção de camadas de composição (DWM/MPO) para menor input lag.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    OTIMIZAÇÃO DE PIPELINE GRÁFICO (DWM, FSE E GAME DVR)           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO REAL DO GAME DVR VIA POLÍTICA DE GRUPO (GPO)
# Contexto: O caminho PolicyManager default é fraco. Este é o caminho oficial.
# ==============================================================================
 $GpoGameDvrPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"
if (-not (Test-Path $GpoGameDvrPath)) { New-Item -Path $GpoGameDvrPath -Force | Out-Null }

 $prop = "AppCaptureEnabled"
 $val = 0
if ((Get-ItemProperty -Path $GpoGameDvrPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $GpoGameDvrPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR (GPO Real)"; Acao = "Desativado via Política"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR (GPO Real)"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAR COMPORTAMENTO HÍBRIDO DO GAME LAYOUT (FSE Behavior)
# ==============================================================================
 $GameBarConfig = "HKCU:\System\GameConfigStore"
if (-not (Test-Path $GameBarConfig)) { New-Item -Path $GameBarConfig -Force | Out-Null }

# GameDVR_FSEBehavior = 2: Desativa a otimização de tela inteira (Força FSE puro)
 $prop = "GameDVR_FSEBehavior"
 $val = 2
if ((Get-ItemProperty -Path $GameBarConfig -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $GameBarConfig -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "FSE Behavior Mode"; Acao = "Definido para 2 (FSE Puro)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "FSE Behavior Mode"; Acao = "Já estava correto"; Status = "OK" }
}

# GameDVR_DXGIHonorFSEWindowsCompatible = 1: Força o DXGI a honrar o FSE
 $prop = "GameDVR_DXGIHonorFSEWindowsCompatible"
 $val = 1
if ((Get-ItemProperty -Path $GameBarConfig -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $GameBarConfig -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "DXGI Honor FSE"; Acao = "Ativado"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "DXGI Honor FSE"; Acao = "Já estava ativado"; Status = "OK" }
}

# ==============================================================================
# 3. CAMADA DE COMPATIBILIDADE DXG KERNEL (CORREÇÃO DE LÓGICA)
# ==============================================================================
 $DxgiPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (-not (Test-Path $DxgiPath)) { New-Item -Path $DxgiPath -Force | Out-Null }

# CORREÇÃO: AllowDirectFlip = 1 (Ativado). 
# O DirectFlip permite que a GPU pule a composição do DWM, reduzindo a latência. Desativá-lo (0) era um erro no código original.
 $prop = "AllowDirectFlip"
 $val = 1
if ((Get-ItemProperty -Path $DxgiPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $DxgiPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "AllowDirectFlip"; Acao = "Ativado (Reduz latência DWM)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "AllowDirectFlip"; Acao = "Já estava ativado"; Status = "OK" }
}

# ==============================================================================
# NOVA FEATURE: DESATIVAR MULTIPLANE OVERLAY (MPO)
# Contexto: O MPO é uma feature do Windows que cria uma camada extra de hardware (Overlay plane). 
# Em muitos drivers (especialmente NVIDIA/AMD mais antigos), isso causa micro-stutters severos.
# ==============================================================================
 $prop = "MPO"
 $val = 0
if ((Get-ItemProperty -Path $DxgiPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $DxgiPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Multiplane Overlay (MPO)"; Acao = "Desativado (Anti-Stutter)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Multiplane Overlay (MPO)"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 4. REINÍCIO SEGURO DA SHELL (EXPLORER.EXE)
# ==============================================================================
Write-Host "`nPara que as regras de comportamento de janela (FSE) façam efeito imediato, a Shell do Windows precisa ser reiniciada." -ForegroundColor Yellow
Write-Warning "AVISO: Isso fechará TODAS as janelas do Explorer (pastas abertas). Salve seu trabalho antes de prosseguir."
 $confirm = Read-Host "Deseja reiniciar o Explorer agora? (S/N)"

if ($confirm -eq 'S' -or $confirm -eq 's') {
    Write-Host "Reiniciando Explorer..." -ForegroundColor Cyan
    Stop-Process -Name explorer -Force
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    $LogTweaks += [PSCustomObject]@{ Feature = "Windows Shell (Explorer)"; Acao = "Reiniciado com sucesso"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Windows Shell (Explorer)"; Acao = "Reinício cancelado pelo usuário"; Status = "PENDENTE" }
    Write-Host "A alteração gráfica será aplicada no próximo login/reinício do sistema." -ForegroundColor DarkGray
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"