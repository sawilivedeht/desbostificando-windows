# ==============================================================================
# OTIMIZAÇÃO EXTREMA DE PILHA TCP/IP E HARDWARE DE REDE (LOW-LATENCY)
# Contexto: Redução de Ping, Jitter, eliminação de micro-stutters causados por 
# buffers de rede e otimização de processamento multi-núcleo (RSS).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar a pilha TCP e drivers."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "           OTIMIZAÇÃO AVANÇADA DE REDE (TCP/IP E NIC OFFLOAD)        " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. OTIMIZAÇÃO DA PILHA GLOBAL TCP/IP (NETSH)
# ==============================================================================
Write-Host "`n[*] Otimizando pilha TCP/IP global..." -ForegroundColor DarkGray

# Array ordenado com os comandos e seus nomes amigáveis para o log
 $NetshCommands = [ordered]@{
    "Heuristics (Restrição Dinâmica)" = "netsh int tcp set heuristics disabled"
    "Auto-Tuning Level"                = "netsh int tcp set global autotuninglevel=normal"
    "RSS (Distribuição de CPU)"        = "netsh int tcp set global rss=enabled"
    "TCP Fast Open (Handshake)"        = "netsh int tcp set global fastopen=enabled"
    "TCP Timestamps (Overhead)"        = "netsh int tcp set global timestamps=disabled"
    "Direct Cache Access (DCA)"        = "netsh int tcp set global dca=enabled"
    "RSS para IPv6"                    = "netsh int ipv6 set global rss=enabled" 
}

foreach ($Name in $NetshCommands.Keys) {
    try {
        $cmd = $NetshCommands[$Name]
        $null = Invoke-Expression $cmd 2>&1
        if ($LASTEXITCODE -eq 0) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Netsh: $Name"; Acao = "Aplicado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Netsh: $Name"; Acao = "Falha ou não suportado"; Status = "AVISO" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Netsh: $Name"; Acao = "Erro de execução"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. PARÂMETROS AVANÇADOS NO REGISTRO (AFD.SYS & TCPIP.SYS)
# ==============================================================================
Write-Host "`n[*] Aplicando parâmetros de baixo nível no registro..." -ForegroundColor DarkGray

# A. Limiar de envio rápido de datagramas
 $AfdPath = "HKLM:\SYSTEM\CurrentControlSet\Services\AFD\Parameters"
 $prop = "FastSendDatagramThreshold"
 $val = 64000
if (-not (Test-Path $AfdPath)) { New-Item -Path $AfdPath -Force | Out-Null }
try {
    if ((Get-ItemProperty -Path $AfdPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $AfdPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "AFD: FastSendDatagram"; Acao = "Definido para 64000"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "AFD: FastSendDatagram"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "AFD: FastSendDatagram"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" } }

# B. TcpTimedWaitDelay (Acelera abertura de novas conexões)
 $TcpBasePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
 $prop = "TcpTimedWaitDelay"
 $val = 30
if (-not (Test-Path $TcpBasePath)) { New-Item -Path $TcpBasePath -Force | Out-Null }
try {
    if ((Get-ItemProperty -Path $TcpBasePath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $TcpBasePath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "TCP: TimedWaitDelay"; Acao = "Reduzido para 30s"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "TCP: TimedWaitDelay"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "TCP: TimedWaitDelay"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. ALGORITMO DE NAGLE (APENAS EM PLACAS FÍSICAS USANDO WMI)
# ==============================================================================
Write-Host "`n[*] Desativando Algoritmo de Nagle (TcpNoDelay) em adaptadores físicos..." -ForegroundColor DarkGray

 $PhysicalAdapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }
 $WmiAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $PhysicalAdapters.InterfaceIndex -contains $_.Index }

foreach ($WmiAdapt in $WmiAdapters) {
    $RegInterfacePath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($WmiAdapt.SettingID)"
    
    if (Test-Path $RegInterfacePath) {
        $prop1 = "TcpAckFrequency"; $val1 = 1
        $prop2 = "TCPNoDelay"; $val2 = 1
        $changed = $false

        try {
            if ((Get-ItemProperty -Path $RegInterfacePath -Name $prop1 -ErrorAction SilentlyContinue).$prop1 -ne $val1) {
                Set-ItemProperty -Path $RegInterfacePath -Name $prop1 -Value $val1 -Type DWord -Force -ErrorAction Stop; $changed = $true
            }
            if ((Get-ItemProperty -Path $RegInterfacePath -Name $prop2 -ErrorAction SilentlyContinue).$prop2 -ne $val2) {
                Set-ItemProperty -Path $RegInterfacePath -Name $prop2 -Value $val2 -Type DWord -Force -ErrorAction Stop; $changed = $true
            }

            $adaptDesc = $WmiAdapt.Description
            if ($adaptDesc.Length -gt 40) { $adaptDesc = $adaptDesc.Substring(0, 40) }

            if ($changed) {
                $LogTweaks += [PSCustomObject]@{ Feature = "Nagle/ACK: $adaptDesc"; Acao = "Desativado (TCP Puro)"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Nagle/ACK: $adaptDesc"; Acao = "Já estava otimizado"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Nagle/ACK: $adaptDesc"; Acao = "Falha ao gravar"; Status = "ERRO" }
        }
    }
}

# ==============================================================================
# 4. COMPORTAMENTO FÍSICO DO ADAPTADOR (OFFLOADING & ENERGY)
# ==============================================================================
Write-Host "`n[*] Configurando silício do controlador de rede (Interrupts/Offload)..." -ForegroundColor DarkGray

# Desativa gerenciamento de energia
foreach ($Adapter in $PhysicalAdapters) {
    try {
        $powerMgmt = Get-NetAdapterPowerManagement -Name $Adapter.Name -ErrorAction SilentlyContinue
        if ($powerMgmt -and $powerMgmt.AllowComputerToTurnOffDevice -ne $false) {
            Disable-NetAdapterPowerManagement -Name $Adapter.Name -NoRestart -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Power Mgmt: $($Adapter.Name)"; Acao = "Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Power Mgmt: $($Adapter.Name)"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Power Mgmt: $($Adapter.Name)"; Acao = "Falha ao alterar"; Status = "ERRO" }
    }
}

# Tweak de Hardware usando -RegistryValue (Ignora idioma do Windows)
 $HardwareTweaks = @{
    "Interrupt Moderation"               = "0"
    "Moderação de interrupção"           = "0"
    "Receive Side Scaling"               = "1"
    "Escalonamento do lado de recepção"  = "1"
    "Packet Coalescing"                  = "0"
    "Agrupamento de pacotes"             = "0"
}

foreach ($Adapter in $PhysicalAdapters) {
    foreach ($DisplayName in $HardwareTweaks.Keys) {
        $targetVal = $HardwareTweaks[$DisplayName]
        
        try {
            $currentProp = Get-NetAdapterAdvancedProperty -InterfaceDescription $Adapter.InterfaceDescription -DisplayName $DisplayName -ErrorAction SilentlyContinue
            
            if ($currentProp) {
                if ($currentProp.RegistryValue -ne $targetVal) {
                    Set-NetAdapterAdvancedProperty -InterfaceDescription $Adapter.InterfaceDescription -DisplayName $DisplayName -RegistryValue $targetVal -ErrorAction Stop
                    $LogTweaks += [PSCustomObject]@{ Feature = "HW: $DisplayName ($($Adapter.Name))"; Acao = "Alterado para $targetVal"; Status = "SUCESSO" }
                } else {
                    $LogTweaks += [PSCustomObject]@{ Feature = "HW: $DisplayName ($($Adapter.Name))"; Acao = "Já estava correto"; Status = "OK" }
                }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "HW: $DisplayName ($($Adapter.Name))"; Acao = "Falha ao aplicar"; Status = "ERRO" }
        }
    }
}

# ==============================================================================
# 5. DESATIVAR NETBIOS OVER TCP/IP (REDUZ BROADCAST LAN)
# ==============================================================================
Write-Host "`n[*] Desativando NetBIOS sobre TCP/IP para reduzir broadcasts..." -ForegroundColor DarkGray

foreach ($WmiAdapt in $WmiAdapters) {
    if ($WmiAdapt.TcpipNetBIOSOptions -ne 2) { 
        try {
            Set-CimInstance -InputObject $WmiAdapt -Property @{TcpipNetBIOSOptions = 2 } -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "NetBIOS over TCP/IP"; Acao = "Desativado (Menos Latência LAN)"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "NetBIOS over TCP/IP"; Acao = "Falha ao alterar"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "NetBIOS over TCP/IP"; Acao = "Já estava desativado"; Status = "OK" }
    }
}

# ==============================================================================
# 6. POLÍTICA DE QoS (MITO DA RESERVA DE BANDA)
# ==============================================================================
 $QosPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"
 $prop = "NonBestEffortLimit"
 $val = 0
if (-not (Test-Path $QosPath)) { New-Item -Path $QosPath -Force | Out-Null }
try {
    if ((Get-ItemProperty -Path $QosPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $QosPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "QoS Bandwidth Limit"; Acao = "Limite removido (0%)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "QoS Bandwidth Limit"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "QoS Bandwidth Limit"; Acao = "Falha ao gravar"; Status = "ERRO" } }


# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. Algumas alterações na pilha TCP exigem que os aplicativos (jogos/browsers) sejam reiniciados para utilizarem o novo socket." -ForegroundColor White
Write-Host "2. Alterações de hardware na placa de rede (Offload/RSS) podem exigir a reconexão do cabo de rede ou reinicialização do PC." -ForegroundColor White
Write-Host "`n"
Read-Host "Pressione ENTER para fechar"