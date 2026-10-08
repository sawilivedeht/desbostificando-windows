# ==============================================================================
# HARDENING DE PRIVACIDADE: MODO DMA (UNIÃO EUROPEIA) E DEBLOATING
# Contexto: Simula região da UE para forçar desativação de rastreamento, remoção 
# do Edge/Widgets e purge de telemetria da pesquisa local.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar políticas do sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "   APLICAÇÃO DE POLITICAS DE PRIVACIDADE (DMA/UE) E DEBLOATING      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsExplorerRestart = $false

# ==============================================================================
# 1. SPOOFING DE REGIÃO PARA ISLÂNDIA (GATILHO DE COMPLIANCE EU)
# Contexto: O Windows 11 lê essa chave. Se for um país do EEA (Espaço Econômico Europeu),
# ele habilita internamente strings de conformidade que limitam a telemetria.
# ==============================================================================
 $GeoPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\International\Geo"
if (-not (Test-Path $GeoPath)) { New-Item -Path $GeoPath -Force | Out-Null }

 $prop = "Nation"
 $val = "112"
try {
    if ((Get-ItemProperty -Path $GeoPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GeoPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Nation)"; Acao = "Alterado para 112 (Islândia/UE)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Nation)"; Acao = "Já estava configurado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Nation)"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

 $prop = "Name"
 $val = "IS"
try {
    if ((Get-ItemProperty -Path $GeoPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $GeoPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Name)"; Acao = "Alterado para IS"; Status = "SUCESSO" }
    } else {
        # CORREÇÃO: Adicionado log que estava faltando
        $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Name)"; Acao = "Já estava configurado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Geo-Spoofing (Name)"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 2. APLICAÇÃO DAS POLÍTICAS DE PRIVACIDADE REAIS DA UE
# Contexto: Agora que o sistema acha que está na UE, forçamos as chaves de privacidade
# que a Comissão Europeia exigiu que a Microsoft desbloqueasse para os usuários.
# ==============================================================================
 $PrivacyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy"
if (-not (Test-Path $PrivacyPath)) { New-Item -Path $PrivacyPath -Force | Out-Null }

# Desativa o ID de Publicidade (Advertising ID)
 $prop = "AdvertisingInfo"
 $val = 0
try {
    if ((Get-ItemProperty -Path $PrivacyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PrivacyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Advertising ID (Telemetria)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Advertising ID (Telemetria)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Advertising ID (Telemetria)"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# Desativa Experiências Personalizadas (Tailored Experiences / CEIP)
 $prop = "TailoredExperiencesWithDiagnosticDataEnabled"
 $val = 0
try {
    if ((Get-ItemProperty -Path $PrivacyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PrivacyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Tailored Experiences"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Tailored Experiences"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Tailored Experiences"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 3. PURGA ABSOLUTA DO BING E RASTREAMENTO NA PESQUISA LOCAL
# ==============================================================================
 $SearchPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $SearchPath)) { New-Item -Path $SearchPath -Force | Out-Null }

 $settings = @{
    "DisableWebSearch" = 1
    "ConnectedSearchUseBing" = 0
    "AllowSearchToUseLocation" = 0
}

foreach ($key in $settings.Keys) {
    try {
        if ((Get-ItemProperty -Path $SearchPath -Name $key -ErrorAction SilentlyContinue).$key -ne $settings[$key]) {
            Set-ItemProperty -Path $SearchPath -Name $key -Value $settings[$key] -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Pesquisa: $key"; Acao = "Configurado para $($settings[$key])"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Pesquisa: $key"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Pesquisa: $key"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 4. DESINSTALAÇÃO FORÇADA DO MICROSOFT EDGE (MÉTODO ROBUSTO)
# ==============================================================================
Write-Host "`nProcurando binários de instalação do Microsoft Edge..." -ForegroundColor DarkGray
 $EdgeInstaller = Get-ChildItem -Path "C:\Program Files (x86)\Microsoft\Edge\Application" -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

if ($EdgeInstaller) {
    Write-Host "Edge encontrado. Iniciando desinstalação forçada e silenciosa..." -ForegroundColor Yellow
    $Arguments = "--uninstall --system-level --verbose-logging --force-uninstall"
    try {
        $proc = Start-Process -FilePath $EdgeInstaller.FullName -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -ErrorAction Stop
        if ($proc.ExitCode -eq 0) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Microsoft Edge"; Acao = "Desinstalado com sucesso"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Microsoft Edge"; Acao = "Falha na desinstalação (Código: $($proc.ExitCode))"; Status = "ERRO" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Microsoft Edge"; Acao = "Erro ao executar o uninstaller"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Microsoft Edge"; Acao = "Não encontrado (Já removido ou nunca instalado)"; Status = "OK" }
}

# ==============================================================================
# 5. BLOQUEIO DE WIDGETS (FALLBACK ELEGANTE)
# ==============================================================================
try {
    $WidgetPath = "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
    if (-not (Test-Path $WidgetPath)) { New-Item -Path $WidgetPath -Force | Out-Null }
    
    if ((Get-ItemProperty -Path $WidgetPath -Name "AllowNewsAndInterests" -ErrorAction SilentlyContinue).AllowNewsAndInterests -ne 0) {
        Set-ItemProperty -Path $WidgetPath -Name "AllowNewsAndInterests" -Value 0 -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Widgets (Politica HKLM)"; Acao = "Bloqueado via GPO"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Widgets (Politica HKLM)"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    # Plano B: Ocultar da barra de tarefas se o TrustedInstaller bloquear a GPO
    $TaskbarPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    if ((Get-ItemProperty -Path $TaskbarPath -Name "TaskbarDa" -ErrorAction SilentlyContinue).TaskbarDa -ne 0) {
        Set-ItemProperty -Path $TaskbarPath -Name "TaskbarDa" -Value 0 -Type DWord -Force
        $LogTweaks += [PSCustomObject]@{ Feature = "Widgets (Fallback HKCU)"; Acao = "Ocultado da Barra de Tarefas"; Status = "SUCESSO" }
        $needsExplorerRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Widgets (Fallback HKCU)"; Acao = "Já estava oculto"; Status = "OK" }
    }
}

# ==============================================================================
# 6. REINICIALIZAÇÃO SEGURA DO EXPLORER (SE NECESSÁRIO)
# ==============================================================================
if ($needsExplorerRestart) {
    Write-Host "`nOcultação dos Widgets requer reinício do Explorer." -ForegroundColor Yellow
    $confirm = Read-Host "Deseja reiniciar o Explorer agora? (S/N)"
    if ($confirm -eq 'S' -or $confirm -eq 's') {
        Stop-Process -Name explorer -Force
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
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

Write-Host "`n[!] NOTA: A alteração de região (Geo-Spoofing) pode exigir reinício do Windows para que todas as políticas da UE reconheçam a nova localização.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"