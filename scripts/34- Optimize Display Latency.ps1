# ==============================================================================
# OTIMIZAÇÃO DE PIPELINE GRÁFICA, DWM E RENDERIZAÇÃO DIRECTX
# Contexto: Redução máxima de Input Lag, eliminação de buffer de frames do DWM,
# ativação do Flip Model em Borderless e estabilização de Frametime.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar drivers de GPU e políticas de kernel."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        OTIMIZAÇÃO DE RENDERIZAÇÃO, HAGS E DWM PIPELINE             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. AGENDAMENTO DE GPU ACELERADO POR HARDWARE (HAGS)
# ==============================================================================
 $GraphicsDriverPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
if (-not (Test-Path $GraphicsDriverPath)) { New-Item -Path $GraphicsDriverPath -Force | Out-Null }

# HwSchMode 2 = Ativado (Transfere o gerenciamento de memória da CPU para a GPU)
 $prop = "HwSchMode"; $val = 2
try {
    if ((Get-ItemProperty -Path $GraphicsDriverPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GraphicsDriverPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: HAGS"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: HAGS"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GPU: HAGS"; Acao = "Falha ao gravar (Protegido?)"; Status = "ERRO" } }

# ==============================================================================
# 2. DESATIVAÇÃO DO MULTIPLANE OVERLAY (MPO)
# Contexto: O MPO cria planos de hardware extras. Drivers da NVIDIA/AMD têm bugs 
# no MPO que causam micro-stutters visíveis. Desativar força um pipeline único.
# ==============================================================================
 $prop = "MPO"; $val = 0
try {
    if ((Get-ItemProperty -Path $GraphicsDriverPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GraphicsDriverPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: MPO (Overlay)"; Acao = "Desativado (Anti-Stutter)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: MPO (Overlay)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GPU: MPO (Overlay)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. VRR (VARIABLE REFRESH RATE) NO DESKTOP
# Contexto: Se você tem um monitor G-Sync/FreeSync, isso faz a taxa de atualização 
# da interface do Windows descer para ~30-60fps quando ociosa, reduzindo calor e 
# latência do mouse no desktop.
# ==============================================================================
 $prop = "VariableRefreshRate_Desktop"; $val = 1
try {
    if ((Get-ItemProperty -Path $GraphicsDriverPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GraphicsDriverPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: VRR Desktop"; Acao = "Ativado (G-Sync/FreeSync Global)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "GPU: VRR Desktop"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "GPU: VRR Desktop"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. OTIMIZAÇÕES DIRECTX (FLIP MODEL EM JANELA)
# ==============================================================================
 $DxGraphicsPath = "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
if (-not (Test-Path $DxGraphicsPath)) { New-Item -Path $DxGraphicsPath -Recurse -Force | Out-Null }

# DirectXUserGlobalExtensions = 1: Força o Flip Model em jogos DX11/DX12 em Borderless/Windowed
 $prop = "DirectXUserGlobalExtensions"; $val = 1
try {
    if ((Get-ItemProperty -Path $DxGraphicsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DxGraphicsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "DX: Flip Model Global"; Acao = "Ativado (Menos Lag em Borderless)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "DX: Flip Model Global"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "DX: Flip Model Global"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 5. SUPRESSÃO DE COMPOSIÇÃO LATENTE DO DWM
# ==============================================================================
 $DwmPath = "HKCU:\Software\Microsoft\Windows\DWM"
if (-not (Test-Path $DwmPath)) { New-Item -Path $DwmPath -Force | Out-Null }

# MaxQueuedFrames = 0 (O TWEAK REAL DO DWM).
# O padrão do Windows é enfileirar 1 frame. Colocar 0 força o DWM a desenhar o frame IMEDIATAMENTE na tela, cortando 1 frame de input lag.
 $prop = "MaxQueuedFrames"; $val = 0
try {
    if ((Get-ItemProperty -Path $DwmPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DwmPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: MaxQueuedFrames"; Acao = "Definido para 0 (Zero Buffer)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: MaxQueuedFrames"; Acao = "Já estava em 0"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "DWM: MaxQueuedFrames"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa o Frame Rate Damping (Impede que o DWM limite a taxa de frames da janela ativa)
 $prop = "FrameRateDamping"; $val = 0
try {
    if ((Get-ItemProperty -Path $DwmPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DwmPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: FrameRateDamping"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "DWM: FrameRateDamping"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "DWM: FrameRateDamping"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 6. PRIORIZAÇÃO CRÍTICA DO SUBSISTEMA (CPU QUANTUM)
# ==============================================================================
 $PriorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if (-not (Test-Path $PriorityPath)) { New-Item -Path $PriorityPath -Force | Out-Null }

# Valor 26 (0x1A): Fatias de tempo Curtas e Variáveis (Ideal para Gaming roubar ciclos do background)
 $prop = "Win32PrioritySeparation"; $val = 26
try {
    if ((Get-ItemProperty -Path $PriorityPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PriorityPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Definido para 26 (Curto/Variável)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Já estava correto"; Status = "OK" }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. O HAGS e o MPO exigem que o driver de vídeo seja reinicializado." -ForegroundColor White
Write-Host "2. É altamente recomendável REINICIAR O COMPUTADOR agora para que a nova pipeline gráfica faça efeito.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"