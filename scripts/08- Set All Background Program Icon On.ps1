# ==============================================================================
# OTIMIZAÇÃO DA BANDEJA DO SISTEMA (SYSTEM TRAY) E LIMPEZA DE CACHE
# Contexto: Forçar a exibição de todos os ícones de aplicativos, remover lixo 
# visual da Microsoft (Meet Now) e purgar o cache gráfico corrompido que causa 
# lentidão ao abrir a bandeja ou ícones invisíveis/transparentes.
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "          OTIMIZAÇÃO DA BANDEJA DO SISTEMA (SYSTEM TRAY)               " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. PROMOÇÃO DE ÍCONES (EXIBIR TODOS SEM EXCESSÕES)
# ==============================================================================
Write-Host "`n[*] Promovendo ícones ocultos na Bandeja do Sistema..." -ForegroundColor DarkGray

 $TrayPath = "HKCU:\Control Panel\NotifyIconSettings"
 $promotedCount = 0
 $totalIcons = 0

if (Test-Path $TrayPath) {
    Get-ChildItem -Path $TrayPath -ErrorAction SilentlyContinue | ForEach-Object {
        $totalIcons++
        $currentStatus = (Get-ItemProperty -Path $_.PsPath -Name "IsPromoted" -ErrorAction SilentlyContinue).IsPromoted
        
        # Só reescreve no registro se o ícone NÃO estiver visível (Otimização de I/O)
        if ($currentStatus -ne 1) {
            Set-ItemProperty -Path $_.PsPath -Name "IsPromoted" -Value 1 -Force
            $promotedCount++
        }
    }
}

if ($totalIcons -gt 0) {
    $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Promover Ícones"; Acao = "$promotedCount ícones promovidos de $totalIcons"; Status = "SUCESSO" }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Promover Ícones"; Acao = "Nenhum ícone cacheado encontrado"; Status = "OK" }
}

# ==============================================================================
# NOVA FEATURE: PURGA DO CACHE GRÁFICO (ICONSTREAMS)
# Contexto: O Windows armazena os bitmaps dos ícones da bandeja em um blob binário 
# gigante no registro (IconStreams). Com o tempo, ele corrompe, ficando gigante, 
# causando travamentos ao passar o mouse ou fazendo ícones sumirem. Deletar isso 
# força o Windows a reconstruir um cache limpo e leve do zero.
# ==============================================================================
Write-Host "[*] Purgando cache gráfico corrompido da Bandeja..." -ForegroundColor DarkGray

 $TrayNotifyPath = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\TrayNotify"
if (Test-Path $TrayNotifyPath) {
    $cacheCleared = $false
    
    # Remove os streams de ícones passados e atuais
    $streamNames = @("IconStreams", "PastIconsStream")
    foreach ($stream in $streamNames) {
        if ((Get-ItemProperty -Path $TrayNotifyPath -Name $stream -ErrorAction SilentlyContinue).$stream) {
            Remove-ItemProperty -Path $TrayNotifyPath -Name $stream -Force -ErrorAction SilentlyContinue
            $cacheCleared = $true
        }
    }

    if ($cacheCleared) {
        $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Graphic Cache"; Acao = "Destruído (Reconstruirá do zero)"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Graphic Cache"; Acao = "Já estava limpo"; Status = "OK" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Graphic Cache"; Acao = "Caminho não encontrado"; Status = "OK" }
}

# ==============================================================================
# NOVA FEATURE: REMOÇÃO DO ÍCONE "MEET NOW" / CHAT DA MICROSOFT
# Contexto: A Microsoft embutiu um ícone do Skype/Chat na bandeja do sistema para 
# iniciar reuniões instantaneamente. 99% dos usuários nunca usam isso. Ocultá-lo 
# limpa o espaço visual da bandeja.
# ==============================================================================
Write-Host "[*] Limpando ícones nativos da Microsoft (Meet Now)..." -ForegroundColor DarkGray

 $TaskbarPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (-not (Test-Path $TaskbarPath)) { New-Item -Path $TaskbarPath -Force | Out-Null }

# TaskbarMn = 0 oculta o ícone do People/Meet Now
 $prop = "TaskbarMn"; $val = 0
if ((Get-ItemProperty -Path $TaskbarPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
    Set-ItemProperty -Path $TaskbarPath -Name $prop -Value $val -Type DWord -Force
    $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Meet Now Icon"; Acao = "Oculto da bandeja"; Status = "SUCESSO" }
} else { 
    $LogTweaks += [PSCustomObject]@{ Feature = "Tray: Meet Now Icon"; Acao = "Já estava oculto"; Status = "OK" }
}


# ==============================================================================
# REINÍCIO SEGURANTE DO EXPLORER (SOMENTE SE NECESSÁRIO)
# ==============================================================================
 $needsRestart = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRestart) {
    Write-Host "`nPara que os ícones promovidos e o novo cache gráfico sejam desenhados na tela, a Shell precisa ser reiniciada." -ForegroundColor Yellow
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

Write-Host "`n[!] NOTA: Ao promover os ícones, a bandeja do sistema pode ficar cheia se você tiver muitos programas rodando." -ForegroundColor Yellow
Write-Host "[!] Você pode arrastar ícones que não te interessam de volta para a setinha '^' (Área de Transbordamento) manualmente se quiser organizar.\n" -ForegroundColor Yellow