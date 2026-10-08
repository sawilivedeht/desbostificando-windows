# ==============================================================================
# OTIMIZAÇÃO DE NAVEGADORES: DESATIVAÇÃO DE ACELERAÇÃO POR HARDWARE (GPU)
# Contexto: Resolve conflitos de renderização, crashes (TDR) e travamentos 
# frequentes forçando os navegadores a usarem o Software Renderer (CPU).
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
Write-Host "     OTIMIZAÇÃO DE NAVEGADORES: DESATIVAÇÃO DE HW ACCELERATION       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. MAPEAMENTO DE CAMINHOS DE DIRETIVAS (Motores Chromium)
# ==============================================================================
Write-Host "`n[*] Aplicando diretivas de renderização para motores Chromium..." -ForegroundColor DarkGray

 $ChromiumBrowsers = @{
    "Google Chrome"      = "HKLM:\SOFTWARE\Policies\Google\Chrome"
    "Microsoft Edge"     = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    "Brave"              = "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave"
    "Opera"              = "HKLM:\SOFTWARE\Policies\Opera"
    "Opera GX"           = "HKLM:\SOFTWARE\Policies\Opera GX"
    "Vivaldi"            = "HKLM:\SOFTWARE\Policies\Vivaldi"
    "Yandex"             = "HKLM:\SOFTWARE\Policies\Yandex\YandexBrowser"
    "Ungoogled Chromium" = "HKLM:\SOFTWARE\Policies\Chromium"
    "SRWare Iron"        = "HKLM:\SOFTWARE\Policies\SRWare\Iron"
    "Comodo Dragon"      = "HKLM:\SOFTWARE\Policies\Comodo\Dragon"
    "Slimjet"            = "HKLM:\SOFTWARE\Policies\FlashPeak\Slimjet"
    "CentBrowser"        = "HKLM:\SOFTWARE\Policies\CentStudio\CentBrowser"
    "Avast Secure"       = "HKLM:\SOFTWARE\Policies\Avast\AvastSecureBrowser"
}

 $prop = "HardwareAccelerationModeEnabled"
 $val = 0

foreach ($Browser in $ChromiumBrowsers.Keys) {
    $Path = $ChromiumBrowsers[$Browser]
    
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
    try {
        $currentVal = (Get-ItemProperty -Path $Path -Name $prop -ErrorAction SilentlyContinue).$prop
        if ($currentVal -ne $val) {
            Set-ItemProperty -Path $Path -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Chromium: $Browser"; Acao = "Aceleração de HW desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Chromium: $Browser"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Chromium: $Browser"; Acao = "Falha ao gravar no registro"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. DIRETIVA CORPORATIVA PARA MOTORES MOZILLA (FIREFOX, WATERFOX, ETC)
# ==============================================================================
Write-Host "[*] Aplicando diretiva de renderização para motores Mozilla..." -ForegroundColor DarkGray

 $MozillaBrowsers = @{
    "Mozilla Firefox" = "HKLM:\SOFTWARE\Policies\Mozilla\Firefox"
    "Waterfox"        = "HKLM:\SOFTWARE\Policies\Mozilla\Waterfox"
    "LibreWolf"       = "HKLM:\SOFTWARE\Policies\LibreWolf"
    "Floorp"          = "HKLM:\SOFTWARE\Policies\Floorp"
}

 $prop = "DisableHardwareAcceleration"
 $val = 1 # 1 = Desativado (Política oficial da Mozilla)

foreach ($Browser in $MozillaBrowsers.Keys) {
    $Path = $MozillaBrowsers[$Browser]
    
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }

    try {
        $currentVal = (Get-ItemProperty -Path $Path -Name $prop -ErrorAction SilentlyContinue).$prop
        if ($currentVal -ne $val) {
            Set-ItemProperty -Path $Path -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Mozilla: $Browser"; Acao = "Aceleração de HW desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Mozilla: $Browser"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Mozilla: $Browser"; Acao = "Falha ao gravar no registro"; Status = "ERRO" }
    }
}

# ==============================================================================
# 3. EXPURGO DE INSTÂNCIAS ATIVAS (Limpeza de Memória)
# ==============================================================================
Write-Host "[*] Encerrando instâncias ativas dos navegadores para aplicar mudanças..." -ForegroundColor DarkGray

 $BrowsersToKill = @(
    "chrome", "msedge", "brave", "opera", "opera_gx", "vivaldi", "browser", 
    "chromium", "iron", "dragon", "slimjet", "centbrowser", "AvastBrowser", 
    "firefox", "waterfox", "librewolf", "floorp"
)

foreach ($Process in $BrowsersToKill) {
    $runningProc = Get-Process -Name $Process -ErrorAction SilentlyContinue
    
    if ($runningProc) {
        try {
            Stop-Process -Name $Process -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Processo: $Process.exe"; Acao = "Finalizado com sucesso"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Processo: $Process.exe"; Acao = "Falha ao finalizar (Permissão?)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: $Process.exe"; Acao = "Não estava em execução"; Status = "OK" }
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

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Os navegadores foram forçados a usar o renderizador por software (CPU). Isso aumenta o uso do processador, mas elimina crashes por falha de GPU." -ForegroundColor White
Write-Host "2. Caso você não possua alguns dos navegadores listados, eles aparecerão no log, mas a escrita no registro é inofensiva e ignorada pelo sistema." -ForegroundColor White
Write-Host "3. AS ALTERAÇÕES SÓ ENTRARÃO EM VIGOR QUANDO VOCÊ ABRIR OS NAVEGADORES NOVAMENTE." -ForegroundColor White
Write-Host "4. Todos os navegadores abertos foram fechados à força. Verifique se não havia formulários não salvos.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"