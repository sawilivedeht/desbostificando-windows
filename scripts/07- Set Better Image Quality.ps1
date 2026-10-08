# ==============================================================================
# OTIMIZAÇÃO DE RENDERIZAÇÃO DO DESKTOP E QUALIDADE DE WALLPAPER
# Contexto: Impedir a compressão de wallpapers, reduzir a carga da GPU no Desktop 
# desativando efeitos de transparência (DWM) e animações de tela de bloqueio.
# Requer: Execução como Administrador (Para manutenção do padrão de segurança).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para manter o padrão de segurança."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      OTIMIZAÇÃO DE RENDERIZAÇÃO DESKTOP E WALLPAPER (DWM/JPEG)      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. FORÇAR QUALIDADE MÁXIMA NO IMPORTADOR JPEG DO DESKTOP
# ==============================================================================
Write-Host "`n[*] Configurando qualidade de renderização de imagens..." -ForegroundColor DarkGray

 $DesktopPath = "HKCU:\Control Panel\Desktop"
if (-not (Test-Path $DesktopPath)) { New-Item -Path $DesktopPath -Force | Out-Null }

# JPEGImportQuality 100 = Desativa a compressão com perda de dados do GDI+ ao aplicar o papel de parede
 $prop = "JPEGImportQuality"; $val = 100
try {
    if ((Get-ItemProperty -Path $DesktopPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DesktopPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Desktop: JPEG Quality"; Acao = "Forçada para 100% (Sem compressão)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Desktop: JPEG Quality"; Acao = "Já estava em 100%"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Desktop: JPEG Quality"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. DESATIVAR TRANSPARÊNCIA DO DWM (REDUZ CARGA DE GPU)
# Contexto: A transparência (Acrylic/Mica) obriga a GPU a renderizar o que está atrás 
# da janela em tempo real. Desativar isso transforma o Windows em uma interface "Flat", 
# liberando de 3% a 5% de carga da GPU, o que ajuda jogos em modo janela/borderless.
# ==============================================================================
Write-Host "[*] Configurando pipeline do Desktop Window Manager (DWM)..." -ForegroundColor DarkGray

 $DWMPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
if (-not (Test-Path $DWMPath)) { New-Item -Path $DWMPath -Force | Out-Null }

 $prop = "EnableTransparency"; $val = 0
try {
    if ((Get-ItemProperty -Path $DWMPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DWMPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: Transparência"; Acao = "Desativada (Economia de GPU)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: Transparência"; Acao = "Já estava desativada"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "DWM: Transparência"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. DESATIVAR ZOOM LENTO NA TELA DE BLOQUEIO
# Contexto: O Windows 11 aplica um efeito de "Pan and Zoom" (câmera lenta) nas 
# imagens da tela de bloqueio. Isso mantém a GPU acordada processando escalonamento 
# de imagem mesmo quando o PC está travado. Desativar reduz o consumo de energia.
# ==============================================================================
Write-Host "[*] Desativando animações de segundo plano da Lock Screen..." -ForegroundColor DarkGray

 $LockScreenPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lock Screen"
if (-not (Test-Path $LockScreenPath)) { New-Item -Path $LockScreenPath -Force | Out-Null }

 $prop = "SlideshowEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $LockScreenPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LockScreenPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow/Zoom"; Acao = "Desativado (Reduz uso de GPU)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow/Zoom"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "LockScreen: Slideshow/Zoom"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças visuais na interface..." -ForegroundColor DarkGray
    
    # MÉTODO CORRETO: O ie4uinit.exe -show avisa o subsistema de shell para recarregar
    # os papéis de parede e configurações visuais SEM destruir as janelas abertas.
    Start-Process "ie4uinit.exe" -ArgumentList "-show" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    
    # Chamada de API secundária para garantir que o DWM aplique a perda de transparência
    # Verifica se o tipo já foi carregado para evitar erro de compilação na segunda execução
    if (-not ("User32.Win32" -as [type])) {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);'
    }
    $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
    
    $LogTweaks += [PSCustomObject]@{ Feature = "Interface Visual"; Acao = "Atualizada com segurança (Sem fechar pastas)"; Status = "SUCESSO" }
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
Write-Host "1. Se o seu papel de parede atual ainda parecer borrado, isso ocorreu porque o Windows já o havia comprimido na instalação." -ForegroundColor White
Write-Host "2. Para aplicar os 100% de fato, vá em Configurações > Personalização > Plano de Fundo e selecione a imagem novamente.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"