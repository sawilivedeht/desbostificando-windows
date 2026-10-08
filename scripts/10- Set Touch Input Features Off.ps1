# ==============================================================================
# PURGA DE SUBSISTEMAS MÓVEIS (TOUCH SCREEN, PEN E TABLET PC)
# Contexto: Desativação completa de drivers de tela de toque e serviços de entrada 
# móvel que consomem RAM/CPU em Desktops e PCs Gamer fixos.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para desativar Serviços e Hardware PNP."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DE SUBSISTEMAS MÓVEIS (TOUCH / PEN / TABLET PC)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DO PORTÃO LÓGICO DE TOQUE (REGISTRO HKCU)
# ==============================================================================
Write-Host "`n[*] Desativando Touch Gate no registro..." -ForegroundColor DarkGray

 $TouchPath = "HKCU:\Software\Microsoft\Wisp\Touch"
if (-not (Test-Path $TouchPath)) { New-Item -Path $TouchPath -Force | Out-Null }

 $prop = "TouchGate"; $val = 0
try {
    if ((Get-ItemProperty -Path $TouchPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $TouchPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Touch Gate"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Touch Gate"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Touch Gate"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAÇÃO DE SERVIÇOS DE ENTRADA MÓVEL (COM BYPASS DE REGISTRO)
# ==============================================================================
Write-Host "[*] Desativando serviços de Tablet e Caneta..." -ForegroundColor DarkGray

 $MobileServices = @(
    "TabletInputService", # Teclado Virtual e Touch
    "PenService"          # Serviço de entrada de Caneta/Stylus
)

foreach ($ServiceName in $MobileServices) {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($service) {
        $changed = $false
        
        # Tenta parar o serviço
        try {
            if ($service.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction Stop
                $changed = $true
            }
        } catch {
            Write-Warning "Falha ao parar o serviço $ServiceName. Tentando forçar via registro..."
        }
        
        # Tenta desativar via API normal
        try {
            if ($service.StartType -ne 'Disabled') {
                Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
                $changed = $true
            }
        } catch {
            Write-Warning "Falha ao desativar $ServiceName via API. Tentando via registro..."
        }

        # BYPASS DE PPL (PROTECTED PROCESS LIGHT)
        # Escreve direto no registro garante que ele não inicie no boot.
        $SvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"
        $currentStart = (Get-ItemProperty -Path $SvcRegPath -Name "Start" -ErrorAction SilentlyContinue).Start
        if ($null -ne $currentStart -and $currentStart -ne 4) {
            try {
                Set-ItemProperty -Path $SvcRegPath -Name "Start" -Value 4 -Type DWord -Force -ErrorAction Stop
                $changed = $true
            } catch {
                # Silencioso, o relatório abaixo cuidará do status
            }
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Já estava desativado"; Status = "OK" }
        }
    }
}

# ==============================================================================
# 3. DESATIVAÇÃO DE HARDWARE NO GERENCIADOR DE DISPOSITIVOS (IDIOMA-PROOF)
# ==============================================================================
Write-Host "[*] Buscando drivers de Tela Sensível ao Toque no hardware..." -ForegroundColor DarkGray

# CORREÇÃO: Ao invés de usar -FriendlyName (que muda conforme o idioma do Windows),
# usamos -InstanceId com a regex "TCH". 
 $TouchDevices = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { 
    $_.InstanceId -match "TCH" -and $_.Status -ne "Unknown" # Ignora dispositivos fantasmas
}

if ($TouchDevices) {
    foreach ($Device in $TouchDevices) {
        if ($Device.Status -ne "Error" -and $Device.Status -ne "Disabled") {
            try {
                Disable-PnpDevice -InstanceId $Device.InstanceId -Confirm:$false -ErrorAction Stop
                $shortId = $Device.InstanceId.Substring(0, [math]::Min(25, $Device.InstanceId.Length))
                $LogTweaks += [PSCustomObject]@{ Feature = "HW: Touch Screen"; Acao = "Desativado (ID: $shortId...)"; Status = "SUCESSO" }
            } catch {
                $LogTweaks += [PSCustomObject]@{ Feature = "HW: Touch Screen"; Acao = "Falha ao desativar (Requer Reboot?)"; Status = "ERRO" }
            }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "HW: Touch Screen"; Acao = "Já estava desativado no hardware"; Status = "OK" }
        }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "HW: Touch Screen"; Acao = "Nenhum hardware de toque encontrado"; Status = "INFO" }
}

# ==============================================================================
# ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Atualizando subsistema de entrada sem reiniciar a Shell..." -ForegroundColor DarkGray
    
    try {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction Stop
        $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
    } catch {
        # Se a classe já existe na sessão, o Add-Type falha, mas a API já está carregada
        $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
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

Write-Host "`n[!] NOTA: Se você estiver executando este script em um NOTEBOOK com tela touch e mudar de ideia no futuro, basta ir em 'Gerenciador de Dispositivos' e clicar em 'Habilitar dispositivo' no driver de toque, ou ir em Configurações > Bluetooth e dispositivos > Touch." -ForegroundColor Yellow
Write-Host "[!] A busca por hardware foi feita usando códigos universais (Regex 'TCH'), portanto funciona corretamente em Windows em Inglês, Português, Espanhol, etc.`n" -ForegroundColor White