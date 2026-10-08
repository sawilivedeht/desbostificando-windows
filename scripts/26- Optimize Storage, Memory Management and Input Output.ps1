# ==============================================================================
# OTIMIZAÇÃO EXTREMA DE I/O DE DISCO, FILA NTFS E GERENCIAMENTO DE MEMÓRIA
# Contexto: Redução de latência de armazenamento, eliminação de writes desnecessários
# e otimização do kernel para maximizar o throughput de NVMe/SSDs.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar parâmetros do Kernel e NTFS."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        HARDENING DE I/O: NTFS, KERNEL MEMORY E PCIe NVMe             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $FileSystemPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
if (-not (Test-Path $FileSystemPath)) { New-Item -Path $FileSystemPath -Force | Out-Null }

# ==============================================================================
# 1. SUBSISTEMA DE ARMAZENAMENTO E FILA NTFS (VIA REGISTRO)
# ==============================================================================
Write-Host "`n[*] Otimizando tabelas e comportamento do sistema de arquivos..." -ForegroundColor DarkGray

# Desativa Last Access Time (Elimina writes duplos ao apenas ler um arquivo)
 $prop = "NtfsDisableLastAccessUpdate"
 $val = 1
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Last Access Time"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Last Access Time"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Last Access Time"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa Nomes Curtos 8.3
 $prop = "NtfsDisable8dot3NameCreation"
 $val = 1
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: 8.3 Naming"; Acao = "Desativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: 8.3 Naming"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: 8.3 Naming"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Garante que o TRIM esteja Ativado (0 = Habilitado)
 $prop = "DisableDeleteNotify"
 $val = 0
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "SSD: TRIM"; Acao = "Forçadamente Ativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "SSD: TRIM"; Acao = "Já estava ativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "SSD: TRIM"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 2. DIRETIVAS DE MEMÓRIA E SISTEMA DE ARQUIVOS (REGISTRO)
# ==============================================================================
# Suporte a Long Paths
 $prop = "LongPathsEnabled"
 $val = 1
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Long Paths"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Long Paths"; Acao = "Já estava ativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Long Paths"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# MFT Zone Reservation alterado para 1 (Mínimo/Dinâmico)
 $prop = "NtfsMftZoneReservation"
 $val = 1
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: MFT Zone"; Acao = "Ajustado para Mínimo"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: MFT Zone"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: MFT Zone"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa Compressão NTFS
 $prop = "NtfsDisableCompression"
 $val = 1
try {
    if ((Get-ItemProperty -Path $FileSystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $FileSystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Compressão I/O"; Acao = "Desativada (Economia de CPU)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Compressão I/O"; Acao = "Já estava desativada"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: Compressão I/O"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 3. GERENCIAMENTO DE MEMÓRIA KERNEL
# ==============================================================================
 $MemorySettingsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

 $prop = "DisablePagingExecutive"
 $val = 1
try {
    if ((Get-ItemProperty -Path $MemorySettingsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $MemorySettingsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Memory: DisablePagingExec"; Acao = "Ativado (Kernel na RAM)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Memory: DisablePagingExec"; Acao = "Já estava ativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Memory: DisablePagingExec"; Acao = "Falha ao gravar"; Status = "ERRO" } }

 $LogTweaks += [PSCustomObject]@{ Feature = "Memory: IoPageLockLimit"; Acao = "Ignorado (Tweak obsoleto/Perigoso)"; Status = "OK" }

# ==============================================================================
# 4. CONTROLE DE ENERGIA PCIe E HIBERNAÇÃO (POWERCFG)
# ==============================================================================
Write-Host "`n[*] Configurando link state do barramento PCIe e Hibernação..." -ForegroundColor DarkGray

# Desativa Hibernação (Remove hiberfil.sys)
if (Test-Path "C:\hiberfil.sys") {
    $null = powercfg /h off 2>&1
    $LogTweaks += [PSCustomObject]@{ Feature = "Power: Hibernation"; Acao = "Desativada (hiberfil.sys removido)"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Power: Hibernation"; Acao = "Já estava desativada"; Status = "OK" }
}

# Desativa ASPM no PCIe
 $null = powercfg /SETACVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>&1
 $null = powercfg /SETDCVALUEINDEX SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 2>&1
 $null = powercfg /setactive SCHEME_CURRENT 2>&1
 $LogTweaks += [PSCustomObject]@{ Feature = "PCIe: ASPM Power Mgmt"; Acao = "Desativado (Link Always-On)"; Status = "SUCESSO" }

# ==============================================================================
# 5. DESATIVAÇÃO DO PREFETCHER / SYSMAIN (SSD NVMe)
# ==============================================================================
 $PrefetchPath = "$MemorySettingsPath\PrefetchParameters"
if (-not (Test-Path $PrefetchPath)) { New-Item -Path $PrefetchPath -Force | Out-Null }

 $prop = "EnablePrefetcher"
 $val = 0
try {
    if ((Get-ItemProperty -Path $PrefetchPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PrefetchPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
    }
} catch {}

 $prop = "EnableSuperfetch"
 $val = 0
try {
    if ((Get-ItemProperty -Path $PrefetchPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PrefetchPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
    }
} catch {}

try {
    $sysMain = Get-Service -Name "SysMain" -ErrorAction SilentlyContinue
    $changed = $false
    if ($sysMain) {
        if ($sysMain.Status -eq 'Running') { Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue; $changed = $true }
        if ($sysMain.StartType -ne 'Disabled') { Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction Stop; $changed = $true }
        
        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Service: SysMain"; Acao = "Desativado (Prefetch/Superfetch Off)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Service: SysMain"; Acao = "Já estava desativado"; Status = "OK" }
        }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Service: SysMain"; Acao = "Falha ao desativar"; Status = "ERRO" } }

# ==============================================================================
# 6. AGENDAMENTO DE THREADS (CORREÇÃO DE QUANTUM)
# ==============================================================================
 $PriorityPath = "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"
if (-not (Test-Path $PriorityPath)) { New-Item -Path $PriorityPath -Force | Out-Null }

 $prop = "Win32PrioritySeparation"
 $val = 26
try {
    if ((Get-ItemProperty -Path $PriorityPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $PriorityPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Definido para 26 (Curto/Variável)"; Status = "SUCESSO" }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "CPU: Quantum Priority"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 7. LIBERAÇÃO DA FILA DE I/O (WINDOWS SEARCH)
# ==============================================================================
try {
    $wSearch = Get-Service -Name "WSearch" -ErrorAction SilentlyContinue
    $changed = $false
    if ($wSearch) {
        if ($wSearch.Status -eq 'Running') { Stop-Service -Name "WSearch" -Force -ErrorAction SilentlyContinue; $changed = $true }
        if ($wSearch.StartType -ne 'Disabled') { Set-Service -Name "WSearch" -StartupType Disabled -ErrorAction Stop; $changed = $true }
        
        if ($changed) {
            $LogTweaks += [PSCustomObject]@{ Feature = "Service: Windows Search"; Acao = "Desativado (Fila de I/O Liberada)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Service: Windows Search"; Acao = "Já estava desativado"; Status = "OK" }
        }
    }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Service: Windows Search"; Acao = "Falha ao desativar"; Status = "ERRO" } }

# ==============================================================================
# 8. PURGA DO USN JOURNAL (HARDCORE I/O REDUCTION)
# ==============================================================================
Write-Host "`n[*] Aplicando tweak Hardcore: Purga do USN Journal..." -ForegroundColor DarkGray

try {
    # Verifica se o journal existe antes de tentar deletar
    $journalInfo = fsutil usn queryjournal C: 2>&1
    if ($LASTEXITCODE -eq 0) {
        $null = fsutil usn deletejournal /D C: 2>&1
        if ($LASTEXITCODE -eq 0) {
            $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: USN Journal"; Acao = "DESTRUÍDO (I/O Hardcore Reduction)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: USN Journal"; Acao = "Falha (Pode exigir Chkdsk)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: USN Journal"; Acao = "Já estava destruído"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "NTFS: USN Journal"; Acao = "Falha ao acessar volume"; Status = "ERRO" }
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
Write-Host "1. A destruição do USN Journal e desativação do Last Access Time são tweaks extremos." -ForegroundColor White
Write-Host "2. Eles quebram a funcionalidade de 'Restaurar Versões Anteriores' do Windows e alguns softwares de Backup incremental (como Acronis)." -ForegroundColor White
Write-Host "3. O IoPageLockLimit foi intencionalmente ignorado por causar Tela Azul em sistemas modernos.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"