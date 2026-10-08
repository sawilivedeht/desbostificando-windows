# ==============================================================================
# OTIMIZAÇÃO DE I/O DE DISCO: DESATIVAÇÃO DE SERVIÇOS DE MANUTENÇÃO EM SEGUNDO PLANO
# Contexto: Evitar picos de leitura/escrita (I/O Spikes) que causam micro-stutters
# em jogos ou aplicativos pesados ao rodar em segundo plano.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas e Tarefas Agendadas."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    HARDENING DE I/O: STORAGE SENSE E OTIMIZAÇÃO DE DISCO           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DO STORAGE SENSE VIA POLÍTICA DE GRUPO (GPO - HKLM)
# ==============================================================================
Write-Host "`n[*] Configurando Storage Sense via GPO (HKLM)..." -ForegroundColor DarkGray

 $StorageSenseGPOPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"
if (-not (Test-Path $StorageSenseGPOPath)) { New-Item -Path $StorageSenseGPOPath -Force | Out-Null }

# Usando HashTable para evitar repetição de código (Boa prática)
 $GPOProps = @{
    "AllowStorageSenseGlobal"             = 0
    "AllowStorageSenseTemporaryFilesCleanup" = 0
}

foreach ($prop in $GPOProps.Keys) {
    $val = $GPOProps[$prop]
    try {
        if ((Get-ItemProperty -Path $StorageSenseGPOPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $StorageSenseGPOPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense GPO ($prop)"; Acao = "Bloqueado via Política"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense GPO ($prop)"; Acao = "Já estava bloqueado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense GPO ($prop)"; Acao = "Erro de permissão no registro"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. REDUNDÂNCIA: DESATIVAÇÃO NO NÍVEL DE USUÁRIO (HKCU)
# Contexto: Garante que mesmo que a GPO seja ignorada por alguma atualização do Windows,
# a chave de usuário impedirá a execução do motor.
# ==============================================================================
Write-Host "[*] Configurando Storage Sense via Registro de Usuário (HKCU)..." -ForegroundColor DarkGray

 $StorageSenseUserPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense"
if (-not (Test-Path $StorageSenseUserPath)) { New-Item -Path $StorageSenseUserPath -Force | Out-Null }

 $prop = "StorageSenseEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $StorageSenseUserPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $StorageSenseUserPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense (User Level)"; Acao = "Desativado para o usuário"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense (User Level)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Storage Sense (User Level)"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 3. DESATIVAR OTIMIZAÇÃO DE DISCO AGENDADA (DEFRAG/SysMain)
# Contexto: O Windows agenda otimizações semanais. Quando essa tarefa acorda 
# inesperadamente ou enquanto você joga, causa graves "congelões" de disco.
# ==============================================================================
Write-Host "[*] Verificando tarefas agendadas de manutenção de disco..." -ForegroundColor DarkGray

 $TaskPath = "\Microsoft\Windows\Defrag\"
 $TaskName = "ScheduledDefrag"

try {
    $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction Stop
    
    if ($task.State -ne "Disabled") {
        try {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskPath -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Otimização de Disco (Task)"; Acao = "Tarefa agendada DESATIVADA"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Otimização de Disco (Task)"; Acao = "Falha ao desativar (Acesso negado?)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Otimização de Disco (Task)"; Acao = "Já estava desativada"; Status = "OK" }
    }
} catch {
    # Se a tarefa não existir (comum em versões LTSC ou alteradas por ferramentas de debloat)
    $LogTweaks += [PSCustomObject]@{ Feature = "Otimização de Disco (Task)"; Acao = "Tarefa não encontrada"; Status = "INFO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Para discos SSD modernos (NVMe), a desfragmentação tradicional é desnecessária e apenas gasta ciclos de vida útil e I/O. O TRIM já é gerenciado pelo próprio controlador do SSD em nível de hardware.`n" -ForegroundColor Yellow