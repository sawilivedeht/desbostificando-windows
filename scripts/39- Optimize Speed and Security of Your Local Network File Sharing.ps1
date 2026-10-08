# ==============================================================================
# OTIMIZAÇÃO AVANÇADA DO PROTOCOLO SMB (NAS / REDE LOCAL / LOW-LATENCY)
# Contexto: Remoção do legado SMBv1, ajuste fino de cache de metadados para 
# reduzir atrasos no Explorer, e desativação de criptografia para ganho bruto 
# de velocidade (Throughput) em redes locais domésticas confiáveis.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar configurações de Rede e Servidor."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        HARDENING E OTIMIZAÇÃO DE PROTOCOLO SMB (NAS / LAN)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. REMOÇÃO SEGURA E INTELIGENTE DO SMBv1 (SEGURANÇA)
# ==============================================================================
Write-Host "`n[*] Verificando presença do protocolo legado SMBv1..." -ForegroundColor DarkGray

# A. Desativa no Servidor (Sem precisar de reboot)
 $smbConfig = Get-SmbServerConfiguration
if ($smbConfig.EnableSMB1Protocol -eq $true) {
    try {
        Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Server"; Acao = "Desativado (Anti-Ransomware)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Server"; Acao = "Falha ao desativar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Server"; Acao = "Já estava desativado"; Status = "OK" }
}

# B. Remove o Cliente do Windows (Pode exigir Reboot)
 $smbFeature = Get-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -ErrorAction SilentlyContinue
if ($smbFeature -and $smbFeature.State -ne "Disabled") {
    try {
        Disable-WindowsOptionalFeature -Online -FeatureName "SMB1Protocol" -NoRestart -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Client (Feature)"; Acao = "Removido (Pode exigir Reboot)"; Status = "SUCESSO" }
    } catch {
        if ($_.Exception.Message -match "restart is required") {
            $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Client (Feature)"; Acao = "Pendente (Reboot necessário)"; Status = "AVISO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Client (Feature)"; Acao = "Falha na remoção"; Status = "ERRO" }
        }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMBv1 Client (Feature)"; Acao = "Já estava removido"; Status = "OK" }
}

# ==============================================================================
# 2. OTIMIZAÇÃO DE HARDWARE E THROUGHPUT (SMBv2 / SMBv3)
# ==============================================================================
Write-Host "[*] Configurando offloads de hardware SMBv2/v3..." -ForegroundColor DarkGray

# Large MTU (Pacotes Jumbo) no Cliente
 $smbClient = Get-SmbClientConfiguration
if ($smbClient.EnableLargeMtu -ne $true) {
    try {
        Set-SmbClientConfiguration -EnableLargeMtu $true -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: Large MTU"; Acao = "Ativado"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: Large MTU"; Acao = "Falha ao aplicar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: Large MTU"; Acao = "Já estava ativado"; Status = "OK" }
}

# Multi-Channel no Servidor (Agregação de links / Múltiplas placas)
 $smbConfig = Get-SmbServerConfiguration # Atualiza variável
if ($smbConfig.EnableMultiChannel -ne $true) {
    try {
        Set-SmbServerConfiguration -EnableMultiChannel $true -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Multi-Channel"; Acao = "Ativado"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Multi-Channel"; Acao = "Falha ao aplicar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Multi-Channel"; Acao = "Já estava ativado"; Status = "OK" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DE CRIPTOGRAFIA SMB (GANHO DE CPU E VELOCIDADE)
# Contexto: O SMBv3 criptografa tudo por padrão (AES-CCM). Em uma rede local caseira 
# confiável (sem hackers na sua rede doméstica), isso consome de 10% a 20% da CPU 
# do NAS e do PC, limitando a velocidade de transferência em conexões de 2.5G/10G.
# ==============================================================================
Write-Host "[*] Configurando criptografia SMB (Foco em velocidade pura de LAN)..." -ForegroundColor DarkGray

if ($smbConfig.EncryptData -ne $false) {
    try {
        Set-SmbServerConfiguration -EncryptData $false -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Encryption"; Acao = "DESATIVADA (Max Throughput LAN)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Encryption"; Acao = "Falha ao desativar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMB Server: Encryption"; Acao = "Já estava desativada"; Status = "OK" }
}

# ==============================================================================
# 4. OTIMIZAÇÃO DE COMANDOS SIMULTÂNEOS (COPIA DE ARQUIVOS RÁPIDA)
# ==============================================================================
if ($smbClient.MaxCmds -lt 2048) {
    try {
        Set-SmbClientConfiguration -MaxCmds 2048 -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: MaxCmds"; Acao = "Aumentado para 2048"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: MaxCmds"; Acao = "Falha ao aplicar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "SMB Client: MaxCmds"; Acao = "Já estava otimizado"; Status = "OK" }
}

# ==============================================================================
# 5. AJUSTE FINO DE CACHE DE METADADOS (CORREÇÃO CRÍTICA)
# ==============================================================================
Write-Host "[*] Ajustando tempos de cache do Windows Explorer (Rede)..." -ForegroundColor DarkGray

 $SmbClientPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
if (-not (Test-Path $SmbClientPath)) { New-Item -Path $SmbClientPath -Force | Out-Null }

# CORREÇÃO: Usar 0 destrói a performance da rede e do servidor NAS. 
# Usar 3 segundos garante que pastas de rede pareçam "ao vivo" (sem atrasos visuais), 
# mas evita que o Windows faça DDoS no seu servidor pedindo os metadados a cada clique.
 $CacheSettings = @{
    "FileInfoCacheLifetime"      = 3
    "FileNotFoundCacheLifetime"  = 3
    "DirectoryCacheLifetime"     = 3
}

foreach ($setting in $CacheSettings.Keys) {
    $prop = $setting
    $val = $CacheSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $SmbClientPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $SmbClientPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Cache: $setting"; Acao = "Ajustado para ${val}s (Anti-Lag seguro)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Cache: $setting"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Cache: $setting"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
}

# Aumenta o tamanho do cache de diretórios para listar pastas grandes de NAS instantaneamente
 $prop = "DirectoryCacheEntryMaxSize"
 $val = 64
try {
    if ((Get-ItemProperty -Path $SmbClientPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SmbClientPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Cache: Dir Entry Max Size"; Acao = "Aumentado para 64 (Listagem rápida)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Cache: Dir Entry Max Size"; Acao = "Já estava otimizado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Cache: Dir Entry Max Size"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
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
Write-Host "1. A desativação da criptografia SMB é SEGURA apenas em redes caseiras (seu roteador Wi-Fi). NÃO faça isso em redes corporativas ou VPNs." -ForegroundColor White
Write-Host "2. Se você desativou o cliente SMBv1 agora, recomenda-se REINICIAR o computador para limpar os drivers de rede da memória." -ForegroundColor White
Write-Host "3. O cache de 3 segundos evita que o Explorer trave ao acessar pastas de NAS, mas não sobrecarrega o servidor de rede como o valor '0' fazia.`n" -ForegroundColor White

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"