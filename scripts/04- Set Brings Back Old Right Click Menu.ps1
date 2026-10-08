# ==============================================================================
# GERENCIAMENTO DO MENU DE CONTEXTO (WIN11 CLÁSSICO vs MODERNO) + OTIMIZAÇÃO
# Contexto: Alternância entre o menu do Windows 10 (rápido/completo) e do 
# Windows 11 (moderno/abreviado), além da limpeza de lentidão no submenu "Novo".
# NOTA: Este script atua no HKCU e NÃO requer privilégios de Administrador.
# ==============================================================================

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       GERENCIADOR DE MENU DE CONTEXTO (WIN 10 vs WIN 11)             " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. DETECÇÃO INTELIGENTE DE ESTADO
# ==============================================================================
 $clsidPath = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}"
 $inprocPath = "$clsidPath\InprocServer32"

# Verifica se a chave existe e qual é o valor
 $inprocExists = Test-Path $inprocPath
 $currentValue = if ($inprocExists) { (Get-ItemProperty -Path $inprocPath -Name "(Default)" -ErrorAction SilentlyContinue)."(Default)" } else { $null }

 $isWin10MenuActive = ($inprocExists -and [string]::IsNullOrEmpty($currentValue))

if ($isWin10MenuActive) {
    Write-Host "`n[Estado Atual] Menu Clássico do Windows 10 está ATIVO." -ForegroundColor Green
    $choice = Read-Host "Deseja REVERTER para o menu Moderno do Windows 11? (S/N)"
    
    if ($choice -eq 'S' -or $choice -eq 's') {
        try {
            # Remove a chave de quebra para restaurar o menu do Win 11
            Remove-Item -Path $clsidPath -Recurse -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Revertido para Windows 11"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Falha ao reverter (Erro de Permissão?)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Mantido no Windows 10"; Status = "OK" }
    }
} else {
    Write-Host "`n[Estado Atual] Menu Moderno do Windows 11 está ATIVO." -ForegroundColor Yellow
    $choice = Read-Host "Deseja ATIVAR o Menu Clássico do Windows 10? (S/N)"
    
    if ($choice -eq 'S' -or $choice -eq 's') {
        try {
            # Força o fallback para o menu clássico injetando a string nula
            if (-not (Test-Path $clsidPath)) { New-Item -Path $clsidPath -Force | Out-Null }
            New-Item -Path $inprocPath -Force | Out-Null
            Set-ItemProperty -Path $inprocPath -Name "(Default)" -Value "" -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Alterado para Windows 10"; Status = "SUCESSO" }
        } catch {
            $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Falha ao alterar (Erro de Permissão?)"; Status = "ERRO" }
        }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Menu de Contexto"; Acao = "Mantido no Windows 11"; Status = "OK" }
    }
}

# ==============================================================================
# 2. LIMPEZA DO CACHE DO SUBMENU "NOVO" (FIX DE LENTIDÃO)
# Contexto: O Windows guarda um cache de todos os templates de arquivo (Word, Bloco 
# de Notas, etc) nessa chave. Com o tempo, esse cache corrompe ou incha, fazendo o 
# botão direito -> "Novo" demorar de 3 a 5 segundos para aparecer. Deletar a chave 
# força o Explorer a reconstruir um cache limpo e ultra-rápido.
# ==============================================================================
Write-Host "`n[*] Otimizando submenu 'Novo' (Fix de lentidão comum no Win 11)..." -ForegroundColor DarkGray

 $ShellNewPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Discardable\PostSetup\ShellNew"
if (Test-Path $ShellNewPath) {
    try {
        Remove-Item -Path $ShellNewPath -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Submenu: 'Novo'"; Acao = "Cache destruído (Será recriado limpo)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Submenu: 'Novo'"; Acao = "Falha ao deletar cache"; Status = "ERRO" }
    }
} else {
    $LogTweaks += [PSCustomObject]@{ Feature = "Submenu: 'Novo'"; Acao = "Cache já está limpo"; Status = "OK" }
}

# ==============================================================================
# 3. REINÍCIO SEGURO DO EXPLORER (SOMENTE SE HOUVE MUDANÇA)
# ==============================================================================
 $needsRestart = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRestart) {
    Write-Host "`nPara que a mudança de Shell e a limpeza de cache façam efeito, o Explorer precisa ser reiniciado." -ForegroundColor Yellow
    Write-Warning "AVISO: Fechar o Explorer fechará TODAS as janelas de pastas abertas."
    $confirmRestart = Read-Host "Deseja reiniciar o Explorer agora? (S/N)"
    
    if ($confirmRestart -eq 'S' -or $confirmRestart -eq 's') {
        Write-Host "Reiniciando a Shell..." -ForegroundColor Cyan
        Stop-Process -Name explorer -Force
        Start-Sleep -Seconds 2
        Start-Process explorer.exe
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell (Explorer)"; Acao = "Reiniciada com sucesso"; Status = "SUCESSO" }
    } else {
        Write-Host "A alteração será aplicada na próxima vez que você fizer login ou reiniciar o PC." -ForegroundColor DarkGray
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

Write-Host "`n[!] DICAS: Se você está no Menu Clássico e sente falta de 'Compactar em ZIP' ou 'Extrair', eles podem ter sumido. Basta abrir o 'Opções de Pasta' > 'Associar um tipo de arquivo' e selecionar o ZIP para restaurá-los ao menu.`n" -ForegroundColor Yellow