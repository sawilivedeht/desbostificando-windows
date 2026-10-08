# ==============================================================================
# DESATIVAÇÃO COMPLETA DO GAME BAR, DVR E BUFFER DE CAPTURA
# Contexto: Eliminação total de overhead de captura de vídeo e forçagem de 
# Fullscreen Exclusive (FSE) para máxima redução de Input Lag.
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
Write-Host "           DESATIVAÇÃO AVANÇADA DE GAME BAR / DVR / FSE             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. MAPEAMENTO E GARANTIA DE ESTRUTURA DAS CHAVES
# ==============================================================================
 $GameDVRPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR"
 $GameConfigStorePath = "HKCU:\System\GameConfigStore"
 $GameBarPath = "HKCU:\Software\Microsoft\GameBar"

if (-not (Test-Path $GameDVRPath)) { New-Item -Path $GameDVRPath -Force | Out-Null }
if (-not (Test-Path $GameConfigStorePath)) { New-Item -Path $GameConfigStorePath -Force | Out-Null }
if (-not (Test-Path $GameBarPath)) { New-Item -Path $GameBarPath -Force | Out-Null }

# ==============================================================================
# 2. DESATIVAÇÃO DO GAME DVR E CAPTURA EM SEGUNDO PLANO
# ==============================================================================
Write-Host "`n[*] Desativando motores de captura de vídeo..." -ForegroundColor DarkGray

# Desativa a gravação principal
 $prop = "AppCaptureEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $GameDVRPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameDVRPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: AppCapture"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: AppCapture"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: AppCapture"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa o Buffer Histórico (Libera RAM)
 $prop = "HistoricalCaptureEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $GameDVRPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameDVRPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Hist. Buffer"; Acao = "Desativado (Libera RAM)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Hist. Buffer"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Hist. Buffer"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa o monitoramento do GameDVR
 $prop = "GameDVR_Enabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $GameConfigStorePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameConfigStorePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Monitoramento"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Monitoramento"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameDVR: Monitoramento"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. FORÇAR FULLSCREEN EXCLUSIVO (FSE) PARA REDUZIR INPUT LAG
# ==============================================================================
Write-Host "[*] Configurando políticas de Renderização Gráfica (FSE)..." -ForegroundColor DarkGray

# GameDVR_FSEBehaviorMode = 2: Força o jogo a usar o modo exclusivo puro
 $prop = "GameDVR_FSEBehaviorMode"; $val = 2
try {
    if ((Get-ItemProperty -Path $GameConfigStorePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameConfigStorePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: FSE Behavior"; Acao = "Forçado (Modo 2)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: FSE Behavior"; Acao = "Já estava configurado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: FSE Behavior"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# GameDVR_DXGIHonorFSEWindowsCompatible = 1: Instrui a API gráfica a honrar o FSE
 $prop = "GameDVR_DXGIHonorFSEWindowsCompatible"; $val = 1
try {
    if ((Get-ItemProperty -Path $GameConfigStorePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameConfigStorePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: DXGI Honor FSE"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: DXGI Honor FSE"; Acao = "Já estava ativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Graphics: DXGI Honor FSE"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. DESATIVAÇÃO E LIMPEZA DA INTERFACE DA GAME BAR
# ==============================================================================
Write-Host "[*] Removendo ganchos de interface do Xbox..." -ForegroundColor DarkGray

# Bloqueia o atalho Win+G e o botão de controles
 $prop = "UseNexusForGameBarEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $GameBarPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameBarPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Atalhos (Win+G)"; Acao = "Bloqueados"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Atalhos (Win+G)"; Acao = "Já estavam bloqueados"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Atalhos (Win+G)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Oculta o painel de inicialização automática da Game Bar ao abrir jogos
 $prop = "ShowStartupPanel"; $val = 0
try {
    if ((Get-ItemProperty -Path $GameBarPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameBarPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Startup Panel"; Acao = "Oculto"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Startup Panel"; Acao = "Já estava oculto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: Startup Panel"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa o painel de "Bem-vindo" e primeiros passos do Xbox
 $prop = "FirstRunPlayed"; $val = 1
try {
    if ((Get-ItemProperty -Path $GameBarPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GameBarPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: First Run"; Acao = "Suprimido"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: First Run"; Acao = "Já estava suprimido"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GameBar: First Run"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Alguns jogos da Microsoft Store (Xbox Game Pass) podem exigir que o serviço de gravação esteja 'Ativo' para inicializar." -ForegroundColor White
Write-Host "2. Se um jogo do Game Pass recusar a abrir, reverta a chave 'GameDVR_Enabled' para 1 temporariamente.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"