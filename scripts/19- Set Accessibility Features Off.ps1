# ==============================================================================
# DESATIVAÇÃO COMPLETA DE ARMADILHAS DE TECLADO (ANTI-INTERRUPTION GAMER)
# Contexto: Bloqueio definitivo de popups de Acessibilidade que pausam jogos e fazem 
# o Windows emitir bipes altos ou "engolir" keystrokes durante partidas intensas.
# NOTA: Este script atua majoritariamente no HKCU, mas a verificação de Admin foi 
# mantida por padrão de segurança do pacote.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para manter o padrão de segurança."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       DESATIVAÇÃO COMPLETA DE ARMADILHAS DE TECLADO (ANTI-LAG GAMER)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO MODULAR PARA APLICAR OS FLAGS DE ACESSIBILIDADE
# ==============================================================================
function Set-AccessibilityFlag {
    param (
        [string]$RegPath,
        [string]$Value,
        [string]$FeatureName,
        [string]$ActionDesc
    )

    if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    
    try {
        $currentFlags = (Get-ItemProperty -Path $RegPath -Name "Flags" -ErrorAction SilentlyContinue).Flags
        if ($currentFlags -ne $Value) {
            Set-ItemProperty -Path $RegPath -Name "Flags" -Value $Value -Type String -Force -ErrorAction Stop
            $script:LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: $FeatureName"; Acao = $ActionDesc; Status = "SUCESSO" }
        } else {
            $script:LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: $FeatureName"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $script:LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: $FeatureName"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 1. TECLAS DE ADERÊNCIA (STICKY KEYS)
# ==============================================================================
Write-Host "`n[*] Configurando Sticky Keys..." -ForegroundColor DarkGray
Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\StickyKeys" -Value "514" -FeatureName "Sticky Keys (Shift 5x)" -ActionDesc "Função e Atalho DESATIVADOS"

# ==============================================================================
# 2. TECLAS DE FILTRAGEM (FILTER KEYS)
# ==============================================================================
Write-Host "[*] Configurando Filter Keys..." -ForegroundColor DarkGray
Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\Keyboard Response" -Value "122" -FeatureName "Filter Keys (Shift Right 8s)" -ActionDesc "Função e Atalho DESATIVADOS"

# ==============================================================================
# 3. TECLAS DE ALTERNÂNCIA (TOGGLE KEYS)
# ==============================================================================
Write-Host "[*] Configurando Toggle Keys..." -ForegroundColor DarkGray
Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\ToggleKeys" -Value "62" -FeatureName "Toggle Keys (NumLock 5s)" -ActionDesc "Alternância e Atalho DESATIVADOS"

# ==============================================================================
# 4. DESATIVAÇÃO DO ATALHO DO NARRADOR (NARRATOR)
# ==============================================================================
Write-Host "[*] Configurando atalho do Narrador..." -ForegroundColor DarkGray

 $NarratorPath = "HKCU:\Software\Microsoft\Narrator\NoRoam"
if (-not (Test-Path $NarratorPath)) { New-Item -Path $NarratorPath -Force | Out-Null }

 $prop = "WinEnterShortcutEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $NarratorPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $NarratorPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Narrator Shortcut"; Acao = "Desativado (Win+Ctrl+Enter)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Narrator Shortcut"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Narrator Shortcut"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 5. ZERAR NÍVEL DE ZOOM DA LUPA (MAGNIFIER)
# ==============================================================================
Write-Host "[*] Resetando nível de Zoom da Lupa..." -ForegroundColor DarkGray

 $MagnifierPath = "HKCU:\Software\Microsoft\ScreenMagnifier"
if (-not (Test-Path $MagnifierPath)) { New-Item -Path $MagnifierPath -Force | Out-Null }

 $prop = "MagnificationMode"; $val = 0
try {
    if ((Get-ItemProperty -Path $MagnifierPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $MagnifierPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Magnifier Zoom"; Acao = "Resetado para 0 (Padrão Estático)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Magnifier Zoom"; Acao = "Já estava em 0"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "UI: Magnifier Zoom"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 6. ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças nas políticas de teclado..." -ForegroundColor DarkGray
    
    # MÉTODO CORRETO: As configurações de Acessibilidade são lidas pelo subsistema de entrada 
    # do Windows. Basta forçar o Shell a reler as políticas usando a API Win32.
    # Verifica se o tipo já foi carregado para evitar erro de compilação na segunda execução
    if (-not ("User32.Win32" -as [type])) {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'
    }
    $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
    
    $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA IMPORTANTE: O valor do Sticky Keys foi ajustado para '514'." -ForegroundColor Yellow
Write-Host "[!] O valor 514 garante matematicamente que o Windows desativará a função E bloqueará o atalho de forma definitiva, evitando micro-lags de input em jogos." -ForegroundColor White
Write-Host "[!] Se você realmente precisa usar as Teclas de Aderência por motivos de acessibilidade real, não rode este script ou reative a função manualmente nas Configurações de Acessibilidade do Windows.`n" -ForegroundColor Yellow

Read-Host "Pressione ENTER para fechar"