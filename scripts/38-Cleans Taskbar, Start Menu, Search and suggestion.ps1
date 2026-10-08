# ==============================================================================
# PURGA DE TELEMETRIA, BING E SUGESTÕES DO MENU INICIAR (WIN 10/11)
# Contexto: Remoção de requisições de rede, anúncios, sugestões baseadas em IA e 
# histórico de uso da interface do Menu Iniciar para obter abertura instantânea 
# e zero consumo de rede ao abrir o menu.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para alterar Políticas do Sistema."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "     PURGA DE TELEMETRIA E SUGESTÕES DO MENU INICIAR (UI CLEAN)     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

# ==============================================================================
# 1. REMOÇÃO DE RESULTADOS DA WEB E BING NA BUSCA LOCAL
# ==============================================================================
Write-Host "`n[*] Desativando integração com Bing no Menu Iniciar..." -ForegroundColor DarkGray

 $SearchPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
if (-not (Test-Path $SearchPolicyPath)) { New-Item -Path $SearchPolicyPath -Force | Out-Null }

 $SearchSettings = @{
    "DisableWebSearch" = 1
    "ConnectedSearchUseBing" = 0
}

foreach ($setting in $SearchSettings.Keys) {
    $val = $SearchSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $SearchPolicyPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $SearchPolicyPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Search: $setting"; Acao = "Configurado (Sem Bing)"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Search: $setting"; Acao = "Já estava configurado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Search: $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 2. DESATIVAÇÃO DE RECOMENDAÇÕES, DESTAQUES E "MAIS USADOS"
# ==============================================================================
Write-Host "[*] Limpando seções promocionais e de rastreamento..." -ForegroundColor DarkGray

 $StartPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer"
if (-not (Test-Path $StartPolicyPath)) { New-Item -Path $StartPolicyPath -Force | Out-Null }

 $StartSettings = @{
    "EnableSearchHighlights" = 0 # Remove desenhos promocionais da barra
    "HideRecommendedSection" = 1 # Oculta a seção de recomendações da nuvem
    "Start_HideFrequentApps"  = 1 # Oculta a seção "Mais usados" (Para de ler histórico)
}

foreach ($setting in $StartSettings.Keys) {
    $val = $StartSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $StartPolicyPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $StartPolicyPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Start: $setting"; Acao = "Desativado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Start: $setting"; Acao = "Já estava desativado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Start: $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 3. SUPRESSÃO DE CONTEÚDO PROMOCIONAL DA SHELL (CONTENT DELIVERY)
# ==============================================================================
Write-Host "[*] Bloqueando sistema de entrega de anúncios (CDM)..." -ForegroundColor DarkGray

 $ContentDeliveryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $ContentDeliveryPath)) { New-Item -Path $ContentDeliveryPath -Force | Out-Null }

 $CDMSettings = @{
    "SubscribedContent-338387Enabled" = 0 # Dicas na interface
    "SubscribedContent-310093Enabled" = 0 # Experiência de boas-vindas
    "SystemAndContentSuggestionsEnabled" = 0 # Sugestões gerais
}

foreach ($setting in $CDMSettings.Keys) {
    $val = $CDMSettings[$setting]
    try {
        if ((Get-ItemProperty -Path $ContentDeliveryPath -Name $setting -ErrorAction SilentlyContinue).$setting -ne $val) {
            Set-ItemProperty -Path $ContentDeliveryPath -Name $setting -Value $val -Type DWord -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Bloqueado"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Já estava bloqueado"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "CDM: $setting"; Acao = "Falha ao gravar"; Status = "ERRO" }
    }
}

# ==============================================================================
# 4. DESATIVAR SEARCH BOX DINÂMICO (WINDOWS 11)
# Contexto: No Win11 22H2+, a barra de pesquisa fica atualizando dinamicamente 
# para sugestões baseadas em tempo real. Desativar isso corta a telemetria ativa.
# ==============================================================================
Write-Host "[*] Desativando Search Box Dinâmico (Win11)..." -ForegroundColor DarkGray

 $SearchSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings"
if (-not (Test-Path $SearchSettingsPath)) { New-Item -Path $SearchSettingsPath -Force | Out-Null }

 $prop = "IsDynamicSearchBoxEnabled"; $val = 0
try {
    if ((Get-ItemProperty -Path $SearchSettingsPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $SearchSettingsPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Dynamic Search Box"; Acao = "Desativado"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Dynamic Search Box"; Acao = "Já estava desativado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Dynamic Search Box"; Acao = "Falha ao gravar"; Status = "ERRO" }
}

# ==============================================================================
# 5. REINICIALIZAÇÃO SEGURA DA INTERFACE (SEM MATAR O EXPLORER)
# ==============================================================================
 $needsRestart = $LogTweaks | Where-Object { $_.Status -eq "SUCESSO" }

if ($needsRestart) {
    Write-Host "`n[*] Aplicando mudanças no Menu Iniciar..." -ForegroundColor DarkGray
    try {
        # MÉTODO CORRETO: O Menu Iniciar no Windows 10/11 é um AppX isolado chamado 
        # "StartMenuExperienceHost". Matar ESTE processo específico faz com que o Windows 
        # o reinicie instantaneamente em segundo plano. NÃO precisamos matar o explorer.exe 
        # (o que fecharia todas as suas pastas) para aplicar políticas do Menu Iniciar.
        Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction Stop
        
        # Dá tempo para o Windows Auto-reiniciar o processo UWP
        Start-Sleep -Milliseconds 500
        
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell: Start Menu Host"; Acao = "Reiniciado com segurança (Pastas intactas)"; Status = "SUCESSO" }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Shell: Start Menu Host"; Acao = "Falha ao reiniciar (Win10 não tem este host)"; Status = "AVISO" }
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
Write-Host "1. Clique no ícone do Windows no teclado ou abra o Menu Iniciar." -ForegroundColor White
Write-Host "2. Ele deve estar completamente limpo, sem sugestões da web, sem anúncios e sem a seção 'Recomendados'. Apenas seus aplicativos fixados aparecerão.`n" -ForegroundColor White

Read-Host "Pressione ENTER para fechar"