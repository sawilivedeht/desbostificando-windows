# ==============================================================================
# PURGA DE RESÍDUOS DA BARRA DE TAREFAS (PEOPLE, MEET NOW, WIDGETS)
# Contexto: Remoção de ícones e bandas legadas/intrusivas da Barra de Tarefas para 
# um ambiente visual limpo, minimalista e livre de distrações em segundo plano.
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "        PURGA DE RESÍDUOS DA BARRA DE TAREFAS (UI CLEANUP)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO AUXILIAR PARA APLICAR CONFIGURAÇÕES COM VALIDAÇÃO DE ESTADO
# ==============================================================================
function Set-TaskbarSetting {
    param (
        [string]$RegPath,
        [string]$Name,
        [int]$Value
    )

    if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force | Out-Null }
    
    $currentVal = (Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue).$Name
    
    try {
        if ($currentVal -ne $Value) {
            Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
            return "SUCESSO"
        }
        return "OK"
    } catch {
        return "ERRO"
    }
}

# Caminho base para configurações avançadas do Explorer
 $TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

# ==============================================================================
# 1. DESATIVAÇÃO DA BANDA DE CONTATOS (PEOPLE BAND)
# ==============================================================================
Write-Host "`n[*] Removendo Banda de Contatos (People Band)..." -ForegroundColor DarkGray

 $PeoplePath = "$TaskbarPath\People"
 $status = Set-TaskbarSetting -RegPath $PeoplePath -Name "PeopleBand" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Taskbar: People Band"; Acao = "Desativada"; Status = $status }

# Zera a capacidade para garantir que o recurso não aloque memória em background
 $status = Set-TaskbarSetting -RegPath $PeoplePath -Name "CapacityOfPeopleBar" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Taskbar: People Capacity"; Acao = "Zerada (Libera memória BG)"; Status = $status }

# ==============================================================================
# 2. REMOÇÃO DO ÍCONE "MEET NOW" / CHAT DA MICROSOFT
# Contexto: O Windows embutiu um ícone do Skype/Chat na barra de tarefas. 
# Mesmo descontinuado em builds recentes, o resíduo fica preso na UI.
# ==============================================================================
Write-Host "[*] Removendo ícone de Chat (Meet Now)..." -ForegroundColor DarkGray

 $status = Set-TaskbarSetting -RegPath $TaskbarPath -Name "TaskbarMn" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Taskbar: Meet Now"; Acao = "Oculto"; Status = $status }

# ==============================================================================
# 3. DESATIVAÇÃO DOS WIDGETS NA BARRA DE TAREFAS
# Contexto: O painel de Widgets consome RAM, CPU e faz requisições de rede em 
# background para buscar notícias e clima. Desativar o ícone remove o acesso rápido.
# ==============================================================================
Write-Host "[*] Ocultando ícone de Widgets..." -ForegroundColor DarkGray

 $status = Set-TaskbarSetting -RegPath $TaskbarPath -Name "TaskbarDa" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Taskbar: Widgets"; Acao = "Oculto"; Status = $status }

# ==============================================================================
# 4. OCULTAR BOTÃO "VISÃO DE TAREFAS" (TASK VIEW)
# Contexto: O botão "Visão de Tarefas" abre o Timeline do Windows (que na verdade 
# não faz mais nada desde o Win 11 22H2). Ocultá-lo deixa a barra de tarefas 
# mais limpa para usuários que gerenciam janelas apenas com Alt+Tab.
# ==============================================================================
Write-Host "[*] Ocultando botão Visão de Tarefas..." -ForegroundColor DarkGray

 $status = Set-TaskbarSetting -RegPath $TaskbarPath -Name "ShowTaskViewButton" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Taskbar: Task View"; Acao = "Oculto"; Status = $status }


# ==============================================================================
# ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Aplicando mudanças na Barra de Tarefas..." -ForegroundColor DarkGray
    
    # MÉTODO CORRETO: Utilizando WM_SETTINGCHANGE via SendMessageTimeout para forçar 
    # o Windows a reler as políticas de UI sem destruir as janelas do Explorer.
    try {
        if (-not ([System.Management.Automation.PSTypeName]'Win32.Win32SendMsg').Type) {
            $signature = @"
            [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
            public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
            Add-Type -MemberDefinition $signature -Name "Win32SendMsg" -Namespace Win32 -ErrorAction Stop
        }
        
        $HWND_BROADCAST = [IntPtr]0xffff
        $WM_SETTINGCHANGE = 0x1A
        $result = [UIntPtr]::Zero
        
        $null = [Win32.Win32SendMsg]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Policy", 2, 5000, [ref]$result)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Atualizado via API (Seguro)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Falha ao atualizar via API"; Status = "ERRO" }
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

Write-Host "`n[!] NOTA: A Barra de Tarefas ficará visivelmente mais limpa, contendo apenas os ícones de aplicativos abertos, a Bandeja do Sistema (Relógio/Rede/Som) e a setinha de ícones ocultos." -ForegroundColor Yellow
Write-Host "[!] Se algum ícone não sumir imediatamente, clique com o botão direito na Barra de Tarefas -> 'Configurações da barra de tarefas' e desative manualmente as opções correspondentes para forçar a sincronização do Windows.`n" -ForegroundColor White

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"