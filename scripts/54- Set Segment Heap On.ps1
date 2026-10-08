# ==============================================================================
# OTIMIZAÇÃO DE ALOCAÇÃO DE MEMÓRIA E PREVENÇÃO DE STUTTERS VIA IFEO
# Contexto: Uso correto do Segment Heap para apps Electron/Chromium e 
# desativação do WER para evitar travamentos de disco (I/O Stutters).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar o IFEO."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       OTIMIZAÇÃO AVANÇADA DE MEMÓRIA (IFEO / SEGMENT HEAP)         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $IfeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
 $LogTweaks = @()

# ==============================================================================
# 1. SEGMENT HEAP (APLICADO CORRETAMENTE EM APPS ELECTRON/CHROMIUM)
# Contexto: Reduz o overhead de memória em apps que abrem múltiplas abas/janelas.
# ==============================================================================
Write-Host "`n[*] Aplicando Segment Heap para aplicativos pesados baseados em Chromium..." -ForegroundColor DarkGray

 $ChromiumApps = @(
    "Discord.exe",
    "Spotify.exe",
    "Teams.exe",
    "Slack.exe"
)

foreach ($App in $ChromiumApps) {
    $AppPath = "$IfeoPath\$App"
    if (-not (Test-Path $AppPath)) { New-Item -Path $AppPath -Force | Out-Null }

    $prop = "UseSegmentHeap"
    $val = 2
    if ((Get-ItemProperty -Path $AppPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AppPath -Name $prop -Value $val -Type DWord -Force
        $LogTweaks += [PSCustomObject]@{ Feature = "Segment Heap: $App"; Acao = "Ativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Segment Heap: $App"; Acao = "Já estava ativado"; Status = "OK" }
    }
}

# ==============================================================================
# 2. DESATIVAR WER (WINDOWS ERROR REPORTING) PARA APPS CRÍTICOS
# Contexto: Evita que o sistema congele para gravar arquivos de despejo de memória
# (.dmp) em caso de falhas menores da interface ou de clientes de jogos.
# Usamos a GlobalFlag 0x200 (FLG_DISABLE_EXCEPTION_LOGGING)
# ==============================================================================
Write-Host "`n[*] Desativando Windows Error Reporting (WER) para evitar I/O Stutters..." -ForegroundColor DarkGray

 $CriticalApps = @(
    "explorer.exe",
    "SearchHost.exe",
    "Steam.exe",
    "EpicGamesLauncher.exe",
    "Battle.net.exe"
)

foreach ($App in $CriticalApps) {
    $AppPath = "$IfeoPath\$App"
    if (-not (Test-Path $AppPath)) { New-Item -Path $AppPath -Force | Out-Null }

    $prop = "GlobalFlag"
    $currentFlag = (Get-ItemProperty -Path $AppPath -Name $prop -ErrorAction SilentlyContinue).$prop
    $targetFlag = 0x200 # FLG_DISABLE_EXCEPTION_LOGGING

    # Lógica de Bitwise OR: Se a chave já tiver outras flags (ex: 0x100), somamos sem apagar (0x100 -bor 0x200 = 0x300)
    # Se for nula, apenas definimos 0x200.
    if ($null -eq $currentFlag) {
        Set-ItemProperty -Path $AppPath -Name $prop -Value $targetFlag -Type DWord -Force
        $LogTweaks += [PSCustomObject]@{ Feature = "Disable WER: $App"; Acao = "Flag 0x200 injetada"; Status = "SUCESSO" }
    } 
    elseif (($currentFlag -band $targetFlag) -ne $targetFlag) {
        $newFlag = $currentFlag -bor $targetFlag
        Set-ItemProperty -Path $AppPath -Name $prop -Value $newFlag -Type DWord -Force
        $LogTweaks += [PSCustomObject]@{ Feature = "Disable WER: $App"; Acao = "Flag 0x200 adicionada (Valor: $('0x{0:X}' -f $newFlag))"; Status = "SUCESSO" }
    } 
    else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Disable WER: $App"; Acao = "Já estava configurado"; Status = "OK" }
    }
}

# ==============================================================================
# 3. LIMPEZA: REMOVER SEGMENT HEAP DE PROCESSOS DO SISTEMA (CASO JÁ TENHA SIDO APLICADO)
# Contexto: Correção de danos causados por scripts antigos ruins da internet.
# ==============================================================================
Write-Host "`n[*] Verificando se há Segment Heap prejudicial aplicado na Shell do Windows..." -ForegroundColor DarkGray

 $ShellApps = @("explorer.exe", "SearchHost.exe", "StartMenuExperienceHost.exe", "ApplicationFrameHost.exe")
foreach ($App in $ShellApps) {
    $AppPath = "$IfeoPath\$App"
    $prop = "UseSegmentHeap"
    
    $currentVal = (Get-ItemProperty -Path $AppPath -Name $prop -ErrorAction SilentlyContinue).$prop
    if ($null -ne $currentVal -and $currentVal -ne 0) {
        try {
            Remove-ItemProperty -Path $AppPath -Name $prop -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Limpeza (Shell): $App"; Acao = "Segment Heap REMOVIDO (Preveniu Stutters)"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Limpeza (Shell): $App"; Acao = "Falha ao remover (Permissão?)"; Status = "ERRO" }
        }
    } else {
        # CORREÇÃO: Adicionado log para quando a chave já estiver no estado correto (limpa)
        $LogTweaks += [PSCustomObject]@{ Feature = "Limpeza (Shell): $App"; Acao = "Já estava limpo"; Status = "OK" }
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

Write-Host "`n[!] NOTA: Aplicativos como Discord e Steam devem ser reiniciados para que as mudanças de memória façam efeito.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"