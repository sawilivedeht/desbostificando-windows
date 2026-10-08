# ==============================================================================
# CALIBRAÇÃO DE PRECISÃO DE ENTRADA RAW (MOUSE 1:1 GAMING)
# Contexto: Remoção total de aceleração de Windows, interpolação de pixels e 
# efeitos visuais para garantir precisão cirúrgica em jogos competitivos (FPS).
# Requer: Execução como Administrador (Para consistência do pacote).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador (Padrão do pacote de otimização)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         CALIBRAÇÃO RAW INPUT (MOUSE PRECISION 1:1)                  " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DE ACELERAÇÃO E CALIBRAÇÃO LINEAR
# ==============================================================================
Write-Host "`n[*] Aplicando vetor de precisão 1:1 no registro..." -ForegroundColor DarkGray

 $MousePath = "HKCU:\Control Panel\Mouse"
if (-not (Test-Path $MousePath)) { New-Item -Path $MousePath -Force | Out-Null }

# Usando Type String pois o Painel de Controle nativo do Windows lê essas chaves como REG_SZ
 $MouseSettings = @{
    "MouseSpeed"        = "0"  # 0 = Desativa a "Precisão Aprimorada" (Aceleração)
    "MouseThreshold1"   = "0"  # Zera o limite de velocidade baixa
    "MouseThreshold2"   = "0"  # Zera o limite de velocidade alta
    "MouseSensitivity"  = "10" # 10 = Multiplicador neutro absoluto (Sem pular pixels)
}

foreach ($setting in $MouseSettings.Keys) {
    $val = $MouseSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $MousePath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $MousePath -Name $setting -Value $val -Type String -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Input: $setting"; Acao = "Definido para $val"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Input: $setting"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Input: $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. DESATIVAR RASTRO DO PONTEIRO (MOUSE TRAILS)
# ==============================================================================
Write-Host "[*] Limpando efeitos visuais de cursor..." -ForegroundColor DarkGray

 $prop = "VanishDelay"; $val = "0"
try {
    if ((Get-ItemProperty -Path $MousePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $MousePath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Mouse Trails"; Acao = "Desativado (Sem Ghosting)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Mouse Trails"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Mouse Trails"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 3. DESATIVAR SNAP-TO DEFAULT BUTTON
# ==============================================================================
 $prop = "SnapToDefaultButton"; $val = "0"
try {
    if ((Get-ItemProperty -Path $MousePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $MousePath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Snap-To Button"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Snap-To Button"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Snap-To Button"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 4. APLICAÇÃO INSTÂNTANEA VIA API WIN32 (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsApply = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsApply) {
    Write-Host "`n[*] Injetando configurações na memória do sistema (Win32 API)..." -ForegroundColor DarkGray
    
    try {
        # Em vez de matar o Explorer, usamos a API nativa do Windows (user32.dll)
        # SystemParametersInfo com a flag SPI_SETMOUSE (0x0004) avisa o driver de input
        # para recarregar as configurações imediatamente na memória RAM (0ms de latência).
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, int[] pvParam, uint fWinIni);' -ErrorAction Stop
        
        # Passa o array exato [MouseSpeed, Threshold1, Threshold2]
        $mouseParams = @(0, 0, 0)
        $null = [User32.Win32]::SystemParametersInfo(0x0004, 0, $mouseParams, 0x0001)
        
        $LogTweaks += [PSCustomObject]@{ Feature = "Driver de Input"; Acao = "Recarregado via API (Instantâneo)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Driver de Input"; Acao = "Falha ao chamar API"; Status = "ERRO" }
    }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] REGRAS DE OURO PARA JOGADORES FPS:" -ForegroundColor Yellow
Write-Host "1. O Windows agora está em modo 1:1. NÃO use mais a sensibilidade do Windows." -ForegroundColor White
Write-Host "2. Ajuste o DPI no SOFTWARE do seu mouse (Logitech G Hub, Razer Synapse, etc)." -ForegroundColor White
Write-Host "3. Dentro do jogo, use a sensibilidade BAIXA (ex: 400 a 800 eDPI) e dependa do braço." -ForegroundColor White
Write-Host "4. Desative qualquer 'Aceleração' dentro do software do seu mouse também.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"