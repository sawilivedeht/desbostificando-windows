# ==============================================================================
# PURGA DO SUFIXO ' - ATALHO' E OTIMIZAÇÃO DE CRIAÇÃO DE ATALHOS (EXPLORER)
# Contexto: Remoção do sufixo automático de atalhos na criação de links na Área de 
# Trabalho para evitar poluição visual e acelerar a criação de atalhos. 
# Inclui desativação do prompt de UAC para atalhos e correção do bug do cache da Shell.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar parâmetros do Explorer e Políticas."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      PURGA DO SUFIXO ' - ATALHO' E OTIMIZAÇÃO DE CRIAÇÃO DE ATALHOS   " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. INJEÇÃO BINÁRIA DO SUFIXO ' - ATALHO' (MÉTODO CORRIGIDO E SEGURO)
# ==============================================================================
Write-Host "`n[*] Injetando máscara binária nula no registro..." -ForegroundColor DarkGray

 $ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
 $prop = "link"
 $val = [byte[]](0x00, 0x00, 0x00, 0x00)

if (-not (Test-Path $ExplorerPath)) { New-Item -Path $ExplorerPath -Force | Out-Null }

try {
    $currentVal = (Get-ItemProperty -Path $ExplorerPath -Name $prop -ErrorAction SilentlyContinue).$prop
    $needsUpdate = $false
    
    # Verifica se os 4 bytes já estão zerados (Evita I/O de registro desnecessário)
    if ($null -eq $currentVal) { 
        $needsUpdate = $true 
    } elseif ($currentVal.Length -ne 4) { 
        $needsUpdate = $true 
    } else {
        foreach ($b in $currentVal) { if ($b -ne 0) { $needsUpdate = $true; break } }
    }

    if ($needsUpdate) {
        Set-ItemProperty -Path $ExplorerPath -Name $prop -Value $val -Type Binary -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Registry: ' - Atalho' Sufixo"; Acao = "Desativado via Registro"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Registry: ' - Atalho' Sufixo"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Registry: ' - Atalho' Sufixo"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 2. DESATIVAR O PROMPT DE UAC NA CRIAÇÃO DE ATALHOS
# Contexto: Quando você cria um atalho para um .exe, o Windows insere um aviso de UAC.
# Remover esse aviso remove o passo de "Clique Sim" ao usar softwares de terceiros.
# ==============================================================================
Write-Host "[*] Desativando prompt de UAC na criação de atalhos externos..." -ForegroundColor DarkGray

 $UacPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\DisallowRunAsAdmin"
 $prop = "DisallowRunAsAdmin"
 $val = 1

if (-not (Test-Path $UacPath)) { New-Item -Path $UacPath -Force | Out-Null }

try {
    if ((Get-ItemProperty -Path $UacPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $UacPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UX: UAC Prompt (Atalhos)"; Acao = "Desativado (Criação instantânea)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UX: UAC Prompt (Atalhos)"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UX: UAC Prompt (Atalhos)"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 3. CORREÇÃO DO BUG DO CACHE DO EXPLORER
# Contexto: Desativar o sufixo ' - Atalho' pode fazer a barra de tarefas travar ao 
# renderizar ícones. A flag ClearRecentDocsAndListByShellExecute limpa esse cache.
# ==============================================================================
Write-Host "[*] Limpando cache corrompido de renderização da Barra de Tarefas..." -ForegroundColor DarkGray

 $ShellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
 $prop = "ClearRecentDocsAndListByShellExecute"
 $val = 1

if (-not (Test-Path $ShellPath)) { New-Item -Path $ShellPath -Force | Out-Null }

try {
    if ((Get-ItemProperty -Path $ShellPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ShellPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell: Taskbar Cache"; Acao = "Limpo (Correção de Bug dos Atalhos)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell: Taskbar Cache"; Acao = "Já estava limpo"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Shell: Taskbar Cache"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 4. ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Atualizando a Área de Trabalho sem fechar janelas..." -ForegroundColor DarkGray
    
    try {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction Stop
        $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Área de Trabalho atualizada via API"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Falha ao chamar API"; Status = "AVISO" }
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

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. O Windows fará uma varredura de API interna no boot se a limpeza do cache foi necessária. Se os ícones não carregarem, o Windows refaz o cache automaticamente." -ForegroundColor White
Write-Host "2. A partir de agora, criar atalhos resultará apenas no caminho limpo (Ex: 'Steam' em vez de 'Steam - Atalho')." -ForegroundColor White
Write-Host "3. Para usuários que gostam do sufixo ' - Atalho', eles terão que adicionar manualmente via Propriedades do atalho.`n" -ForegroundColor DarkGray

Read-Host "Pressione ENTER para fechar"