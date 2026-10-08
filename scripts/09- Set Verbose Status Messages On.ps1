# ==============================================================================
# FERRAMENTAS AVANÇADAS DE DIAGNÓSTICO DE BOOT E DESLIGAMENTO
# Contexto: Exposição de logs textuais na tela e geração de arquivos de log 
# em disco para identificar gargalos de drivers, serviços ou políticas (GPO).
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar políticas de Boot e Registro."
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     HABILITAÇÃO DE LOGS VERBOSE DE BOOT, KERNEL E DESLIGAMENTO       " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Warning "AVISO: Logs detalhados deixam o boot e o desligamento visualmente mais poluídos e podem adicionar alguns segundos ao tempo total de inicialização."

 $LogTweaks = @()

# ==============================================================================
# 1. POLÍTICAS DE STATUS DE INICIALIZAÇÃO E DESLIGAMENTO (USER-MODE)
# ==============================================================================
Write-Host "`n[*] Configurando políticas de status na tela (User-Mode)..." -ForegroundColor DarkGray

 $SystemPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
if (-not (Test-Path $SystemPath)) { New-Item -Path $SystemPath -Force | Out-Null }

# Mostra mensagens detalhadas de status na tela durante o boot e desligamento
 $prop = "VerboseStatus"; $val = 1
try {
    if ((Get-ItemProperty -Path $SystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Verbose Status"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Verbose Status"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Verbose Status"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# Garante que as mensagens não sejam suprimidas
 $prop = "DisableStatusMessages"; $val = 0
try {
    if ((Get-ItemProperty -Path $SystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Status Messages"; Acao = "Desbloqueado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Status Messages"; Acao = "Já estava desbloqueado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Boot/Shutdown: Status Messages"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# Exibe o motivo do desligamento na tela (Shutdown Event Tracker)
 $prop = "ShutdownReasonUI"; $val = 1 # O nome correto da chave é ShutdownReasonUI (1 = Ativado)
try {
    if ((Get-ItemProperty -Path $SystemPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SystemPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Shutdown: Reason UI"; Acao = "Ativado"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "Shutdown: Reason UI"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Shutdown: Reason UI"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# 2. LOG DE KERNEL EM DISCO (NTBTLOG.TXT)
# Contexto: O VerboseStatus só mostra a fase posterior ao carregador. Ativar o 
# bootlog via bcdedit cria o arquivo C:\Windows\ntbtlog.txt, que lista TODOS os 
# drivers de kernel (.sys) carregados na ordem exata.
# ==============================================================================
Write-Host "[*] Configurando log de Kernel em disco (bcdedit)..." -ForegroundColor DarkGray

# Ativa o log de inicialização
 $null = bcdedit /set bootlog yes 2>&1
if ($LASTEXITCODE -eq 0) {
    $LogTweaks += [PSCustomObject]@{ Feature = "Kernel: Boot Log (ntbtlog.txt)"; Acao = "Ativado"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Kernel: Boot Log (ntbtlog.txt)"; Acao = "Falha ao aplicar"; Status = "ERRO" }
}

# NOTA SOBRE SHUTDOWN LOG: O comando "bcdedit /set bootlogshutdown" foi removido pois NÃO EXISTE no Windows.
# O arquivo ntbtlog.txt registra apenas o BOOT. Para diagnosticar desligamentos lentos:
# 1. Use o Verbose Status (ativado acima).
# 2. Abra o Visualizador de Eventos (eventvwr.msc) > Logs de Aplicativo e Serviços > Microsoft > Windows > Diagnostics-Performance > Operacional.
# 3. Filtre por ID de Evento 200 (Shutdown) para ver quais serviços/aplicativos demoraram para fechar.

# ==============================================================================
# 3. REMOÇÃO DO ATRASO ARTIFICIAL DO STARTUP
# ==============================================================================
Write-Host "[*] Removendo atraso artificial da pasta de Inicialização..." -ForegroundColor DarkGray

 $StartupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize"
if (-not (Test-Path $StartupPath)) { New-Item -Path $StartupPath -Force | Out-Null }

 $prop = "StartupDelayInMSec"; $val = 0
try {
    if ((Get-ItemProperty -Path $StartupPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $StartupPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Startup Delay"; Acao = "Removido (0ms)"; Status = "SUCESSO" }
    } else { 
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Startup Delay"; Acao = "Já estava removido"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Startup Delay"; Acao = "Erro ao aplicar"; Status = "ERRO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] COMO DIAGNOSTICAR O PROBLEMA:" -ForegroundColor Yellow
Write-Host "1. REINICIE o computador." -ForegroundColor White
Write-Host "2. Durante o boot, observe os textos na tela (Verbose Status) para ver onde ele para." -ForegroundColor White
Write-Host "3. Após entrar no Windows, abra o arquivo: C:\Windows\ntbtlog.txt" -ForegroundColor Green
Write-Host "4. O último driver listado como 'Loaded' ou 'Did not load' nesse arquivo é quase sempre o culpado pelo travamento de BOOT." -ForegroundColor White
Write-Host "5. Para problemas de DESLIGAMENTO, abra o Visualizador de Eventos e vá em:" -ForegroundColor White
Write-Host "   Logs de Aplicativos e Serviços > Microsoft > Windows > Diagnostics-Performance > Operacional" -ForegroundColor Green
Write-Host ""