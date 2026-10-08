# ==============================================================================
# DESINSTALAÇÃO E BLOQUEIO PERMANENTE DO WINDOWS INSIDER PROGRAM
# Contexto: Remoção de canais instáveis, limpeza de chaves de registro, bloqueio 
# de políticas (GPO) e desinstalação da interface UWP para garantir que o PC 
# receba APENAS atualizações estáveis (General Availability).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas e remover Pacotes do Sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       DESINSTALAÇÃO E BLOQUEIO DO WINDOWS INSIDER PROGRAM            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. PURGA DAS CHAVES DE REGISTRO DO INSIDER
# ==============================================================================
Write-Host "`n[*] Limpando resíduos de configuração do Insider..." -ForegroundColor DarkGray

 $InsiderRegPath = "HKLM:\SOFTWARE\Microsoft\WindowsSelfHost"
if (Test-Path $InsiderRegPath) {
    try {
        Remove-Item -Path $InsiderRegPath -Recurse -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Reg: WindowsSelfHost"; Acao = "Deletado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Reg: WindowsSelfHost"; Acao = "Falha ao deletar (Travado?)"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Reg: WindowsSelfHost"; Acao = "Já estava limpo"; Status = "OK" }
}

# ==============================================================================
# 2. BLOQUEIO VIA POLÍTICA DE GRUPO (GPO MIRROR)
# ==============================================================================
Write-Host "[*] Aplicando GPO de bloqueio de Builds Preview..." -ForegroundColor DarkGray

 $WUPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
if (-not (Test-Path $WUPolicyPath)) { New-Item -Path $WUPolicyPath -Force | Out-Null }

# ManagePreviewBuilds = 1 (Ativa o controle de políticas)
 $prop = "ManagePreviewBuilds"
 $val = 1
if ((Get-ItemProperty -Path $WUPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $WUPolicyPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Manage Preview"; Acao = "Controle ativado"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Manage Preview"; Acao = "Já estava ativo"; Status = "OK" }
}

# ManagePreviewBuildsPolicyValue = 0 (0 = Bloqueia totalmente o recebimento de builds Insider)
 $prop = "ManagePreviewBuildsPolicyValue"
 $val = 0
if ((Get-ItemProperty -Path $WUPolicyPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $WUPolicyPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Block Value"; Acao = "Definido para 0 (Bloqueado)"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: Block Value"; Acao = "Já estava bloqueado"; Status = "OK" }
}

# ==============================================================================
# 3. DESINSTALAÇÃO DO APLICATIVO UWP "WINDOWS INSIDER HUB"
# Contexto: Mesmo bloqueado, o atalho do programa Insider permanece no Menu Iniciar. 
# Remover o pacote AppX limpa a interface do sistema.
# ==============================================================================
Write-Host "[*] Procurando aplicativo Windows Insider Hub..." -ForegroundColor DarkGray

# Procura o app para todos os usuários do sistema
 $InsiderApp = Get-AppxPackage -AllUsers -Name "*WindowsInsiderHub*" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($InsiderApp) {
    try {
        Remove-AppxPackage -Package $InsiderApp.PackageFullName -AllUsers -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "AppX: Insider Hub"; Acao = "Desinstalado do Sistema"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "AppX: Insider Hub"; Acao = "Falha na desinstalação (Pode exigir Reboot)"; Status = "AVISO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "AppX: Insider Hub"; Acao = "Não encontrado (Já removido)"; Status = "OK" }
}

# ==============================================================================
# 4. DESATIVAÇÃO DO SERVIÇO DE BACKGROUND (WISVC)
# Contexto: O Windows Insider Service verifica periodicamente os servidores da 
# Microsoft em busca de novos canais. Desativar o serviço encerra essa telemetria.
# ==============================================================================
Write-Host "[*] Desativando serviço de background (wisvc)..." -ForegroundColor DarkGray

 $Wisvc = Get-Service -Name "wisvc" -ErrorAction SilentlyContinue
if ($Wisvc) {
    if ($Wisvc.Status -eq 'Running') { Stop-Service -Name "wisvc" -Force -NoWait -ErrorAction SilentlyContinue }
    if ($Wisvc.StartType -ne 'Disabled') {
        Set-Service -Name "wisvc" -StartupType Disabled -ErrorAction SilentlyContinue
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Windows Insider"; Acao = "Parado e Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Windows Insider"; Acao = "Já estava desativado"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Svc: Windows Insider"; Acao = "Não presente neste PC"; Status = "OK" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] NOTA: Ao bloquear o Insider Program, a tela de 'Windows Update' pode exibir o aviso:" -ForegroundColor Yellow
Write-Host "'Algumas configurações são gerenciadas pela sua organização'. Isso é o sinal de que a GPO foi aplicada com sucesso e o PC está seguro contra builds instáveis.`n" -ForegroundColor White