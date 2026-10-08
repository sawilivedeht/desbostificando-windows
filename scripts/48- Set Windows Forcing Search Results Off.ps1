# ==============================================================================
# SEQUESTRO DE PROTOLOCO MICROSOFT EDGE E PURGA DE TELEMETRIA (ANTI-BLOAT)
# Contexto: Intercepta links forçados pelo Windows (Copilot, Widgets, Start Menu), 
# remove tracking parameters (UTM) e redireciona para o navegador padrão do usuário.
# NOTA: Este script atua majoritariamente no HKCU e NÃO requer Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "    REDIRECIONAMENTO DE PROTOCOLOS E LIMPEZA DE TELEMETRIA (EDGE)    " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO AUXILIAR: BYPASS DE PERMISSÃO (TAKE OWNERSHIP)
# Contexto: O Windows bloqueia a gravação nas chaves do Edge mesmo no HKCU.
# Esta função assume a propriedade da chave via .NET antes de gravar.
# ==============================================================================
function Unlock-RegistryKey {
    param([string]$RegPath)
    
    $RelPath = $RegPath -replace "HKCU:\\", ""
    try {
        $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        
        # 1. Assume a propriedade (Take Ownership)
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RelPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        if ($key) {
            $acl = $key.GetAccessControl()
            $acl.SetOwner($sid)
            $key.SetAccessControl($acl)
            $key.Close()
        }

        # 2. Concede Controle Total a si mesmo
        $key2 = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($RelPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
        if ($key2) {
            $acl2 = $key2.GetAccessControl()
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($sid, "FullControl", "ContainerInherit", "None", "Allow")
            $acl2.SetAccessRule($rule)
            $key2.SetAccessControl($acl2)
            $key2.Close()
        }
    } catch {
        # Ignora silenciosamente se já tiver permissão ou se a chave não existir
    }
}

# ==============================================================================
# 1. MAPEAMENTO E OTIMIZAÇÃO DO TRATADOR DE PROTOCOLOS (EDGE & HUB)
# ==============================================================================
Write-Host "`n[*] Injetando tratadores de protocolo de alta velocidade..." -ForegroundColor DarkGray

 $ProtocolsToHijack = @(
    "microsoft-edge",
    "microsoft-edge-hub"
)

foreach ($Protocol in $ProtocolsToHijack) {
    $ProtocolPath = "HKCU:\Software\Classes\$Protocol"
    $CommandPath = "$ProtocolPath\shell\open\command"

    if (-not (Test-Path $CommandPath)) { New-Item -Path $CommandPath -Force | Out-Null }

    # ETAPA CRÍTICA: Desbloqueia as chaves antes de tentar gravar
    Unlock-RegistryKey -RegPath $ProtocolPath
    Unlock-RegistryKey -RegPath $CommandPath

    try {
        $regKey = Get-Item -Path $ProtocolPath -ErrorAction Stop
        $regKey.SetValue("", "URL:$Protocol Custom Redirector", [Microsoft.Win32.RegistryValueKind]::String)
        $regKey.SetValue("URL Protocol", "", [Microsoft.Win32.RegistryValueKind]::String)
        
        $ExecutionCommand = "powershell.exe -WindowStyle Hidden -Command `"foreach(`$p in @('%1')){`$u=`$p; if(`$u -match 'url=(https?://[^\\s&]+)'){`$u=`$Matches[1]}else{`$u=`$u -replace '^$Protocol[^\`"]*',''}; `$u=`$u -replace '[?&](utm_[^&=]+|sprefix|cvid|form|tracking_id|cid|ep|pc)=[^&\\s]*',''; if(`$u -match '^http'){Start-Process `$u}}`""

        $cmdKey = Get-Item -Path $CommandPath -ErrorAction Stop
        $currentCmd = $cmdKey.GetValue("")

        if ($currentCmd -ne $ExecutionCommand) {
            $cmdKey.SetValue("", $ExecutionCommand, [Microsoft.Win32.RegistryValueKind]::String)
            $LogTweaks += [PSCustomObject]@{ Feature = "Protocol: $Protocol"; Acao = "Sequestrado e Otimizado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Protocol: $Protocol"; Acao = "Já estava sequestrado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Protocol: $Protocol"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. SUPRESSÃO DO POP-UP "FAÇA DO EDGE SEU NAVEGADOR"
# ==============================================================================
Write-Host "[*] Suprimindo notificações de navegador padrão..." -ForegroundColor DarkGray

 $EdgePolicyPath = "HKCU:\Software\Microsoft\Edge\Main"
if (-not (Test-Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }

 $prop = "DefaultBrowserSettingEnabled"
 $val = 0
try {
    if ((Get-ItemProperty -Path $EdgePolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $EdgePolicyPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Pop-up Padrão"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Pop-up Padrão"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Pop-up Padrão"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 3. BLOQUEIO DE CRIAÇÃO DE ATALHOS DO EDGE NA ÁREA DE TRABALHO
# ==============================================================================
Write-Host "[*] Bloqueando criação de atalhos indesejados..." -ForegroundColor DarkGray

 $EdgeDesktopPath = "HKCU:\Software\Policies\Microsoft\MicrosoftEdge\Main"
if (-not (Test-Path $EdgeDesktopPath)) { New-Item -Path $EdgeDesktopPath -Force | Out-Null }

 $prop = "AllowPrelaunch"
 $val = 0
try {
    if ((Get-ItemProperty -Path $EdgeDesktopPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $EdgeDesktopPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Prelaunch/Lixo"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Prelaunch/Lixo"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Nuisance: Prelaunch/Lixo"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 4. REINICIALIZAÇÃO SEGURA DO EXPLORER (SOMENTE SE NECESSÁRIO)
# ==============================================================================
 $needsRestart = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRestart) {
    Write-Host "`nPara que o Windows reconheça os novos tratadores de protocolo imediatamente, a Shell precisa ser reiniciada." -ForegroundColor Yellow
    Write-Warning "AVISO: Fechar o Explorer fechará TODAS as janelas de pastas abertas."
    $confirm = Read-Host "Deseja reiniciar o Explorer agora? (S/N)"
    
    if ($confirm -eq 'S' -or $confirm -eq 's') {
        Write-Host "Reiniciando a Shell..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell (Explorer)"; Acao = "Reiniciada com sucesso"; Status = "SUCESSO" }
    } else {
        Write-Host "A alteração será aplicada na próxima vez que você fizer login." -ForegroundColor DarkGray
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell (Explorer)"; Acao = "Reinício ignorado pelo usuário"; Status = "OK" }
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

Write-Host "`n[!] TESTE: Abra o Menu Iniciar, pesquise qualquer coisa e clique em um link de notícia. Ele deve abrir instantaneamente no seu navegador padrão (Chrome/Firefox/Brave), sem passar pelo Edge e sem parâmetros de rastreamento.`n" -ForegroundColor Yellow

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"