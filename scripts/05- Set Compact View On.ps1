# ==============================================================================
# OTIMIZAÇÃO DE INTERFACE: MODO COMPACTO NO FILE EXPLORER (WIN 11)
# Contexto: Remove o espaçamento excessivo (padding) entre os itens no 
# File Explorer do Windows 11, exibindo mais informações na tela e 
# melhorando a usabilidade em monitores menores.
# Requer: Execução como Administrador (Para consistência do pacote de otimização).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador (Padrão do pacote de otimização)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "          OTIMIZAÇÃO DE UI: MODO COMPACTO EXPLORER (WIN 11)          " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()
 $needsRestart = $false # Controle para evitar reinício desnecessário do Explorer

# ==============================================================================
# 1. ATIVAÇÃO DO MODO COMPACTO (REGISTRO)
# ==============================================================================
Write-Host "`n[*] Configurando geometria de itens do File Explorer..." -ForegroundColor DarkGray

 $ExplorerPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
 $prop = "UseCompactMode"
 $val = 1

# Garante que o caminho do registro existe (boas práticas)
if (-not (Test-Path $ExplorerPath)) { 
    New-Item -Path $ExplorerPath -Force | Out-Null 
}

try {
    # Verifica se o valor já é o desejado (Idempotência)
    $currentValue = (Get-ItemProperty -Path $ExplorerPath -Name $prop -ErrorAction SilentlyContinue).$prop
    
    if ($currentValue -ne $val) {
        Set-ItemProperty -Path $ExplorerPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: Compact Mode"; Acao = "Ativado (Padding reduzido)"; Status = "SUCESSO" }
        $needsRestart = $true # Marca que o Explorer precisa ser reiniciado
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: Compact Mode"; Acao = "Já estava ativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Explorer: Compact Mode"; Acao = "Falha ao modificar o registro"; Status = "ERRO" }
}

# ==============================================================================
# 2. REINÍCIO DO WINDOWS EXPLORER (CONDICIONAL)
# ==============================================================================
if ($needsRestart) {
    Write-Host "[*] Aplicando alterações na interface..." -ForegroundColor DarkGray
    try {
        # Força a morte do processo. O Windows o reiniciará automaticamente em segundos.
        Stop-Process -Name explorer -Force -ErrorAction Stop
        
        # Pausa de 2 segundos para o Windows reiniciar a interface (Shell) 
        Start-Sleep -Seconds 2
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Reiniciado com sucesso"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Falha ao reiniciar"; Status = "ERRO" }
    }
} else {
    Write-Host "[*] Nenhuma alteração na interface detectada. Explorer não será reiniciado." -ForegroundColor DarkGray
    $LogTweaks += [PSCustomObject]@{ Feature = "Processo: explorer.exe"; Acao = "Pulado (Sem necessidade)"; Status = "OK" }
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
Write-Host "1. O Windows Explorer só é reiniciado se o Modo Compacto acabou de ser ativado. Janelas abertas anteriormente podem ter sido fechadas durante o processo." -ForegroundColor White
Write-Host "2. Embora seja uma chave de usuário (HKCU) que não exija Admin, a verificação foi mantida para padronizar com o pacote geral de otimizações.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"