# ==============================================================================
# PERSONALIZAÇÃO AVANÇADA DO MENU DE CONTEXTO (SHELL EXTENSIONS)
# Contexto: Adição de opções rápidas e úteis ao botão direito do mouse no Explorer,
# como Assumir Propriedade, Abrir com Bloco de Notas e Copiar Caminho.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar chaves globais do Windows."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       INSTALAÇÃO DE MENUS DE CONTEXTO AVANÇADOS (EXPLORER)           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO AUXILIAR PARA REGISTRO (COM TRATAMENTO DE ERROS)
# ==============================================================================
function Set-ContextMenu {
    param (
        [string]$RegPath,
        [string]$Name,
        [string]$Value
    )

    try {
        if (-not (Test-Path $RegPath)) { New-Item -Path $RegPath -Force -ErrorAction Stop | Out-Null }
        
        $regItem = Get-ItemProperty -Path $RegPath -Name $Name -ErrorAction SilentlyContinue
        $current = if ($null -ne $regItem) { $regItem.$Name } else { $null }
        
        if ($current -ne $Value) {
            Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Force -ErrorAction Stop
            return "SUCESSO"
        }
        return "OK"
    } catch {
        return "ERRO"
    }
}

# ==============================================================================
# 1. TAKE OWNERSHIP (ASSUMIR PROPRIEDADE)
# ==============================================================================
Write-Host "`n[*] Registrando menu 'Assumir Propriedade'..." -ForegroundColor DarkGray

 $TakeOwnCtx = "HKLM:\SOFTWARE\Classes\AllFilesystemObjects\shell\TakeOwnership"
 $s1 = Set-ContextMenu -RegPath $TakeOwnCtx -Name "(Default)" -Value "Assumir Propriedade"
 $s2 = Set-ContextMenu -RegPath $TakeOwnCtx -Name "Icon" -Value "imageres.dll,-78"
 $s3 = Set-ContextMenu -RegPath "$TakeOwnCtx\command" -Name "(Default)" -Value 'cmd.exe /c takeown /f "%1" /r /d y && icacls "%1" /grant administrators:F /t'

 $statuses = @($s1, $s2, $s3)
if ($statuses -contains "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Take Ownership"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
} elseif ($statuses -contains "SUCESSO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Take Ownership"; Acao = "Registrado (Arqs e Pastas)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Take Ownership"; Acao = "Já estava registrado"; Status = "OK" } 
}

# ==============================================================================
# 2. MENU "NOVO" PARA SCRIPTS POWERSHELL (.PS1)
# ==============================================================================
Write-Host "[*] Habilitando criação rápida de arquivos .ps1..." -ForegroundColor DarkGray

 $Ps1Path = "HKLM:\SOFTWARE\Classes\.ps1\ShellNew"
 $status = Set-ContextMenu -RegPath $Ps1Path -Name "NullFile" -Value ""

if ($status -eq "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "New: Script PowerShell"; Acao = "Falha ao gravar"; Status = "ERRO" }
} elseif ($status -eq "SUCESSO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "New: Script PowerShell"; Acao = "Habilitado no menu Novo"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "New: Script PowerShell"; Acao = "Já estava habilitado"; Status = "OK" } 
}

# ==============================================================================
# 3. CASCATA DE PRIORIDADE DE EXECUÇÃO (.EXE)
# ==============================================================================
Write-Host "[*] Registrando menu 'Executar com Prioridade...'..." -ForegroundColor DarkGray

 $ExeCtx = "HKLM:\SOFTWARE\Classes\exefile\shell\RunPriority"
Set-ContextMenu -RegPath $ExeCtx -Name "MUIVerb" -Value "Executar com Prioridade..." | Out-Null
Set-ContextMenu -RegPath $ExeCtx -Name "SubCommands" -Value "" | Out-Null

# Prioridade Alta
 $statusH = Set-ContextMenu -RegPath "$ExeCtx\shell\High" -Name "MUIVerb" -Value "Prioridade Alta (High)"
 $statusHC = Set-ContextMenu -RegPath "$ExeCtx\shell\High\command" -Name "(Default)" -Value 'cmd.exe /c start "" /High "%1"'

 $statuses = @($statusH, $statusHC)
if ($statuses -contains "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority High"; Acao = "Falha ao gravar"; Status = "ERRO" }
} elseif ($statuses -contains "SUCESSO") { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority High"; Acao = "Registrado"; Status = "SUCESSO" } 
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority High"; Acao = "Já existia"; Status = "OK" } 
}

# Prioridade Baixa
 $statusL = Set-ContextMenu -RegPath "$ExeCtx\shell\Low" -Name "MUIVerb" -Value "Prioridade Baixa (Low)"
 $statusLC = Set-ContextMenu -RegPath "$ExeCtx\shell\Low\command" -Name "(Default)" -Value 'cmd.exe /c start "" /Low "%1"'

 $statuses = @($statusL, $statusLC)
if ($statuses -contains "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority Low"; Acao = "Falha ao gravar"; Status = "ERRO" }
} elseif ($statuses -contains "SUCESSO") { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority Low"; Acao = "Registrado"; Status = "SUCESSO" } 
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Priority Low"; Acao = "Já existia"; Status = "OK" } 
}

# ==============================================================================
# 4. COPIAR CAMINHO DO ARQUIVO/PASTA (SEM FLASH DE TELA)
# ==============================================================================
Write-Host "[*] Registrando menu 'Copiar Caminho'..." -ForegroundColor DarkGray

 $AllCtx = "HKLM:\SOFTWARE\Classes\AllFilesystemObjects\shell\CopyPath"
 $s1 = Set-ContextMenu -RegPath $AllCtx -Name "MUIVerb" -Value "Copiar Caminho do Arquivo"
 $s2 = Set-ContextMenu -RegPath $AllCtx -Name "Icon" -Value "imageres.dll,-5302"
 $s3 = Set-ContextMenu -RegPath "$AllCtx\command" -Name "(Default)" -Value 'powershell.exe -WindowStyle Hidden -Command "Set-Clipboard -LiteralPath \"%1\""'

 $statuses = @($s1, $s2, $s3)
if ($statuses -contains "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Copiar Caminho"; Acao = "Falha ao gravar"; Status = "ERRO" }
} elseif ($statuses -contains "SUCESSO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Copiar Caminho"; Acao = "Registrado (Sem Flash)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Copiar Caminho"; Acao = "Já estava registrado"; Status = "OK" } 
}

# ==============================================================================
# 5. ABRIR COM O BLOCO DE NOTAS
# ==============================================================================
Write-Host "[*] Registrando menu 'Abrir com Bloco de Notas'..." -ForegroundColor DarkGray

 $NotepadCtx = "HKLM:\SOFTWARE\Classes\AllFilesystemObjects\shell\OpenWithNotepad"
 $s1 = Set-ContextMenu -RegPath $NotepadCtx -Name "MUIVerb" -Value "Abrir com Bloco de Notas"
 $s2 = Set-ContextMenu -RegPath $NotepadCtx -Name "Icon" -Value "notepad.exe"
 $s3 = Set-ContextMenu -RegPath "$NotepadCtx\command" -Name "(Default)" -Value 'notepad.exe "%1"'

 $statuses = @($s1, $s2, $s3)
if ($statuses -contains "ERRO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Abrir com Notepad"; Acao = "Falha ao gravar"; Status = "ERRO" }
} elseif ($statuses -contains "SUCESSO") {
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Abrir com Notepad"; Acao = "Registrado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Ctx: Abrir com Notepad"; Acao = "Já estava registrado"; Status = "OK" } 
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
Write-Host "1. O Windows Explorer armazena os menus de contexto em cache." -ForegroundColor White
Write-Host "2. Se você não ver as opções imediatamente, reinicie o processo 'Explorer' via Gerenciador de Tarefas ou faça logoff/logon.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"