# ==============================================================================
# PURGA DA CENTRAL DE AÇÕES E ÍCONES DO SISTEMA (ACTION CENTER CLEANUP)
# Contexto: Desativação completa da Central de Ações e remoção de ícones do 
# sistema embutidos (Relógio, Rede, Som, Bateria) para obter uma barra de tarefas 
# visualmente limpa e sem processos UWP residuais.
# Requer: Execução como Administrador (necessário para aplicar a política HKLM global).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas do Sistema (HKLM)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       PURGA DA CENTRAL DE AÇÕES E ÍCONES DO SISTEMA (UI CLEANUP)     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DESATIVAÇÃO DA CENTRAL DE AÇÕES (ESCOPO DUPLO: USUÁRIO E MÁQUINA)
# ==============================================================================
Write-Host "`n[*] Desativando Central de Ações em ambos os escopos..." -ForegroundColor DarkGray

 $PolicyPaths = @{
    "HKCU:\Software\Policies\Microsoft\Windows\Explorer" = "Usuário Atual (HKCU)"
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" = "Sistema Local (HKLM)"
}

 $prop = "DisableNotificationCenter"
 $val = 1

foreach ($Path in $PolicyPaths.Keys) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    
    $scopeName = $PolicyPaths[$Path]
    try {
        if ((Get-ItemProperty -Path $Path -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $Path -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Action Center ($scopeName)"; Acao = "Desativada"; Status = "SUCESSO" }
        } else { 
            $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Action Center ($scopeName)"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Action Center ($scopeName)"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. OCULTAR ÍCONES DO SISTEMA DA BARRA DE TAREFAS
# ==============================================================================
Write-Host "[*] Ocultando ícones do Sistema da barra de tarefas..." -ForegroundColor DarkGray

 $SystemIconsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideIcons"
if (-not (Test-Path $SystemIconsPath)) { New-Item -Path $SystemIconsPath -Force | Out-Null }

 $IconSettings = @{
    "HideSCAHealth" = 0 # Mantém o ícone do Windows Defender (Importante!)
    "HideSCAPower"  = 1 # Oculta o ícone de Energia
    "HideSCANetwork"= 1 # Oculta o ícone de Rede
    "HideSCAVolume" = 1 # Oculta o ícone de Volume
    "HideSCASound"  = 1 # Oculta o ícone de Som
    "HideSCATime"   = 1 # Oculta o Relógio
}

foreach ($setting in $IconSettings.Keys) {
    $val = $IconSettings[$setting]
    $logName = switch ($setting) {
        "HideSCAHealth" { "Icon: Segurança (Mantido)" }
        default         { "Icon: $setting" }
    }
    
    try {
        if ((Get-ItemProperty -Path $SystemIconsPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $SystemIconsPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = $logName; Acao = "Aplicado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = $logName; Acao = "Já estava configurado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = $logName; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 3. DESATIVAR NOTIFICAÇÕES NO LOCK SCREEN / CALENDÁRIO
# ==============================================================================
Write-Host "[*] Removendo botão de notificações e excessos na interface..." -ForegroundColor DarkGray

 $CalendarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $CalendarPath)) { New-Item -Path $CalendarPath -Force | Out-Null }

 $prop = "ShowNotificationsOnLockScreen"
 $val = 0

try {
    if ((Get-ItemProperty -Path $CalendarPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $CalendarPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Calendário/LockScreen"; Acao = "Notificações ocultas"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Calendário/LockScreen"; Acao = "Já estava oculto"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Calendário/LockScreen"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 4. ATUALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRefresh = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRefresh) {
    Write-Host "`n[*] Forçando a barra de tarefas a redesenhar sem fechar pastas..." -ForegroundColor DarkGray
    
    try {
        Add-Type -Namespace User32 -Name Win32 -MemberDefinition '[DllImport("user32.dll")]public static extern bool UpdatePerUserSystemParameters(uint uiAction, uint uiParam, string pvParam, uint fWinIni);' -ErrorAction Stop
        $null = [User32.Win32]::UpdatePerUserSystemParameters(0x001F, 0, $null, 0x0001)
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell Update"; Acao = "Barra de Tarefas atualizada via API"; Status = "SUCESSO" }
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
Write-Host "1. A Central de ações foi completamente suprimida. Para abrir notificações de apps de terceiros (Discord, Steam), use os próprios sistemas de notificação de cada app." -ForegroundColor White
Write-Host "2. O ícone do Windows Defender foi intencionalmente MANTIDO na barra de tarefas, pois é o único que não pode ser removido via registro de forma segura." -ForegroundColor White
Write-Host "3. Se você não usa o Defender nativo, é recomendado desativá-lo por completo em um script separado em vez de apenas ocultar o ícone.`n" -ForegroundColor DarkGray

Read-Host "Pressione ENTER para fechar"