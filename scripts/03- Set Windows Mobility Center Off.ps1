# ==============================================================================
# PURGA DE COMPONENTES MÓVEIS (MOBILITY CENTER, TABLET PC E SENSORES)
# Contexto: Remoção de interfaces, serviços e subsistemas projetados para Laptops 
# e Tablets (2-em-1) que são completamente inúteis em Desktops ou PCs Gamer fixos, 
# liberando pequenas porções de RAM e eliminando checagens de hardware ociosas.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas e Serviços."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DE ARQUITETURA MÓVEL (DESKTOP / GAMING RIG CLEANUP)       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DO MOBILITY CENTER (GPO MIRROR)
# ==============================================================================
Write-Host "`n[*] Desativando Windows Mobility Center..." -ForegroundColor DarkGray

 $MobilityPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\MobilityCenter"
if (-not (Test-Path $MobilityPath)) { New-Item -Path $MobilityPath -Force | Out-Null }

 $prop = "NoMobilityCenter"
 $val = 1
if ((Get-ItemProperty -Path $MobilityPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $MobilityPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Mobility Center"; Acao = "Desativado via GPO"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Mobility Center"; Acao = "Já estava desativado"; Status = "OK" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO SERVIÇO DE ENTRADA DE TABLET PC (TABTIP)
# Contexto: O TabletInputService gerencia o teclado virtual (OSK) e reconhecimento 
# de caneta. Em Desktops, ele carrega o componente `TabTip.exe` em memória e consome 
# cerca de 15-20MB de RAM aguardando toques na tela que nunca vão acontecer.
# ==============================================================================
Write-Host "[*] Desativando subsistema de Tablet PC..." -ForegroundColor DarkGray

 $TabletSvc = Get-Service -Name "TabletInputService" -ErrorAction SilentlyContinue
if ($TabletSvc) {
    if ($TabletSvc.Status -eq 'Running') { Stop-Service -Name "TabletInputService" -Force -NoWait -ErrorAction SilentlyContinue }
    if ($TabletSvc.StartType -ne 'Disabled') {
        Set-Service -Name "TabletInputService" -StartupType Disabled -ErrorAction SilentlyContinue
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Tablet Input (TabTip)"; Acao = "Desativado (Libera ~20MB RAM)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Tablet Input (TabTip)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Tablet Input (TabTip)"; Acao = "Não presente neste PC"; Status = "OK" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DOS SERVIÇOS DE SENSORES
# Contexto: Desktops comuns não possuem Acelerômetro, Giroscópio ou Luz Ambiental. 
# O serviço de sensores fica acordado monitorando drivers fictícios.
# ==============================================================================
Write-Host "[*] Desativando serviços de Sensoriamento..." -ForegroundColor DarkGray

 $SensorServices = @(
    "SensorService",       # Serviço principal de dados de sensores
    "SensrSvc"             # Serviço de dados do sensor (Legado)
)

foreach ($SvcName in $SensorServices) {
    $service = Get-Service -Name $SvcName -ErrorAction SilentlyContinue
    
    if ($service) {
        if ($service.Status -eq 'Running') { Stop-Service -Name $SvcName -Force -NoWait -ErrorAction SilentlyContinue }
        if ($service.StartType -ne 'Disabled') {
            Set-Service -Name $SvcName -StartupType Disabled -ErrorAction SilentlyContinue
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } else {
        # CORREÇÃO: Adicionado log para quando o serviço não existir, mantendo o relatório completo
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $SvcName"; Acao = "Não presente neste PC"; Status = "OK" }
    }
}

# ==============================================================================
# 4. DESATIVAÇÃO DO SERVIÇO DE LOCALIZAÇÃO
# Contexto: Usado para GPS e "Wi-Fi Sensing" (descobrir sua localização baseada 
# nos roteadores ao redor). Em um PC fixo, isso só serve para telemetria e consumo de rede.
# ==============================================================================
Write-Host "[*] Desativando rastreamento de Localização..." -ForegroundColor DarkGray

 $LocationSvc = Get-Service -Name "lfsvc" -ErrorAction SilentlyContinue
if ($LocationSvc) {
    if ($LocationSvc.Status -eq 'Running') { Stop-Service -Name "lfsvc" -Force -NoWait -ErrorAction SilentlyContinue }
    if ($LocationSvc.StartType -ne 'Disabled') {
        Set-Service -Name "lfsvc" -StartupType Disabled -ErrorAction SilentlyContinue
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Location (lfsvc)"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Location (lfsvc)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Location (lfsvc)"; Acao = "Não presente neste PC"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Se você está rodando este script em um NOTEBOOK, a desativação do Location e dos Sensores pode quebrar o 'Auto-Brightness' (Brilho Automático) e o 'Plane Mode' (Modo Avião automático em voos). Recomendado estritamente para Desktops.`n" -ForegroundColor Yellow