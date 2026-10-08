# ==============================================================================
# PURGA DE POLITICAS DE SISTEMA DE ARQUIVOS E RASTREAMENTO DE DISCO (I/O)
# Contexto: Desativação de subsistemas de monitoramento de disco (Quotas) e criação 
# de snapshots em tempo real (VSS) que causam overhead de I/O desnecessário em 
# Desktops e PCs Gamer, onde o backup costuma ser feito por softwares de terceiros.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas de Disco."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      PURGA DE COTAS DE DISCO E SNAPSHOT SERVICE (VSS / DEDUP)         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DE COTAS DE DISCO NTFS (GPO MIRROR)
# ==============================================================================
Write-Host "`n[*] Desativando políticas de Cotas de Disco..." -ForegroundColor DarkGray

 $QuotaPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DiskQuota"
if (-not (Test-Path $QuotaPolicyPath)) { New-Item -Path $QuotaPolicyPath -Force | Out-Null }

 $QuotaSettings = @{
    "Enable"     = 0 # Desativa o monitoramento
    "Enforce"    = 0 # Impede limites estritos
    "LogWarning" = 0 # Desativa logs de aviso no Event Viewer
}

foreach ($setting in $QuotaSettings.Keys) {
    $val = $QuotaSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $QuotaPolicyPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $QuotaPolicyPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Disk Quota $setting"; Acao = "Definido para $val"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Disk Quota $setting"; Acao = "Já estava correto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Disk Quota $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. DESATIVAÇÃO DO VOLUME SHADOW COPY (VSS)
# Contexto: O serviço VSS cria "cópias de sombra" em tempo real para o System Restore. 
# Isso significa que para CADA arquivo que você salva ou modifica, o VSS cria um bloco 
# de dados paralelo. Em SSDs NVMe, isso duplica o I/O de gravação e causa "stutters" 
# perceptíveis ao salvar trabalhos pesados ou em jogos que gravam logs/save states.
# ==============================================================================
Write-Host "[*] Desativando Serviço de Cópia de Sombra (VSS)..." -ForegroundColor DarkGray

try {
    $VssSvc = Get-Service -Name "VSS" -ErrorAction SilentlyContinue
    if ($VssSvc) {
        $changed = $false
        if ($VssSvc.Status -eq 'Running') { Stop-Service -Name "VSS" -Force -NoWait -ErrorAction SilentlyContinue }
        if ($VssSvc.StartType -ne 'Disabled') {
            Set-Service -Name "VSS" -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Volume Shadow Copy"; Acao = "Desativado (Redução massiva de I/O)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Volume Shadow Copy"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Volume Shadow Copy"; Acao = "Não presente neste PC"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Volume Shadow Copy"; Acao = "Falha ao desativar (Protegido?)"; Status = "ERRO" }
}

# ==============================================================================
# 3. DESATIVAÇÃO DA DESDUPLICAÇÃO DE DADOS (DEDUP)
# Contexto: O Data Deduplication é um serviço de servidor que escaneia o disco inteiro 
# procurando por blocos de arquivos idênticos para economizar espaço. Em PCs 
# comuns, ele não faz nada útil, mas se estiver habilitado por engano, consumirá 
# muita CPU e RAM em segundo plano.
# ==============================================================================
Write-Host "[*] Verificando serviço de Desduplicação de Dados..." -ForegroundColor DarkGray

try {
    $DedupSvc = Get-Service -Name "DedupSvc" -ErrorAction SilentlyContinue
    if ($DedupSvc) {
        $changed = $false
        if ($DedupSvc.Status -eq 'Running') { Stop-Service -Name "DedupSvc" -Force -NoWait -ErrorAction SilentlyContinue }
        if ($DedupSvc.StartType -ne 'Disabled') {
            Set-Service -Name "DedupSvc" -StartupType Disabled -ErrorAction Stop
            $changed = $true
        }

        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Data Deduplication"; Acao = "Desativado (Economia de CPU/RAM)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Data Deduplication"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Data Deduplication"; Acao = "Não presente (Padrão em Desktops)"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Data Deduplication"; Acao = "Falha ao desativar"; Status = "ERRO" }
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
Write-Host "1. CRÍTICO: Ao desativar o VSS, a função 'Restauração do Sistema' nativa do Windows será completamente quebrada e não poderá mais criar pontos de restauração." -ForegroundColor Red
Write-Host "2. Se você depende do 'Restauração do Sistema' para corrigir problemas do Windows, NÃO rode este script, ou utilize um software de backup de terceiros (ex: Macrium Reflect).`n" -ForegroundColor Yellow

Read-Host "Pressione ENTER para fechar"