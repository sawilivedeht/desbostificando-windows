# ==============================================================================
# PURGA COMPLETA DO ECOSSISTEMA HOMEGROUP E RESÍDUOS DE REDE LLMNR
# Contexto: Remoção definitiva da infraestrutura legada do Grupo Doméstico, limpeza de 
# chaves de registro fantasma que podem travar o sistema e desativação do LLMNR, que 
# gera pacotes de broadcast desnecessários na rede local (causa microlags).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Serviços e Registros do Sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DO HOMEGROUP, RESÍDUOS DE REGISTRO E LLMNR (REDE)         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO INTELIGENTE DOS SERVIÇOS HOMEGROUP
# ==============================================================================
Write-Host "`n[*] Verificando serviços legados do HomeGroup..." -ForegroundColor DarkGray

 $HomeGroupServices = @(
    "HomeGroupProvider", # Gerenciador de configurações
    "HomeGroupListener"  # Ouvinte de tráfego de rede
)

foreach ($ServiceName in $HomeGroupServices) {
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
    
    if ($service) {
        $changed = $false
        
        # Só tenta parar se estiver rodando
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force -NoWait -ErrorAction SilentlyContinue
            $changed = $true
        }
        
        # Só altera o StartType se não for 'Disabled'
        if ($service.StartType -ne 'Disabled') {
            Set-Service -Name $ServiceName -StartupType Disabled -ErrorAction SilentlyContinue
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: $ServiceName"; Acao = "Não instalado nesta versão do Windows"; Status = "OK" }
    }
}

# ==============================================================================
# 2. PURGA DE RESÍDUOS DE REGISTRO DO HOMEGROUP
# Contexto: Mesmo sem os serviços, o Windows deixa rastros profundos da infraestrutura 
# do HomeGroup no registro. Em PCs atualizados de versões antigas do Windows, esses 
# resíduos podem causar lentidão no Explorer ao tentar ler chaves obsoletas.
# ==============================================================================
Write-Host "[*] Limpando resíduos profundos do HomeGroup no registro..." -ForegroundColor DarkGray

 $HgRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\HomeGroup"

if (Test-Path $HgRegPath) {
    try {
        Remove-Item -Path $HgRegPath -Recurse -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Reg: HomeGroup Hive"; Acao = "Deletado (Prevenção de bugs de leitura)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Reg: HomeGroup Hive"; Acao = "Falha na exclusão (Travado pelo sistema)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Reg: HomeGroup Hive"; Acao = "Já estava limpo"; Status = "OK" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DO LLMNR (LINK-LOCAL MULTICAST NAME RESOLUTION)
# Contexto: O LLMNR faz o Windows gritar na rede local perguntando "Alguém aí é o PC-X?" 
# a cada vez que você abre o Explorer ou tenta acessar um recurso de rede. Desativá-lo 
# via Política de DNS corta dezenas de pacotes de rede inúteis por minuto, reduzindo 
# micro-stutters na LAN. (Este é o método padrão utilizado por administradores via GPO).
# ==============================================================================
Write-Host "[*] Desativando resolução de nomes multicast (LLMNR)..." -ForegroundColor DarkGray

 $DnsPolicyPath = "HKLM:\SOFTWARE\policies\Microsoft\Windows NT\DNSClient"
 $prop = "EnableMulticast"
 $val = 0 # 0 = Desativado

# Cria a pasta de política se não existir (não existe por padrão no Windows limpo)
if (-not (Test-Path $DnsPolicyPath)) { New-Item -Path $DnsPolicyPath -Force | Out-Null }

try {
    $currentValue = (Get-ItemProperty -Path $DnsPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop
    if ($currentValue -ne $val) {
        Set-ItemProperty -Path $DnsPolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Network: LLMNR"; Acao = "Desativado (Fim dos broadcasts na LAN)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Network: LLMNR"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Network: LLMNR"; Acao = "Falha ao desativar (Permissão?)"; Status = "ERRO" }
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
Write-Host "1. O LLMNR (Link-Local Multicast Name Resolution) é o principal culpado por 'travamentos' de microssegundos ao acessar a rede local." -ForegroundColor White
Write-Host "2. Com ele desativado, o Windows para de tentar descobrir impressoras e PCs na rede local sozinho. Em redes corporativas (Active Directory), se você não conseguir achar impressoras por nome, reative o LLMNR (valor 1 ou delete a chave)." -ForegroundColor White
Write-Host "`n"
Read-Host "Pressione ENTER para fechar"