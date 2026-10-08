# ==============================================================================
# OTIMIZAÇÃO DE HARDWARE DE INTERAÇÃO (FORÇAGEM DE MSI - LOW DPC LATENCY)
# Contexto: Substituir IRQs legadas por Message Signaled Interrupts (MSI) na 
# GPU, NVMe, Rede e Áudio para eliminar gargalos de interrupção e DPC Latency.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar o registro de hardware."
    Read-Host "Pressione ENTER para sair"
    exit
}

# ==============================================================================
# ELEVAÇÃO DE PRIVILÉGIOS DO TOKEN (P/INVOKE C# CORRIGIDO PARA PS 5.1)
# ==============================================================================
if (-not ("Priv.Privilege" -as [type])) {
    $CSharpCode = @'
    using System;
    using System.Runtime.InteropServices;

    namespace Priv {
        public class Privilege {
            [DllImport("advapi32.dll", SetLastError = true)] 
            public static extern bool OpenProcessToken(IntPtr h, int acc, out IntPtr phtok);
            
            [DllImport("advapi32.dll", SetLastError = true)] 
            public static extern bool LookupPrivilegeValue(string host, string name, out long pluid);
            
            [DllImport("advapi32.dll", SetLastError = true)] 
            public static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
            
            [StructLayout(LayoutKind.Sequential, Pack = 1)] 
            public struct TokPriv1Luid { public int Count; public long Luid; public int Attr; }
            
            public const int SE_PRIVILEGE_ENABLED = 0x00000002;
            public const int TOKEN_QUERY = 0x00000008;
            public const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
            
            public static bool Enable(string privilege) {
                IntPtr htok; TokPriv1Luid tp;
                if (!OpenProcessToken(System.Diagnostics.Process.GetCurrentProcess().Handle, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, out htok)) return false;
                tp.Count = 1; tp.Luid = 0; tp.Attr = SE_PRIVILEGE_ENABLED;
                if (!LookupPrivilegeValue(null, privilege, out tp.Luid)) return false;
                return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
            }
        }
    }
'@
    Add-Type -TypeDefinition $CSharpCode
}

[Priv.Privilege]::Enable("SeTakeOwnershipPrivilege") | Out-Null
[Priv.Privilege]::Enable("SeRestorePrivilege") | Out-Null

# Caminho do Log de depuração na Área de Trabalho
 $LogPath = "$env:USERPROFILE\Desktop\Log_MSI_SYSTEM.txt"
Start-Transcript -Path $LogPath -Force | Out-Null

 $LogTweaks = @()

try {
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "          FORÇAGEM DE HARDWARE MSI (OWNERSHIP BYPASS)               " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    # SID imutável do grupo Administradores (Funciona em qualquer idioma do Windows)
    $AdminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $SystemSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")

    # ==============================================================================
    # FUNÇÃO AUXILIAR: DESBLOQUEAR CHAVE DO REGISTRO
    # ==============================================================================
    function Unlock-RegistryKey {
        param([string]$Path)
        $netPath = $Path -replace "HKLM:\\", ""
        try {
            # 1. Assumir posse (Take Ownership)
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($netPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if ($key) {
                $acl = $key.GetAccessControl()
                $acl.SetOwner($AdminSID)
                $key.SetAccessControl($acl)
                $key.Close()
            }

            # 2. Conceder Full Control
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($netPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if ($key) {
                $acl = $key.GetAccessControl()
                $rule = New-Object System.Security.AccessControl.RegistryAccessRule($AdminSID, "FullControl", "ContainerInherit", "None", "Allow")
                $acl.SetAccessRule($rule)
                $key.SetAccessControl($acl)
                $key.Close()
            }
            return $true
        } catch {
            return $false
        }
    }

    function Restore-RegistryKey {
        param([string]$Path)
        $netPath = $Path -replace "HKLM:\\", ""
        try {
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($netPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if ($key) {
                $acl = $key.GetAccessControl()
                $acl.SetOwner($SystemSID)
                $key.SetAccessControl($acl)
                $key.Close()
            }
        } catch {}
    }

    # ==============================================================================
    # FUNÇÃO MODULAR: INJETOR DE MSI
    # ==============================================================================
    function Set-DeviceMSI {
        param (
            [string]$PnpDeviceId,
            [string]$DeviceName
        )

        # Alguns dispositivos guardam em 'Device Parameters', outros não. Checamos os dois.
        $RegPath1 = "HKLM:\SYSTEM\CurrentControlSet\Enum\$PnpDeviceId\Device Parameters\Interrupt Management"
        $RegPath2 = "HKLM:\SYSTEM\CurrentControlSet\Enum\$PnpDeviceId\Interrupt Management"
        
        if (Test-Path $RegPath1) { $RegPath = $RegPath1 }
        elseif (Test-Path $RegPath2) { $RegPath = $RegPath2 }
        else {
            $script:LogTweaks += [PSCustomObject]@{ Feature = "MSI: $DeviceName"; Acao = "Chave de Interrupção não encontrada"; Status = "N/A" }
            return
        }

        $MsiPath = "$RegPath\MessageSignaledInterruptProperties"
        $AffinityPath = "$RegPath\Affinity Policy"
        $changed = $false

        try {
            # Desbloqueia as subchaves que contêm os valores a serem alterados
            $unlockMsi = Unlock-RegistryKey -Path $MsiPath
            $unlockAff = Unlock-RegistryKey -Path $AffinityPath

            if ($unlockMsi -and (Test-Path $MsiPath)) {
                $currentMsi = (Get-ItemProperty -Path $MsiPath -Name "MSISupported" -ErrorAction SilentlyContinue).MSISupported
                if ($currentMsi -ne 1) {
                    Set-ItemProperty -Path $MsiPath -Name "MSISupported" -Value 1 -Type DWord -Force -ErrorAction Stop
                    $changed = $true
                }
            }

            if ($unlockAff -and (Test-Path $AffinityPath)) {
                $currentPrio = (Get-ItemProperty -Path $AffinityPath -Name "DevicePriority" -ErrorAction SilentlyContinue).DevicePriority
                if ($currentPrio -ne 3) {
                    Set-ItemProperty -Path $AffinityPath -Name "DevicePriority" -Value 3 -Type DWord -Force -ErrorAction Stop
                    $changed = $true
                }
            }

            # Devolve a posse para o SYSTEM (Boas práticas de segurança)
            if ($unlockMsi) { Restore-RegistryKey -Path $MsiPath }
            if ($unlockAff) { Restore-RegistryKey -Path $AffinityPath }
            
            if ($changed) {
                $script:LogTweaks += [PSCustomObject]@{ Feature = "MSI: $DeviceName"; Acao = "Forçado com Prioridade Alta"; Status = "SUCESSO" }
            } else {
                $script:LogTweaks += [PSCustomObject]@{ Feature = "MSI: $DeviceName"; Acao = "Já estava otimizado"; Status = "OK" }
            }

        } catch {
            $script:LogTweaks += [PSCustomObject]@{ Feature = "MSI: $DeviceName"; Acao = "Falha: $($_.Exception.Message)"; Status = "ERRO" }
        }
    }

    # Função auxiliar para truncar nomes com segurança
    function Get-ShortName {
        param([string]$Name, [int]$Length = 35)
        if ([string]::IsNullOrWhiteSpace($Name)) { return "Desconhecido" }
        if ($Name.Length -gt $Length) { return $Name.Substring(0, $Length) }
        return $Name
    }

    # ==============================================================================
    # 1. APLICAÇÃO EM PLACAS DE VÍDEO (TODAS AS GPUs FÍSICAS)
    # ==============================================================================
    Write-Host "`n[*] Mapeando Placas de Vídeo (GPUs)..." -ForegroundColor DarkGray
    $Gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.PNPDeviceID -notmatch "Microsoft Basic Render" -and $_.AdapterRAM -gt 0 }
    if ($Gpus) {
        foreach ($Gpu in $Gpus) {
            $shortName = Get-ShortName -Name $Gpu.Name
            Set-DeviceMSI -PnpDeviceId $Gpu.PNPDeviceID -DeviceName "GPU: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MSI: GPUs"; Acao = "Nenhuma GPU física encontrada"; Status = "N/A" } }

    # ==============================================================================
    # 2. APLICAÇÃO EM ADAPTADORES DE REDE FÍSICOS
    # ==============================================================================
    Write-Host "[*] Mapeando Adaptadores de Rede..." -ForegroundColor DarkGray
    $NetAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    if ($NetAdapters) {
        foreach ($Adapter in $NetAdapters) {
            Set-DeviceMSI -PnpDeviceId $Adapter.PnpDeviceID -DeviceName "NIC: $($Adapter.Name)"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MSI: NICs"; Acao = "Nenhum adaptador físico encontrado"; Status = "N/A" } }

    # ==============================================================================
    # 3. APLICAÇÃO EM CONTROLADORES NVMe
    # ==============================================================================
    Write-Host "[*] Mapeando Controladores NVMe..." -ForegroundColor DarkGray
    $NvmeControllers = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match "NVME" -or $_.Name -match "NVM Express" }
    if ($NvmeControllers) {
        foreach ($Nvme in $NvmeControllers) {
            $shortName = Get-ShortName -Name $Nvme.Name
            Set-DeviceMSI -PnpDeviceId $Nvme.PNPDeviceID -DeviceName "NVMe: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MSI: NVMe"; Acao = "Nenhum controlador NVMe encontrado"; Status = "N/A" } }

    # ==============================================================================
    # 4. APLICAÇÃO EM DISPOSITIVOS DE ÁUDIO
    # ==============================================================================
    Write-Host "[*] Mapeando Controladores de Áudio..." -ForegroundColor DarkGray
    $AudioDevices = Get-CimInstance -ClassName Win32_SoundDevice | Where-Object { $_.Status -eq "OK" -and $_.PNPDeviceID -notmatch "BTH" }
    if ($AudioDevices) {
        foreach ($Audio in $AudioDevices) {
            $shortName = Get-ShortName -Name $Audio.Name
            Set-DeviceMSI -PnpDeviceId $Audio.PNPDeviceID -DeviceName "Audio: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "MSI: Áudio"; Acao = "Nenhum dispositivo de áudio encontrado"; Status = "N/A" } }

    # ==============================================================================
    # RESULTADO FINAL
    # ==============================================================================
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    $LogTweaks | Format-Table -AutoSize

    Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
    Write-Host "1. As mudanças de arquitetura de interrupção (MSI) exigem Reboot." -ForegroundColor White
    Write-Host "2. O BIOS/UEFI e o Windows renegociarão as rotas na placa-mãe no boot.`n" -ForegroundColor White

} catch {
    Write-Host "`n[!!!] ERRO FATAL DURANTE A EXECUÇÃO:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Stop-Transcript | Out-Null
    Read-Host "Pressione ENTER para fechar"
}