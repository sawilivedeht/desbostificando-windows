# ==============================================================================
# OTIMIZAÇÃO DE PRIVACIDADE: DESATIVAÇÃO DE TELEMETRIA E ANÚNCIOS (WIN 11)
# Contexto: Bloqueio de envio de dados de diagnóstico para a Microsoft, 
# desativação de anúncios na Shell/Menu Iniciar, telemetria do Office e Edge.
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
Write-Host "      OTIMIZAÇÃO DE PRIVACIDADE: TELEMETRIA E ANÚNCIOS (WIN 11)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsRestart = $false

# ==============================================================================
# 1. TELEMETRIA GLOBAL DO CORE OS (Windows Diagnostics e Data Collection)
# ==============================================================================
Write-Host "`n[*] Configurando telemetria do kernel do Windows..." -ForegroundColor DarkGray

 $DataCollectionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $DataCollectionPath)) { New-Item -Path $DataCollectionPath -Force | Out-Null }

 $prop = "AllowTelemetry"; $val = 0
try {
    if ((Get-ItemProperty -Path $DataCollectionPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DataCollectionPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Telemetria Core OS"; Acao = "Definida para Segurança (0)"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Telemetria Core OS"; Acao = "Já estava no nível mínimo"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Telemetria Core OS"; Acao = "Falha ao modificar"; Status = "ERRO" }
}

# Desativa o serviço DiagTrack
Write-Host "[*] Gerenciando serviço de rastreamento (DiagTrack)..." -ForegroundColor DarkGray
try {
    $diagService = Get-Service -Name "DiagTrack" -ErrorAction Stop
    $changed = $false
    if ($diagService.Status -ne 'Stopped') {
        Stop-Service -Name "DiagTrack" -Force -ErrorAction Stop
        $changed = $true
    }
    if ($diagService.StartType -ne 'Disabled') {
        Set-Service -Name "DiagTrack" -StartupType Disabled -ErrorAction Stop
        $changed = $true
    }
    
    if ($changed) {
        $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: DiagTrack"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: DiagTrack"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: DiagTrack"; Acao = "Serviço não encontrado ou inacessível"; Status = "AVISO" }
}

# ==============================================================================
# 2. ANÚNCIOS, SUGESTÕES E EXPERIÊNCIAS CONSUMIDOR (Shell Content Delivery)
# ==============================================================================
Write-Host "[*] Removendo anúncios e sugestões do sistema..." -ForegroundColor DarkGray

# Política de Cloud Content (Bloatware automático)
 $CloudContentPath = "HKCU:\Software\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $CloudContentPath)) { New-Item -Path $CloudContentPath -Force | Out-Null }

 $prop = "DisableWindowsConsumerFeatures"; $val = 1
try {
    if ((Get-ItemProperty -Path $CloudContentPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $CloudContentPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Cloud Content: Bloatware"; Acao = "Instalação de apps promocionais bloqueada"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Cloud Content: Bloatware"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Cloud Content: Bloatware"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# Content Delivery Manager (Menu Iniciar, Tela de Bloqueio, Dicas)
 $ContentDeliveryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $ContentDeliveryPath) {
    $CdmSettings = @{
        "SoftLandingEnabled"                 = 0 # Dicas de experiência da Shell
        "SystemAndContentSuggestionsEnabled" = 0 # Sugestões do sistema
        "SubscribedContent-338387Enabled"    = 0 # Dicas do Windows
        "SubscribedContent-338388Enabled"    = 0 # Anúncios na Tela de Bloqueio
    }

    foreach ($setting in $CdmSettings.Keys) {
        $prop = $setting
        $val = $CdmSettings[$setting]
        try {
            if ((Get-ItemProperty -Path $ContentDeliveryPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
                Set-ItemProperty -Path $ContentDeliveryPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
                $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Desativado"; Status = "SUCESSO" }
                $needsRestart = $true
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Já estava desativado"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Falha ao modificar"; Status = "ERRO" }
        }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "CDM (Geral)"; Acao = "Caminho do registro não encontrado"; Status = "AVISO" }
}

# ==============================================================================
# 3. TELEMETRIA DO MICROSOFT OFFICE SUITE
# ==============================================================================
Write-Host "[*] Configurando privacidade do Microsoft Office..." -ForegroundColor DarkGray

 $OfficeCommonPath = "HKCU:\Software\Policies\Microsoft\Office\Common\Privacy"
if (-not (Test-Path $OfficeCommonPath)) { New-Item -Path $OfficeCommonPath -Force | Out-Null }

 $OfficeSettings = @{
    "LdfDiagnosticData" = 0 # Diagnóstico
    "DisconnectedState" = 1 # Estado Desconectado
}

foreach ($setting in $OfficeSettings.Keys) {
    $prop = $setting
    $val = $OfficeSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $OfficeCommonPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $OfficeCommonPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Office: $setting"; Acao = "Configurado para privacidade"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Office: $setting"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Office: $setting"; Acao = "Falha ao modificar (Office não instalado?)"; Status = "AVISO" }
    }
}

# ==============================================================================
# 4. TELEMETRIA DE NAVEGADORES (Microsoft Edge)
# ==============================================================================
Write-Host "[*] Desativando telemetria do Microsoft Edge..." -ForegroundColor DarkGray

 $EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (-not (Test-Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }

 $prop = "MetricsReportingEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $EdgePolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $EdgePolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Edge: MetricsReporting"; Acao = "Relatórios de uso desativados"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Edge: MetricsReporting"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Edge: MetricsReporting"; Acao = "Falha ao modificar"; Status = "ERRO" }
}

# ==============================================================================
# 5. REINÍCIO CONDICIONAL DO WINDOWS EXPLORER
# ==============================================================================
if ($needsRestart) {
    Write-Host "[*] Aplicando alterações visuais na interface..." -ForegroundColor DarkGray
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
Write-Host "1. Algumas políticas de telemetria podem exigir reinicialização do Windows para ter efeito total no kernel." -ForegroundColor White
Write-Host "2. As chaves do Microsoft Office só terão efeito se o pacote Office estiver instalado no sistema." -ForegroundColor White
Write-Host "3. O Windows Explorer só foi reiniciado se alguma alteração visual tiver sido feita.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"