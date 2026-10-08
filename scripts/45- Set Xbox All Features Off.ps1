# ==============================================================================
# PURGA DA INFRAESTRUTURA XBOX E GAME PASS (SERVIÇOS E REDE)
# Contexto: Desativação completa do ecossistema Xbox para liberar RAM, CPU e 
# fechar portas de rede P2P (Teredo) usadas pelo Xbox Live em segundo plano.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para desativar serviços do sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "           PURGA DO ECOSISTEMA XBOX E GAME PASS (SERVIÇOS)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. MATRIZ EXPANDIDA DE SERVIÇOS (INCLUINDO GAMING SERVICES)
# ==============================================================================
Write-Host "`n[*] Verificando serviços do ecossistema Xbox..." -ForegroundColor DarkGray

 $XboxServices = @(
    "XblAuthManager",  # Gerenciador de Autenticação
    "XblGameSave",     # Salva-jogos em nuvem
    "XboxNetApiSvc",   # Rede do Xbox Live (Teredo P2P)
    "XboxGipSvc",      # Acessórios e periféricos
    "GamingServices"   # Serviço principal do Xbox App / Game Pass (Win11)
)

foreach ($ServiceName in $XboxServices) {
    $ServiceInstance = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($ServiceInstance) {
        try {
            $changed = $false
            
            if ($ServiceInstance.Status -eq 'Running') {
                Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction Stop
                $changed = $true
            }
            
            if ($ServiceInstance.StartType -ne 'Disabled') {
                Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction Stop
                $changed = $true
            }

            if ($changed) {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
            } else {
                $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Já estava desativado"; Status = "OK" }
            }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Falha ao desativar (Protegido?)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Não instalado neste PC"; Status = "OK" }
    }
}

# ==============================================================================
# 2. REMOÇÃO DE AUTO-START DO XBOX APP
# Contexto: Mesmo com os serviços desativados, o instalador do Xbox deixa resíduos 
# na chave 'Run' do registro. Se você abrir o Xbox App uma vez, ele adiciona chaves 
# ali que tentam pre-carregar a UI na memória no próximo boot.
# ==============================================================================
Write-Host "[*] Limpando chaves de inicialização automática do Xbox..." -ForegroundColor DarkGray

 $RunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
 $XboxRunKeys = @("XboxApp", "XboxGameCallableUI")

foreach ($key in $XboxRunKeys) {
    try {
        $regKey = Get-ItemProperty -Path $RunPath -Name $key -ErrorAction Stop
        if ($null -ne $regKey) {
            Remove-ItemProperty -Path $RunPath -Name $key -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "AutoStart: $key"; Acao = "Removido do Registro"; Status = "SUCESSO" }
        }
    } catch {
        # Se cair aqui, a chave provavelmente não existe (ignorado silenciosamente)
        $LogTweaks += [PSCustomObject]@{ Feature = "AutoStart: $key"; Acao = "Já estava limpo"; Status = "OK" }
    }
}

# ==============================================================================
# 3. BLOQUEIO DE REDE XBOX NO FIREWALL (FECHAR PORTAS P2P)
# Contexto: O XboxNetApiSvc abre portas específicas e mantém a interface "Teredo" 
# ativa para comunicação P2P. Bloquear o executável principal no firewall garante 
# que, mesmo que o serviço seja ativado acidentalmente, ele não poderá enviar/receber 
# tráfego de rede não solicitado.
# ==============================================================================
Write-Host "[*] Configurando regras de bloqueio de rede do Xbox..." -ForegroundColor DarkGray

 $FwRuleName = "Block_Xbox_Ecosystem"
 $FwExePath = "$env:WinDir\System32\XblAuthManager.exe"

try {
    $existingRule = Get-NetFirewallRule -DisplayName $FwRuleName -ErrorAction SilentlyContinue
    if (-not $existingRule) {
        $null = New-NetFirewallRule -DisplayName $FwRuleName -Direction Outbound -Action Block -Program $FwExePath -Enabled True -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Firewall: Xbox Outbound"; Acao = "Tráfego de saída bloqueado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Firewall: Xbox Outbound"; Acao = "Já estava bloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Firewall: Xbox Outbound"; Acao = "Falha ao aplicar (Permissão?)"; Status = "ERRO" }
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
Write-Host "1. Se você utiliza o 'PC Game Pass' (Xbox App) para jogar jogos como Forza ou Flight Simulator, NÃO rode este script." -ForegroundColor Red
Write-Host "2. Esses jogos dependem estritamente do serviço 'GamingServices' e da rede do Xbox para validação de licença DRM.`n" -ForegroundColor Yellow

Read-Host "Pressione ENTER para fechar"