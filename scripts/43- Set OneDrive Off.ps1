# ==============================================================================
# OTIMIZAÇÃO DE SISTEMA: DESINSTALAÇÃO E BLOQUEIO DO ONEDRIVE
# Contexto: Encerra o processo, remove o ícone do Explorer, injeita bloqueio via 
# políticas de registro (GPO) e executa o desinstalador oficial em modo silencioso.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "          OTIMIZAÇÃO DE SISTEMA: DESINSTALAÇÃO DO ONEDRIVE           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsRestart = $false

# ==============================================================================
# 1. ENCERRAMENTO DOS PROCESSOS ATIVOS DO ONEDRIVE
# ==============================================================================
Write-Host "`n[*] Interrompendo instâncias ativas do OneDrive..." -ForegroundColor DarkGray

 $odProcess = Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue
if ($odProcess) {
    try {
        Stop-Process -Name "OneDrive" -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: OneDrive.exe"; Acao = "Finalizado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: OneDrive.exe"; Acao = "Falha ao finalizar (Permissão?)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Processo: OneDrive.exe"; Acao = "Não estava em execução"; Status = "OK" }
}

# ==============================================================================
# 2. INJEÇÃO DE DIRETIVAS DE BLOQUEIO NO REGISTRO (GPO Mirror)
# ==============================================================================
Write-Host "[*] Aplicando políticas de bloqueio via Registro..." -ForegroundColor DarkGray

 $OneDrivePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
if (-not (Test-Path $OneDrivePolicyPath)) { New-Item -Path $OneDrivePolicyPath -Recurse -Force | Out-Null }

 $prop = "DisableFileSyncNGSC"; $val = 1
try {
    if ((Get-ItemProperty -Path $OneDrivePolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $OneDrivePolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "GPO: DisableFileSync"; Acao = "Sincronização bloqueada globalmente"; Status = "SUCESSO" }
        $needsRestart = $true
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "GPO: DisableFileSync"; Acao = "Já estava bloqueada"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "GPO: DisableFileSync"; Acao = "Falha ao aplicar política"; Status = "ERRO" }
}

# ==============================================================================
# 3. REMOÇÃO DO ÍCONE E DO NÓ DO ONEDRIVE NO PAINEL LATERAL DO EXPLORER
# ==============================================================================
Write-Host "[*] Removendo ícone do OneDrive do Explorador de Arquivos..." -ForegroundColor DarkGray

 $ExplorerPaths = @(
    "HKLM:\SOFTWARE\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}",
    "HKLM:\SOFTWARE\Classes\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}"
)

 $prop = "System.IsPinnedToNameSpaceTree"; $val = 0

foreach ($Path in $ExplorerPaths) {
    $pathName = if ($Path -match "Wow6432Node") { "CLSID (Wow6432Node)" } else { "CLSID (Padrão)" }
    
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
    try {
        if ((Get-ItemProperty -Path $Path -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $Path -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Explorer Pin: $pathName"; Acao = "Ícone removido do painel lateral"; Status = "SUCESSO" }
            $needsRestart = $true
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Explorer Pin: $pathName"; Acao = "Ícone já estava oculto"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Explorer Pin: $pathName"; Acao = "Falha ao modificar registro"; Status = "ERRO" }
    }
}

# ==============================================================================
# 4. EXECUÇÃO DO DESINSTALADOR NATIVO
# ==============================================================================
Write-Host "[*] Executando desinstalador oficial do OneDrive..." -ForegroundColor DarkGray

 $uninstallPaths = @(
    "$env:SystemRoot\System32\OneDriveSetup.exe",
    "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
)

 $uninstalled = $false

foreach ($exePath in $uninstallPaths) {
    if (Test-Path $exePath) {
        try {
            Start-Process -FilePath $exePath -ArgumentList "/uninstall" -Wait -NoNewWindow -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Desinstalador: $([System.IO.Path]::GetFileName($exePath))"; Acao = "Executado com sucesso"; Status = "SUCESSO" }
            $uninstalled = $true
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Desinstalador: $([System.IO.Path]::GetFileName($exePath))"; Acao = "Falha na execução"; Status = "ERRO" }
        }
    }
}

if (-not $uninstalled) {
    $LogTweaks += [PSCustomObject]@{ Feature = "Desinstalador (Geral)"; Acao = "Executáveis não encontrados (Já desinstalado?)"; Status = "AVISO" }
}

# ==============================================================================
# 5. REINICIALIZAÇÃO CONDICIONAL DA INTERFACE
# ==============================================================================
if ($needsRestart) {
    Write-Host "[*] Consolidando mudanças na interface..." -ForegroundColor DarkGray
    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Reiniciado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Falha ao reiniciar"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Pulado (Sem necessidade)"; Status = "OK" }
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
Write-Host "1. O OneDrive foi desinstalado, mas seus arquivos locais na pasta 'C:\Users\SeuUsuario\OneDrive' NÃO foram apagados." -ForegroundColor White
Write-Host "2. A política de registro impede que o Windows reinstale o OneDrive silenciosamente em atualizações futuras." -ForegroundColor White
Write-Host "3. Caso você decida reativar o OneDrive no futuro, será necessário baixar o instalador manualmente no site da Microsoft e deletar a chave 'DisableFileSyncNGSC' criada neste script.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"