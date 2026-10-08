# ==============================================================================
# RESTAURAÇÃO DO VISUALIZADOR DE FOTOS CLÁSSICO (WINDOWS 7 VIEWER)
# Contexto: Substituir o app moderno "Fotos" (lento e pesado) pelo visualizador 
# legado, que abre instantaneamente e consome quase zero memória.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para registrar capacidades de aplicativo (HKLM)."
    Read-Host "Pressione ENTER para sair"
    exit
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "       RESTAURAÇÃO DO VISUALIZADOR DE FOTOS CLÁSSICO (LEGADO)         " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

 $LogTweaks = @()

## ==============================================================================
# 1. REGISTRO DE SEGURANÇA DA INTERFACE (GARANTIA DE EXECUÇÃO)
# ==============================================================================
Write-Host "`n[*] Verificando integridade do executável do Visualizador..." -ForegroundColor DarkGray

 $ProgIdPath = "HKLM:\SOFTWARE\Classes\PhotoViewer.FileAssoc.Tiff\shell\open\command"
if (-not (Test-Path $ProgIdPath)) { New-Item -Path $ProgIdPath -Force | Out-Null }

# O valor padrão esperado para invocar a DLL
 $expectedVal = '%SystemRoot%\System32\rundll32.exe "%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll", ImageView_Fullscreen %1'

try {
    # CORREÇÃO: Usando o objeto .NET para ler o valor (Default) de forma segura
    $regKey = Get-Item -Path $ProgIdPath -ErrorAction Stop
    $currentVal = $regKey.GetValue("") # String vazia representa o valor (Default)

    if ($currentVal -ne $expectedVal) {
        # CORREÇÃO: Usando o objeto .NET para gravar o valor (Default) de forma segura
        $regKey.SetValue("", $expectedVal, [Microsoft.Win32.RegistryValueKind]::String)
        $LogTweaks += [PSCustomObject]@{ Feature = "Core: PhotoViewer DLL"; Acao = "Comando registrado com sucesso"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "Core: PhotoViewer DLL"; Acao = "Já estava registrado"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Core: PhotoViewer DLL"; Acao = "Falha ao registrar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# 2. REGISTRO DE CAPACIDADES (FILE ASSOCIATIONS)
# ==============================================================================
Write-Host "[*] Registrando extensões de imagem no Visualizador Clássico..." -ForegroundColor DarkGray

 $PhotoViewerPath = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations"
if (-not (Test-Path $PhotoViewerPath)) {
    New-Item -Path $PhotoViewerPath -Recurse -Force | Out-Null
}

# Lista expandida de extensões (Adicionado .wdp e .dib)
 $ImageExtensions = @(
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tif", ".tiff", ".ico", ".jfif", ".webp", ".wdp", ".dib"
)

foreach ($Extension in $ImageExtensions) {
    $prop = $Extension
    $val = "PhotoViewer.FileAssoc.Tiff"
    
    try {
        if ((Get-ItemProperty -Path $PhotoViewerPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
            Set-ItemProperty -Path $PhotoViewerPath -Name $prop -Value $val -Force -ErrorAction Stop
            $LogTweaks += [PSCustomObject]@{ Feature = "Ext: $Extension"; Acao = "Vinculada ao Viewer"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Ext: $Extension"; Acao = "Já estava vinculada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Ext: $Extension"; Acao = "Falha ao vincular (Permissão?)"; Status = "ERRO" }
    }
}

# ==============================================================================
# 3. DESATIVAR O BOTÃO "EDITAR" NO VISUALIZADOR
# Contexto: O Visualizador clássico tem um botão que tenta abrir o Paint. Se você 
# usa um software de edição de imagem de terceiros ou não tem o Paint clássico 
# instalado, clicar ali gera erros. Desativar limpa a interface e evita bugs.
# ==============================================================================
Write-Host "[*] Otimizando interface do Visualizador (Removendo botão Editar)..." -ForegroundColor DarkGray

 $CapabilitiesPath = "HKLM:\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities"
 $prop = "NoEdit"
 $val = 1

try {
    if ((Get-ItemProperty -Path $CapabilitiesPath -Name $prop -ErrorAction SilentlyContinue).$prop -ne $val) {
        Set-ItemProperty -Path $CapabilitiesPath -Name $prop -Value $val -Type DWord -Force -ErrorAction Stop
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Botão Editar"; Acao = "Removido da interface"; Status = "SUCESSO" }
    } else {
        $LogTweaks += [PSCustomObject]@{ Feature = "UI: Botão Editar"; Acao = "Já estava removido"; Status = "OK" }
    }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "UI: Botão Editar"; Acao = "Falha ao gravar (Permissão?)"; Status = "ERRO" }
}

# ==============================================================================
# RESULTADO FINAL
# ==============================================================================
Clear-Host
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
 $LogTweaks | Format-Table -AutoSize

Write-Host "`n[!] COMO UTILIZAR (Não é necessário reiniciar o PC ou o Explorer):" -ForegroundColor Yellow
Write-Host "1. Clique com o BOTÃO DIREITO em qualquer imagem." -ForegroundColor White
Write-Host "2. Selecione 'Abrir com' > 'Escolher outro aplicativo'." -ForegroundColor White
Write-Host "3. O 'Visualizador de Fotos do Windows' agora estará na lista. Selecione-o." -ForegroundColor White
Write-Host "4. (Opcional) Marque a caixa 'Sempre usar este app para abrir arquivos .jpg'." -ForegroundColor White
Write-Host "`nNota: O Windows 11 não permite definir aplicativos legado como padrão diretamente pelo menu 'Configurações', apenas por este método de clique direito.`n" -ForegroundColor DarkGray

# Pausa final para o usuário conseguir ler o relatório
Read-Host "Pressione ENTER para fechar"