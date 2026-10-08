# ==============================================================================
# OTIMIZAÇÃO DA SHELL, FILE EXPLORER E FLUXO DE I/O DE INTERFACE
# Contexto: Reduzir atrasos de renderização de pastas, prevenir crashes em 
# cascata e remover gatilhos de busca web que travam a interface.
# Requer: Execução como Administrador (Para consistência do pacote).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador (Padrão do pacote de otimização)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         OTIMIZAÇÃO AVANÇADA DO FILE EXPLORER (SHELL/UI)            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsRestart = $false

# Caminhos Mestres
 $ExplorerAdvancedPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
 $ExplorerMainPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
 $ShellPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

if (-not (Test-Path $ExplorerAdvancedPath)) { New-Item -Path $ExplorerAdvancedPath -Force | Out-Null }
if (-not (Test-Path $ExplorerMainPath)) { New-Item -Path $ExplorerMainPath -Force | Out-Null }

# ==============================================================================
# 1. COMPORTAMENTO DE INICIALIZAÇÃO E NAVEGAÇÃO
# ==============================================================================
Write-Host "`n[*] Configurando comportamento de inicialização..." -ForegroundColor DarkGray

# Abrir direto em "Este Computador"
 $prop = "LaunchTo"; $val = 1
try {
    if ((Get-ItemProperty -Path $ExplorerMainPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ExplorerMainPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: LaunchTo"; Acao = "Definido para 'Este Computador'"; Status = "SUCESSO" }
        $needsRestart = $true
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: LaunchTo"; Acao = "Já estava correto"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: LaunchTo"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Desativa Recent e Frequent
 $props = @{ "ShowRecent" = 0; "ShowFrequent" = 0 }
foreach ($p in $props.Keys) {
    $val = $props[$p]
    try {
        if ((Get-ItemProperty -Path $ExplorerMainPath -Name $p -ErrorAction SilentlyContinue).$p -ne $val) {
            Set-ItemProperty -Path $ExplorerMainPath -Name $p -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: $p"; Acao = "Desativado"; Status = "SUCESSO" }
            $needsRestart = $true
        } else { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: $p"; Acao = "Já estava desativado"; Status = "OK" } }
    } catch { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: $p"; Acao = "Falha ao gravar"; Status = "ERRO" } }
}

# ==============================================================================
# 2. ISOLAMENTO DE PROCESSOS E LIMPEZA DE NÓS (ONEDRIVE/SYNC)
# ==============================================================================
Write-Host "[*] Aplicando isolamento de processos..." -ForegroundColor DarkGray

# Processo Separado (Crucial: se uma pasta travar, a Taskbar não morre)
 $prop = "SeparateProcess"; $val = 1
try {
    if ((Get-ItemProperty -Path $ExplorerAdvancedPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ExplorerAdvancedPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: SeparateProcess"; Acao = "Ativado (Proteção contra Crash)"; Status = "SUCESSO" }
        $needsRestart = $true
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: SeparateProcess"; Acao = "Já estava ativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: SeparateProcess"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# Oculta arquivos na nuvem e notificações de sync do OneDrive
 $propsCloud = @{ "ShowCloudFilesInQuickAccess" = 0; "ShowSyncProviderNotifications" = 0 }
foreach ($p in $propsCloud.Keys) {
    $val = $propsCloud[$p]
    try {
        if ((Get-ItemProperty -Path $ExplorerAdvancedPath -Name $p -ErrorAction SilentlyContinue).$p -ne $val) {
            Set-ItemProperty -Path $ExplorerAdvancedPath -Name $p -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "UI: $p"; Acao = "Desativado"; Status = "SUCESSO" }
            $needsRestart = $true
        } else { $LogTweaks += [PSCustomObject]@{ Feature = "UI: $p"; Acao = "Já estava desativado"; Status = "OK" } }
    } catch { $LogTweaks += [PSCustomObject]@{ Feature = "UI: $p"; Acao = "Falha ao gravar"; Status = "ERRO" } }
}

# ==============================================================================
# 3. DESATIVAR "PESQUISAR NA WEB" (WINDOWS 11)
# ==============================================================================
 $SearchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
if (-not (Test-Path $SearchSettingsPath)) { New-Item -Path $SearchSettingsPath -Force | Out-Null }

 $prop = "IsDynamicSearchBoxEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $SearchSettingsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SearchSettingsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Search: Web Search"; Acao = "Desativado (Evita travamentos do Edge)"; Status = "SUCESSO" }
        $needsRestart = $true
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Search: Web Search"; Acao = "Já estava desativado"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Search: Web Search"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# 4. OCULTAR ABAS INÚTEIS NAS PROPRIEDADES DE ARQUIVOS
# ==============================================================================
Write-Host "[*] Otimizando janela de Propriedades de Arquivos..." -ForegroundColor DarkGray

 $prop = "NoSharingTab"; $val = 1
try {
    if ((Get-ItemProperty -Path $ShellPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ShellPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Props: Sharing Tab"; Acao = "Ocultada"; Status = "SUCESSO" }
        $needsRestart = $true
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Props: Sharing Tab"; Acao = "Já estava oculta"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Props: Sharing Tab"; Acao = "Falha ao gravar"; Status = "ERRO" } }

 $prop = "NoPreviousVersionsPage"; $val = 1
try {
    if ((Get-ItemProperty -Path $ShellPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $ShellPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Props: Previous Versions"; Acao = "Ocultada"; Status = "SUCESSO" }
        $needsRestart = $true
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Props: Previous Versions"; Acao = "Já estava oculta"; Status = "OK" } }
} catch { $LogTweaks += [PSCustomObject]@{ Feature = "Props: Previous Versions"; Acao = "Falha ao gravar"; Status = "ERRO" } }

# ==============================================================================
# RESULTADO FINAL E REINÍCIO CONDICIONAL DO EXPLORER
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

if ($needsRestart) {
    Write-Host "[*] Aplicando alterações na interface (Reiniciando Explorer)..." -ForegroundColor DarkGray
    try {
        Stop-Process -Name explorer -Force -ErrorAction Stop
        Start-Sleep -Seconds 2
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Reiniciado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Falha ao reiniciar"; Status = "ERRO" }
    }
} else {
    Write-Host "[*] Nenhuma alteração nova detectada. Explorer não será reiniciado." -ForegroundColor DarkGray
}

Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
Write-Host "1. O Windows Explorer só é reiniciado se alguma alteração real tiver sido feita no registro." -ForegroundColor White
Write-Host "2. Janelas de pastas abertas anteriormente podem ter sido fechadas durante o processo de reinício.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"