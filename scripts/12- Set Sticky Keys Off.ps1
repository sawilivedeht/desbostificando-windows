# ==============================================================================
# DESATIVAÇÃO COMPLETA DE ATALHOS DE ACESSIBILIDADE (ANTI-INTERRUPTION GAMER)
# Contexto: Bloqueio definitivo dos popups que pausam jogos (Sticky, Filter e Toggle Keys)
# que são acionados acidentalmente ao pressionar modificadores repetidas vezes.
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      DESATIVAÇÃO DE ATALHOS DE ACESSIBILIDADE (ANTI-LAG GAMER)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO MODULAR PARA APLICAR OS FLAGS DE ACESSIBILIDADE
# Os "Flags" no registro de Acessibilidade são strings legadas que combinam 
# estados binários (Ex: 506 = 2[Desligado] + 4[Desativar atalho] + 500[Aplicar])
# ==============================================================================
function Set-AccessibilityFlag {
    param (
        [string]$RegPath,
        [string]$Value
    )

    if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    
    try {
        $currentFlags = (Get-ItemProperty -Path $RegPath -Name "Flags" -ErrorAction SilentlyContinue).Flags
        
        if ($currentFlags -ne $Value) {
            Set-ItemProperty -Path $RegPath -Name "Flags" -Value $Value -Type String -Force -ErrorAction Stop
            return "SUCESSO"
        }
        return "OK"
    } catch {
        return "ERRO"
    }
}

# ==============================================================================
# 1. TECLAS DE ADERÊNCIA (STICKY KEYS)
# Contexto: Popup que aparece ao pressionar Shift 5 vezes.
# 506 = Desliga a função e remove o atalho.
# ==============================================================================
Write-Host "`n[*] Configurando Sticky Keys..." -ForegroundColor DarkGray
 $status = Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\StickyKeys" -Value "506"
 $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Sticky Keys (Shift 5x)"; Acao = "Desativado e Bloqueado"; Status = $status }

# ==============================================================================
# 2. TECLAS DE FILTRAGEM (FILTER KEYS)
# Contexto: Popup que silencia o teclado ao segurar Shift direito por 8 segundos.
# 122 = Desliga a função de ignorar keystrokes curtos e remove o atalho.
# IMPORTANTE: Se isso estiver ativado por engano, o seu mouse ou teclado "para de responder" no jogo.
# ==============================================================================
Write-Host "[*] Configurando Filter Keys..." -ForegroundColor DarkGray
 $status = Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\Keyboard Response" -Value "122"
 $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Filter Keys (Shift Right 8s)"; Acao = "Desativado e Bloqueado"; Status = $status }

# ==============================================================================
# 3. TECLAS DE ALTERNÂNCIA (TOGGLE KEYS)
# Contexto: Emite um Bipe forte e ativa/desativa o NumLock ao segurar a tecla por 5 segundos.
# 62 = Desliga a alternância forçada e remove o atalho.
# ==============================================================================
Write-Host "[*] Configurando Toggle Keys..." -ForegroundColor DarkGray
 $status = Set-AccessibilityFlag -RegPath "HKCU:\Control Panel\Accessibility\ToggleKeys" -Value "62"
 $LogTweaks += [PSCustomObject]@{ Feature = "Acessibilidade: Toggle Keys (NumLock 5s)"; Acao = "Desativado e Bloqueado"; Status = $status }


# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Estas configurações são aplicadas instantaneamente na memória do Windows. Não é necessário reiniciar o PC ou fechar jogos abertos, a proteção já está ativa." -ForegroundColor Yellow
Write-Host "[!] Se você realmente precisa usar a Tecla de Aderência por motivos de acessibilidade real, não rode este script ou reative a função manualmente nas Configurações de Acessibilidade do Windows.`n" -ForegroundColor White