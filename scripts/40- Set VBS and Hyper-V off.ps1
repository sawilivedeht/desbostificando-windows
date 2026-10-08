# ==============================================================================
# ANIQUILAÇÃO DA PILHA DE VIRTUALIZAÇÃO (VBS / HVCI / HYPER-V / SYSTEM GUARD)
# Contexto: Remoção completa da camada de hypervisor para recuperação total de 
# CPU, RAM e eliminação de DPC Latency causada por ISRs de virtualização.
# Requer: Execução como Administrador e REINICIALIZAÇÃO OBRIGATÓRIA.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para matar serviços e usar o bcdedit."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      DESATIVAÇÃO TOTAL DA VIRTUALIZAÇÃO DE SEGURANÇA (VBS/HYPER-V)   " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DAS CHAVES DE REGISTRO CORE (VBS, HVCI E CREDENTIAL GUARD)
# ==============================================================================
 $DeviceGuardPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
if (-not (Test-Path $DeviceGuardPath)) { New-Item -Path $DeviceGuardPath -Force | Out-Null }

 $HvciPath = "$DeviceGuardPath\Scenarios\HypervisorEnforcedCodeIntegrity"
if (-not (Test-Path $HvciPath)) { New-Item -Path $HvciPath -Force | Out-Null }

# Desativa VBS Global
 $prop = "EnableVirtualizationBasedSecurity"; $val = 0
try {
    if ((Get-ItemProperty -Path $DeviceGuardPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $DeviceGuardPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Device Guard)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Device Guard)"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "VBS (Device Guard)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa HVCI (Memory Integrity)
 $prop = "Enabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $HvciPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $HvciPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "HVCI (Memory Integrity)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. SINCRONIZAÇÃO COM A INTERFACE DA SEGURANÇA DO WINDOWS
# Contexto: Força o aplicativo "Segurança do Windows" a reconhecer que o HVCI está OFF,
# evitando que o usuário veja a opção como "Ativa" enganosamente na UI.
# ==============================================================================
 $UISyncPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Virtualization"
if (-not (Test-Path $UISyncPath)) { New-Item -Path $UISyncPath -Force | Out-Null }

 $prop = "HypervisorEnforcedCodeIntegrity"; $val = 0
try {
    if ((Get-ItemProperty -Path $UISyncPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $UISyncPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI Sync (Segurança do Win)"; Acao = "Sincronizado para OFF"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "UI Sync (Segurança do Win)"; Acao = "Já estava sincronizado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "UI Sync (Segurança do Win)"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. PARÂMETROS DO GERENCIADOR DE BOOT (BCDEDIT)
# ==============================================================================
Write-Host "`n[*] Configurando gerenciador de boot para ignorar hipervisor..." -ForegroundColor DarkGray

# Desliga o Hypervisor
 $null = bcdedit /set hypervisorlaunchtype off 2>&1
if ($LASTEXITCODE -eq 0) { $LogTweaks += [PSCustomObject]@{ Feature = "Boot: Hypervisor"; Acao = "Desativado"; Status = "SUCESSO" } }
else { $LogTweaks += [PSCustomObject]@{ Feature = "Boot: Hypervisor"; Acao = "Falha ao aplicar"; Status = "ERRO" } }

# Desliga o VSM (Virtual Secure Mode) para evitar BSODs em hardwares específicos
 $null = bcdedit /set vsmlaunchtype off 2>&1
if ($LASTEXITCODE -eq 0) { $LogTweaks += [PSCustomObject]@{ Feature = "Boot: VSM (Secure Mode)"; Acao = "Desativado"; Status = "SUCESSO" } }
else { $LogTweaks += [PSCustomObject]@{ Feature = "Boot: VSM (Secure Mode)"; Acao = "Falha ao aplicar"; Status = "ERRO" } }

# ==============================================================================
# 4. DESATIVAÇÃO PRECISA DE SERVIÇOS (EVITANDO WILDCARDS PERIGOSOS)
# ==============================================================================
Write-Host "`n[*] Desativando serviços de infraestrutura..." -ForegroundColor DarkGray

# Lista exata dos serviços do System Guard e Hyper-V nativo
 $TargetServices = @(
    "SgrmBroker",          # System Guard Runtime Monitor Broker
    "SgrmAgent",           # System Guard Runtime Monitor Agent
    "vmms",                # Hyper-V Virtual Machine Management
    "vmcompute",           # Hyper-V Host Compute Service
    "hvhost"               # Hyper-V Host Compute Service (Auxiliar)
)

foreach ($SvcName in $TargetServices) {
    $service = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
    
    if ($service) {
        $stoppedStatus = ""
        # Tenta parar o serviço se estiver rodando
        if ($service.Status -eq 'Running') {
            try {
                Stop-Service -Name $SvcName -ErrorAction Stop
                $stoppedStatus = "Parado e "
            } catch {
                # Processos PPL (Protegidos) como o SgrmBroker vão falhar aqui. É normal.
                $stoppedStatus = "[Protegido pelo SO - Parará no Boot] "
            }
        }

        try {
            # Altera o tipo de inicialização
            if ($service.StartType -ne 'Disabled') {
                Set-Service -Name $SvcName -StartupType Disabled -ErrorAction Stop
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "${stoppedStatus}Desativado"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Já estava desativado"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Falha ao desativar"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Não instalado neste PC"; Status = "OK" }
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
Write-Host "1. CRÍTICO: O Hipervisor e o System Guard são protegidos pelo kernel." -ForegroundColor Red
Write-Host "2. Você DEVE REINICIAR O COMPUTADOR agora para que a camada de virtualização seja completamente removida da memória.`n" -ForegroundColor Red

Read-Host "Pressione ENTER para fechar"