# ==============================================================================
# ISOLAMENTO DE DRIVERS: BLOQUEIO DO WINDOWS UPDATE E BUSCA AUTOMÁTICA
# Contexto: Impedir que a Microsoft substitua drivers manuais instalados por 
# versões genéricas, e eliminar o I/O de rede/Disco causado por buscas de driver.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas de Atualização."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "          ISOLAMENTO DE DRIVERS E BLOQUEIO DO WU MEDIC SERVICE        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Ao bloquear o Windows Update, você assumirá total responsabilidade por manter seus drivers atualizados manualmente via sites oficiais (NVIDIA, AMD, Intel, etc)."

 $LogTweaks = @()

# ==============================================================================
# 1. EXPURGO DE CONFIGURAÇÃO NO WINDOWS UPDATE (GPO MIRROR)
# ==============================================================================
Write-Host "`n[*] Configurando políticas de bloqueio de drivers no WU..." -ForegroundColor DarkGray

 $WuPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (-not (Test-Path $WuPolicyPath)) { New-Item -Path $WuPolicyPath -Recurse -Force | Out-Null }

 $prop = "ExcludeWUDriversInQualityUpdate"; $val = 1
try {
    if ((Get-ItemProperty -Path $WuPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $WuPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Driver Block"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Driver Block"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: WU Driver Block"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO SUBSISTEMA PLUG AND PLAY (DRIVER SEARCHING)
# ==============================================================================
 $DriverSearchPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"

# SearchOrderConfig = 0 (Nunca buscar no WU. Usa apenas drivers locais/inf)
 $prop = "SearchOrderConfig"; $val = 0
try {
    if ((Get-ItemProperty -Path $DriverSearchPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DriverSearchPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Driver Search"; Acao = "Restrito para Local"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Driver Search"; Acao = "Já estava restrito"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Driver Search"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DE METADADOS DE DISPOSITIVOS
# ==============================================================================
 $DeviceMetadataPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata"

 $prop = "PreventDeviceMetadataFromNetwork"; $val = 1
try {
    if ((Get-ItemProperty -Path $DeviceMetadataPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DeviceMetadataPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Device Metadata"; Acao = "Bloqueado na rede"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Device Metadata"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "PnP: Device Metadata"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 4. DESATIVAÇÃO DO "DEVICE SETUP MANAGER"
# Contexto: Quando você pluga um dispositivo USB (mouse, HD, celular), esse serviço 
# dispara processos em segundo plano para achar ícones e softwares extras na Store.
# Desativá-lo elimina o "congelão" de 2-3 segundos ao plugar coisas na USB.
# ==============================================================================
Write-Host "[*] Desativando Gerenciador de Configuração de Dispositivos..." -ForegroundColor DarkGray

 $DsmSvc = Get-Service -Name "DeviceSetupManager" -ErrorAction SilentlyContinue
if ($DsmSvc) {
    $changed = $false
    try {
        if ($DsmSvc.Status -eq 'Running') { 
            Stop-Service -Name "DeviceSetupManager" -Force -NoWait -ErrorAction Stop | Out-Null 
            $changed = $true
        }
    } catch { Write-Warning "Falha ao parar o DeviceSetupManager." }

    try {
        if ($DsmSvc.StartType -ne 'Disabled') {
            Set-Service -Name "DeviceSetupManager" -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }
    } catch { Write-Warning "Falha ao desativar DeviceSetupManager via API." }

    if ($changed) {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: DeviceSetupManager"; Acao = "Desativado (Fim do lag USB)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: DeviceSetupManager"; Acao = "Já estava desativado"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: DeviceSetupManager"; Acao = "Serviço não encontrado"; Status = "INFO" }
}

# ==============================================================================
# 5. ASSASSINATO DO WAASMEDICSVC (O PROTETOR DO WINDOWS UPDATE)
# Contexto: O Windows Update Medic Service é um daemon de proteção. Se você alterar 
# as políticas do WU, ele as reverterá silenciosamente em poucos dias. Ele é um 
# serviço protegido (PPL), então não podemos usar o Set-Service normal. 
# Solução: Escrita direta no registro (Start=4).
# ==============================================================================
Write-Host "[*] Aplicando Bypass no WaaSMedicSvc (Protetor do WU)..." -ForegroundColor DarkGray

 $WaaSMedicPath = "HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc"
if (Test-Path $WaaSMedicPath) {
    $prop = "Start"; $val = 4 # 4 = Disabled
    
    # CORREÇÃO: Usar $prop ao invés de $Start
    $currentStart = (Get-ItemProperty -Path $WaaSMedicPath -Name $prop -ErrorAction SilentlyContinue).$prop
    try {
        if ($null -eq $currentStart -or $currentStart -ne $val) {
            Set-ItemProperty -Path $WaaSMedicPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: WaaSMedicSvc"; Acao = "Neutralizado via Registro"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: WaaSMedicSvc"; Acao = "Já estava neutralizado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: WaaSMedicSvc"; Acao = "Acesso Negado (PPL ativo)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: WaaSMedicSvc"; Acao = "Não presente neste sistema"; Status = "INFO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA CRÍTICA: O Windows Update pode exibir uma notificação dizendo que 'Alguns ajustes são gerenciados pela sua organização'. Isso é normal e significa que as políticas foram aplicadas com sucesso.`n" -ForegroundColor Yellow