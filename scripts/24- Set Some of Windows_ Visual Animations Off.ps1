# ==============================================================================
# OTIMIZAÇÃO DE INTERFACE: DESATIVAÇÃO DE ANIMAÇÕES E AJUSTE VISUAL (WIN 11)
# Contexto: Configura o Windows para um perfil de performance desativando 
# animações de janelas/menus, mas preserva o ClearType e miniaturas para 
# manter a usabilidade e estética modernas.
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
Write-Host "       OTIMIZAÇÃO DE UI: DESATIVAÇÃO DE ANIMAÇÕES (WIN 11)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsRestart = $false

# Preparação dos caminhos
 $VisualEffectsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects"
 $DesktopPath = "HKCU:\Control Panel\Desktop"
 $AdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

if (-not (Test-Path $VisualEffectsPath)) { New-Item -Path $VisualEffectsPath -Force | Out-Null }
if (-not (Test-Path $DesktopPath)) { New-Item -Path $DesktopPath -Force | Out-Null }
if (-not (Test-Path $AdvancedPath)) { New-Item -Path $AdvancedPath -Force | Out-Null }

# ==============================================================================
# 1. PERFIL DE EFEITOS VISUAIS (CUSTOMIZADO)
# ==============================================================================
Write-Host "`n[*] Configurando perfil visual para modo customizado..." -ForegroundColor DarkGray

 $prop = "VisualFXSetting"
 $val = 3
try {
    if ((Get-ItemProperty -Path $VisualEffectsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $VisualEffectsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "VisualFXSetting"; Acao = "Definido como Customizado (3)"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "VisualFXSetting"; Acao = "Já estava em modo Customizado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "VisualFXSetting"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. EFEITOS DESATIVADOS (FOCO EM PERFORMANCE)
# ==============================================================================
Write-Host "[*] Desativando animações de interface..." -ForegroundColor DarkGray

# A. Esmaecimento do menu
 $prop = "MenuFade"
 $val = "0"
try {
    if ((Get-ItemProperty -Path $DesktopPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DesktopPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Menu Fade"; Acao = "Desativado"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Menu Fade"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Menu Fade"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# B. Máscara de preferências do usuário (Animações de Minimizar/Maximizar)
 $prop = "UserPreferencesMask"
 $targetMask = [byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)
try {
    $currentMask = (Get-ItemProperty -Path $DesktopPath -Name $prop -ErrorAction SilentlyContinue).$prop
    if (-not $currentMask -or (($currentMask -join ',') -ne ($targetMask -join ','))) {
        Set-ItemProperty -Path $DesktopPath -Name $prop -Value $targetMask -Type Binary -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UserPreferencesMask"; Acao = "Animações de janelas desativadas"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UserPreferencesMask"; Acao = "Já estava otimizado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UserPreferencesMask"; Acao = "Falha ao aplicar máscara binária"; Status = "ERRO" }
}

# C. Animações internas de controles (Taskbar/WinUI)
 $prop = "TaskbarAnimations"
 $val = 0
try {
    if ((Get-ItemProperty -Path $AdvancedPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AdvancedPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "TaskbarAnimations"; Acao = "Desativadas"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "TaskbarAnimations"; Acao = "Já estava desativada"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "TaskbarAnimations"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 3. EFEITOS PRESERVADOS (ESTÉTICA E USABILIDADE)
# ==============================================================================
Write-Host "[*] Validando presets de estética (ClearType e Miniaturas)..." -ForegroundColor DarkGray

# A. Suavização de fontes (ClearType)
 $prop = "FontSmoothing"
 $val = "2"
try {
    if ((Get-ItemProperty -Path $DesktopPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DesktopPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "FontSmoothing"; Acao = "Ativado (ClearType)"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "FontSmoothing"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "FontSmoothing"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# B. Miniaturas no Explorer
 $prop = "IconsOnly"
 $val = 0
try {
    if ((Get-ItemProperty -Path $AdvancedPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AdvancedPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "IconsOnly"; Acao = "Miniaturas garantidas"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "IconsOnly"; Acao = "Já estava correto"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "IconsOnly"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 4. REINÍCIO DO WINDOWS EXPLORER (CONDICIONAL)
# ==============================================================================
if ($needsRestart) {
    Write-Host "[*] Aplicando alterações na interface..." -ForegroundColor DarkGray
    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Reiniciado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Falha ao reiniciar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Pulado (Sem necessidade)"; Status = "OK" }
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
Write-Host "1. Animações ao abrir/minimizar janelas foram desativadas para ganho de FPS e responsividade." -ForegroundColor White
Write-Host "2. O ClearType (suavização de fontes) e as miniaturas de arquivos foram preservados." -ForegroundColor White
Write-Host "3. O Windows Explorer só foi reiniciado se alguma alteração real tiver sido feita no registro.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"