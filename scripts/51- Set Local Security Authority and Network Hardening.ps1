# ==============================================================================
# HARDENING DE AUTENTICAÇÃO LSA E PROTEÇÃO ANTI-CREDENTIAL DUMPING
# Contexto: Fechamento de vetores de ataques de autenticação (NTLM Relay, 
# Pass-the-Hash, Mimikatz) e proteção de credenciais em repouso (Disco/Memória).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar as políticas LSA."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      HARDENING LSA, PROTOCOLOS NTLM E PROTEÇÃO DE MEMÓRIA          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. CONFIGURAÇÕES CORE DO LSA (NTLM, NULL SESSIONS, ETC)
# ==============================================================================
 $LsaPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
if (-not (Test-Path $LsaPath)) { New-Item -Path $LsaPath -Force | Out-Null }

 $LsaSettings = @{
    "RestrictAnonymous"    = 1  # Bloqueia enumeração anônima de contas/compartilhamentos
    "RestrictAnonymousSAM" = 1 # Bloqueia enumeração anônima de permissões da SAM
    "NoLMHash"             = 1  # Impede armazenamento de hashes LM (extremamente fracos)
    "LmCompatibilityLevel" = 5 # Força apenas NTLMv2 (Recusa LM e NTLMv1)
}

foreach ($setting in $LsaSettings.Keys) {
    $val = $LsaSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $LsaPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $LsaPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "LSA: $setting"; Acao = "Configurado para $val"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "LSA: $setting"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: $setting"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. PROTEÇÃO ANTI-MIMIKATZ (RUN AS PPL)
# Contexto: O RunAsPPL (Protection Process Light) impede que processos não assinados 
# pela Microsoft leiam a memória do lsass.exe. É a defesa nº1 contra roubo de senhas.
# ==============================================================================
Write-Host "`n[*] Aplicando proteção avançada de memória (Anti-Mimikatz)..." -ForegroundColor DarkGray

 $prop = "RunAsPPL"
 $val = 1
try {
    if ((Get-ItemProperty -Path $LsaPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LsaPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RunAsPPL"; Acao = "Ativado (Memória do LSASS Protegida)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RunAsPPL"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RunAsPPL"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 3. BLOQUEIO DE CONSULTA REMOTA DA SAM (RPC RESTRICTIONS)
# Contexto: Impede que computadores na rede local consultem o seu banco de dados 
# de usuários (SAM) via RPC, mitigando ataques de enumeração de rede.
# ==============================================================================
 $prop = "RestrictRemoteSAM"
 $val = "O:BAG:BAD:(A;;RC;;;BA)" # Permite apenas Administradores locais
try {
    if ((Get-ItemProperty -Path $LsaPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LsaPath -Name $prop -Value $val -Type String -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RestrictRemoteSAM"; Acao = "Restrito apenas para Admins"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RestrictRemoteSAM"; Acao = "Já estava restrito"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "LSA: RestrictRemoteSAM"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 4. DESATIVAR CACHE DE LOGON DE DOMÍNIO (CACHEDLOGONSCOUNT)
# Contexto: Se o PC for de uma rede corporativa (AD) e for roubado, o ladrão pode 
# extrair hashes de logons anteriores mesmo sem internet. 0 = Desativado.
# ==============================================================================
 $prop = "CachedLogonsCount"
 $val = 0
try {
    if ((Get-ItemProperty -Path $LsaPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $LsaPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: CachedLogonsCount"; Acao = "Definido para 0 (Sem cache de domínio)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "LSA: CachedLogonsCount"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "LSA: CachedLogonsCount"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 5. LIMPEZA DO ARQUIVO DE PAGINAÇÃO (REQUER CONFIRMAÇÃO)
# ==============================================================================
Write-Host "`n[!] ATENÇÃO: Limpeza do Pagefile (ClearPageFileAtShutdown)" -ForegroundColor Yellow
Write-Host "Se você tem 16GB+ de RAM, isso pode adicionar de 3 a 10 MINUTOS no tempo de desligamento do PC, pois o Windows precisa escrever zeros em todo o arquivo." -ForegroundColor DarkGray

# CORREÇÃO CRÍTICA: ClearPageFileAtShutdown pertence a Memory Management, não a Lsa
 $MemMgmtPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
if (-not (Test-Path $MemMgmtPath)) { New-Item -Path $MemMgmtPath -Force | Out-Null }

 $prop = "ClearPageFileAtShutdown"
 $confirmPagefile = Read-Host "Deseja ativar a limpeza do Pagefile no desligamento? (S/N)"

if ($confirmPagefile -eq 'S' -or $confirmPagefile -eq 's') {
    $val = 1
    try {
        if ((Get-ItemProperty -Path $MemMgmtPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $MemMgmtPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Ativado (Desligamento lento)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Já estava ativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
} else {
    # Garante que esteja desativado se o usuário não quiser
    $val = 0
    try {
        if ((Get-ItemProperty -Path $MemMgmtPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $MemMgmtPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Mantido DESATIVADO (Desligamento rápido)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Security: ClearPageFile"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
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

Write-Host "`n[!] NOTA: A ativação do 'RunAsPPL' (Proteção de Memória) exige uma REINICIALIZAÇÃO do sistema para que o Windows isole o processo lsass.exe de forma segura.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"