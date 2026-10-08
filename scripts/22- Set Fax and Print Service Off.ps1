# ==============================================================================
# DEBLOATING DE SUBSISTEMA DE IMPRESSÃO E FAX (REDUÇÃO DE SUPERFÍCIE E I/O)
# Contexto: Remoção completa de serviços de impressão para máquinas dedicadas a 
# jogos ou desempenho bruto, eliminando processos em segundo plano e varreduras.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar recursos do Windows."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        DESINSTALAÇÃO DE RECURSOS DE IMPRESSÃO E FAX (DEBLOAT)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. REMOÇÃO DE CAPACIDADES E FEATURES DO WINDOWS (DISM)
# ==============================================================================
Write-Host "`n[*] Verificando recursos de Fax e Impressão..." -ForegroundColor DarkGray

# A. Remoção do Cliente de Fax e Escaneamento (Capacidade)
 $FaxCap = Get-WindowsCapability -Online -Name "Print.Fax.Scan*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($FaxCap -and $FaxCap.State -ne "NotPresent") {
    try {
        Remove-WindowsCapability -Online -Name $FaxCap.Name -ErrorAction Stop | Out-Null
        $LogTweaks += [PSCustomObject]@{ Feature = "Recurso: Fax e Scan"; Acao = "Removido com sucesso"; Status = "SUCESSO" }
    } catch {
        if ($_.Exception.Message -match "restart is required|pending") {
            $LogTweaks += [PSCustomObject]@{ Feature = "Recurso: Fax e Scan"; Acao = "Falha (Reboot pendente no Windows)"; Status = "AVISO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Recurso: Fax e Scan"; Acao = "Falha na remoção"; Status = "ERRO" }
        }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Recurso: Fax e Scan"; Acao = "Já estava removido"; Status = "OK" }
}

# B. Desativação de Features Opcionais (XPS e Internet Printing)
 $OptionalFeatures = @(
    "Printing-XPSServices-Features",
    "Printing-Foundation-InternetPrinting-Client"
)

foreach ($Feature in $OptionalFeatures) {
    $featInfo = Get-WindowsOptionalFeature -Online -FeatureName $Feature -ErrorAction SilentlyContinue
    if ($featInfo -and $featInfo.State -eq "Enabled") {
        try {
            Disable-WindowsOptionalFeature -Online -FeatureName $Feature -NoRestart -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Feature: $Feature"; Acao = "Desativada"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Feature: $Feature"; Acao = "Falha ao desativar"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Feature: $Feature"; Acao = "Já estava desativada"; Status = "OK" }
    }
}

# ==============================================================================
# 2. DESATIVAÇÃO DE SERVIÇOS RELACIONADOS
# ==============================================================================
Write-Host "`n[*] Configurando serviços de impressão..." -ForegroundColor DarkGray

# A. Serviço de Fax
try {
    $faxSvc = Get-Service -Name "Fax" -ErrorAction SilentlyContinue
    if ($faxSvc) {
        $changed = $false
        if ($faxSvc.Status -eq 'Running') { 
            Stop-Service -Name "Fax" -Force -ErrorAction SilentlyContinue 
            $changed = $true
        }
        if ($faxSvc.StartType -ne 'Disabled') { 
            Set-Service -Name "Fax" -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }
        
        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Fax (fxssvc)"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Fax (fxssvc)"; Acao = "Já estava desativado"; Status = "OK" }
        }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Fax (fxssvc)"; Acao = "Falha ao desativar"; Status = "ERRO" }
}

# B. Serviço PrintWorkflow (Pipeline de Impressão Moderno do Win 11)
# SOLUÇÃO: Bypass do cmdlet Set-Service via edição direta do Registro (Start=4)
 $PwSvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\PrintWorkflowUserSvc"
 $prop = "Start"
 $val = 4 # 4 = Disabled no kernel

if (Test-Path $PwSvcRegPath) {
    try {
        $currentStart = (Get-ItemProperty -Path $PwSvcRegPath -Name $prop -ErrorAction SilentlyContinue).$prop
        if ($null -eq $currentStart -or $currentStart -ne $val) {
            Set-ItemProperty -Path $PwSvcRegPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: PrintWorkflow (Win11)"; Acao = "Desativado via Registro (Bypass)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: PrintWorkflow (Win11)"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: PrintWorkflow (Win11)"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: PrintWorkflow (Win11)"; Acao = "Não presente neste sistema"; Status = "OK" }
}

# C. SPOOLER DE IMPRESSÃO (AÇÃO DESTRUTIVA - REQUER CONFIRMAÇÃO)
Write-Host "`n[!] ATENÇÃO: Desativar o Spooler removerá a capacidade de imprimir QUALQUER coisa (inclusive PDF)." -ForegroundColor Red
 $confirmSpooler = Read-Host "Tem certeza que deseja desativar o Spooler de Impressão? (S/N)"

if ($confirmSpooler -eq 'S' -or $confirmSpooler -eq 's') {
    try {
        $spoolerSvc = Get-Service -Name "Spooler" -ErrorAction SilentlyContinue
        if ($spoolerSvc) {
            if ($spoolerSvc.Status -eq 'Running') { Stop-Service -Name "Spooler" -Force -ErrorAction SilentlyContinue }
            if ($spoolerSvc.StartType -ne 'Disabled') { 
                Set-Service -Name "Spooler" -StartupType Disabled -ErrorAction Stop
                $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Spooler (IMPRESSÃO)"; Acao = "PARADO E DESATIVADO"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Spooler (IMPRESSÃO)"; Acao = "Já estava desativado"; Status = "OK" }
            }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Spooler (IMPRESSÃO)"; Acao = "Falha ao desativar (Protegido?)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Serviço: Spooler (IMPRESSÃO)"; Acao = "Mantido ativo (Cancelado pelo usuário)"; Status = "OK" }
}

# ==============================================================================
# 3. BLOQUEAR DOWNLOAD DE DRIVERS DE IMPRESSORA VIA WINDOWS UPDATE
# Contexto: O Windows costuma baixar drivers de impressora silenciosamente em segundo 
# plano quando detecta uma rede, consumindo banda e I/O de disco.
# ==============================================================================
Write-Host "`n[*] Aplicando políticas de restrição de drivers..." -ForegroundColor DarkGray

 $PrintPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers"
 $prop = "DoNotInstallCompatibleDriverFromWindowsUpdate"
 $val = 1

if (-not (Test-Path $PrintPolicyPath)) { New-Item -Path $PrintPolicyPath -Force | Out-Null }

try {
    if ((Get-ItemProperty -Path $PrintPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PrintPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Política: Download Driver WU"; Acao = "Bloqueado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Política: Download Driver WU"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Política: Download Driver WU"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

 $needsReboot = $LogTweaks | Where-Object { $_.Acao -match "Desativada|Removido" -and $_.Status -eq "SUCESSO" }
if ($needsReboot) {
    Write-Host "[!] NOTA: A remoção de componentes do Windows (DISM) exige uma REINICIALIZAÇÃO do sistema para limpar os arquivos antigos do disco." -ForegroundColor Yellow
}

Write-Host "`n"
Read-Host "Pressione ENTER para fechar"