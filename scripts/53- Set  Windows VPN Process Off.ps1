# ==============================================================================
# DESATIVAÇÃO DE PILHA VPN, TÚNEIS IPV6 E DESCOBERTA DE PROXY (WPAD)
# Contexto: Remoção de subsistemas de rede corporativa/empresarial para reduzir 
# broadcast LAN, economizar memória e limpar portas de escuta ociosas.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para desativar serviços de rede."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DE SUBSISTEMAS VPN, TÚNEIS E PROXY (NETWORK DEBLOAT)     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Desativar o RasMan pode quebrar o recurso de 'Ponto de Acesso Móvel' (Compartilhar Internet) em notebooks."

 $LogTweaks = @()

# ==============================================================================
# 1. MATRIZ EXPANDIDA DE SERVIÇOS DE TÚNEL E PROXY
# ==============================================================================
 $NetworkServices = @(
    # --- Matriz Original (VPN) ---
    "RasMan",    # Remote Access Connection Manager (Gerencia VPN e Discagem)
    "SstpSvc",   # Secure Socket Tunneling Protocol Service (Túnel SSL/TLS)
    "Ikeext",    # IKE and AuthIP IPsec Keyring Modules (Autenticação VPN)
    "RasAuto",   # Remote Access Auto Connection Manager (Disparador automático)
    
    # --- NOVAS FEATURES (Redes Corporativas/legadas) ---
    "iphlpsvc",  # IP Helper (Gerencia túneis 6to4, ISATAP e Port Proxy para IPv6. Inútil em redes domésticas puras)
    "WinHttpAutoProxySvc" # Descoberta Automática de Proxy (WPAD). Fica enviando pacotes na rede local procurando servidores Proxy)
)

# ==============================================================================
# 2. LOOP DE OTIMIZAÇÃO E BLOQUEIO (COM VALIDAÇÃO DE ESTADO)
# ==============================================================================
Write-Host "`n[*] Verificando daemons de rede..." -ForegroundColor DarkGray

foreach ($ServiceName in $NetworkServices) {
    $ServiceInstance = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($ServiceInstance) {
        $changed = $false
        
        # Se estiver rodando, manda o sinal de parada sem travar o script (-NoWait)
        if ($ServiceInstance.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction SilentlyContinue
            $changed = $true
        }
        
        # Só altera o StartType se não for 'Disabled' (Economiza I/O do Registro)
        if ($ServiceInstance.StartType -ne 'Disabled') {
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
            $changed = $true
        }

        # Mapeia nomes feios para nomes amigáveis no Log
        $FriendlyName = switch ($ServiceName) {
            "RasMan"               { "VPN: Remote Access Manager" }
            "SstpSvc"              { "VPN: SSTP Tunneling" }
            "Ikeext"               { "VPN: IPsec Keyring" }
            "RasAuto"              { "VPN: Auto Connection" }
            "iphlpsvc"             { "IPv6: IP Helper (Túneis)" }
            "WinHttpAutoProxySvc"  { "Proxy: WPAD Discovery" }
            default                { $ServiceName }
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $FriendlyName"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $FriendlyName"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } else {
        # CORREÇÃO: Adicionado log para quando o serviço não existir, mantendo o relatório completo
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Não presente neste PC"; Status = "OK" }
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

Write-Host "`n[!] NOTA: Alguns serviços de rede são interdependentes. Eles foram marcados como 'Disabled' e não iniciarão mais no boot, mas o processo real de limpeza de memória será concluído após a REINICIALIZAÇÃO do computador.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"