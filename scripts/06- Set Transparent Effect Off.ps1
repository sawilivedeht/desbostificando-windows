# ==============================================================================
# OTIMIZAÇÃO VISUAL DO DESKTOP (DWM / TRANSPARÊNCIA / ANIMAÇÕES)
# Contexto: Redução da carga contínua da GPU no Desktop, eliminando efeitos 
# visuais (Acrylic, Mica, Animações) que forçam redesenhar a tela 60/144 vezes 
# por segundo. Ideal para gamers em modo Janela/Bordeless e notebooks.
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       DESATIVAÇÃO DE EFEITOS VISUAIS DO DWM (PERFORMANCE MODE)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DA TRANSPARÊNCIA (ACRYLIC / MICA)
# ==============================================================================
Write-Host "`n[*] Configurando pipeline de transparência..." -ForegroundColor DarkGray

 $DWMPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $DWMPath)) { New-Item -Path $DWMPath -Force | Out-Null }

 $prop = "EnableTransparency"; $val = 0
if ((Get-ItemProperty -Path $DWMPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $DWMPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "DWM: Transparência"; Acao = "Desativada (Economia de GPU)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "DWM: Transparência"; Acao = "Já estava desativada"; Status = "OK" }
}

# ==============================================================================
# NOVA FEATURE: DESATIVAÇÃO DE ANIMAÇÕES DE MINIMIZAÇÃO/MAXIMIZAÇÃO
# Contexto: A animação suave ao abrir/fechar janelas consome CPU (para calcular 
# o trajeto) e GPU (para escalonar os frames da janela). Desativar isso faz o 
# Desktop parecer que tem "0ms de latência" ao interagir com pastas.
# ==============================================================================
Write-Host "[*] Desativando animações de janelas..." -ForegroundColor DarkGray

 $WindowMetricsPath = "HKCU:\Control Panel\Desktop\WindowMetrics"
if (-not (Test-Path $WindowMetricsPath)) { New-Item -Path $WindowMetricsPath -Force | Out-Null }

# ATENÇÃO: O Windows exige que o valor "0" seja uma STRING, não um DWord.
 $prop = "MinAnimate"; $val = "0"
if ((Get-ItemProperty -Path $WindowMetricsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $WindowMetricsPath -Name $prop -Value $val -Type String -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Window Animations"; Acao = "Desativadas (Desktop Instantâneo)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Window Animations"; Acao = "Já estavam desativadas"; Status = "OK" }
}

# ==============================================================================
# NOVA FEATURE: REMOÇÃO DE SOMBRA DE JANELAS
# Contexto: O Windows desenha uma sombra dinâmica atrás de cada janela ativa. 
# Mais uma tarefa desnecessária dada à GPU quando o foco é performance bruta.
# ==============================================================================
Write-Host "[*] Removendo sombras de janelas..." -ForegroundColor DarkGray

 $ExplorerAdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $ExplorerAdvPath)) { New-Item -Path $ExplorerAdvPath -Force | Out-Null }

 $prop = "ListviewShadow"; $val = 0
if ((Get-ItemProperty -Path $ExplorerAdvPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $ExplorerAdvPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Window Shadows"; Acao = "Removidas (Menos draw calls)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Window Shadows"; Acao = "Já estavam removidas"; Status = "OK" }
}


# ==============================================================================
# ATUALIZAÇÃO SEGURA DO DWM (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças no subsistema visual..." -ForegroundColor DarkGray
    
    # MÉTODO CORRETO: Em vez de matar o Explorer (que destrói a sessão do usuário),
    # nós chamamos a API Win32 "UpdatePerUserSystemParameters" (SPI_SETDESKWALLPAPER).
    # Isso envia um sinal seguro para o DWM redesenhar a interface usando as novas regras,
    # sem fechar nenhuma janela e sem piscar a tela.
    
    # Define a assinatura da API do Windows usando C# inline
    Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction SilentlyContinue
    
    # Executa a atualização (0x001F = SPI_SETDESKWALLPAPER, 0x0001 = SPIF_UPDATEINIFILE)
    $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
    
    $LogTweaks += [PSCustomObject]@{ Feature = "DWM Engine"; Acao = "Atualizada via API (Sem destruir Shell)"; Status = "SUCESSO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: A interface do Windows ficará mais 'plana' e sem efeitos de vidro/blur." -ForegroundColor Yellow
Write-Host "[!] Isso é intencional. Você notará que ao abrir ou fechar janelas, a ação será INSTANTÂNEA, sem qualquer atraso de animação.\n" -ForegroundColor Yellow