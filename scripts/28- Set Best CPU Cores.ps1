# ==============================================================================
# OTIMIZAÇÃO DE AFINIDADE DE HARDWARE (DPC LATENCY REDUCTION)
# Contexto: Distribuir interrupções (IRQs/MSIs) entre todos os núcleos da CPU
# para evitar sobrecarga de um núcleo específico (DPC Spikes).
# Requer: Execução como Administrador (Ownership Bypass Embutido).
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para modificar o registro de hardware."
    Read-Host "Pressione ENTER para sair"
    exit
}

# ==============================================================================
# ELEVAÇÃO DE PRIVILÉGIOS DO TOKEN (P/INVOKE C#)
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
 $LogPath = "$env:USERPROFILE\Desktop\Log_Affinity_SYSTEM.txt"
Start-Transcript -Path $LogPath -Force | Out-Null

 $LogTweaks = @()

try {
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "        DISTRIBUIÇÃO DE AFINIDADE DE INTERRUPÇÕES (DEVICE POLICY)      " -ForegroundColor Cyan
    Write-Host "======================================================================" -ForegroundColor Cyan

    # SID imutável do grupo Administradores e SYSTEM
    $AdminSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-32-544")
    $SystemSID = New-Object System.Security.Principal.SecurityIdentifier("S-1-5-18")

    # ==============================================================================
    # FUNÇÃO AUXILIAR: DESBLOQUEAR E RESTAURAR CHAVE DO REGISTRO
    # ==============================================================================
    function Unlock-RegistryKey {
        param([string]$Path)
        $netPath = $Path -replace "HKLM:\\", ""
        try {
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($netPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
            if ($key) {
                $acl = $key.GetAccessControl()
                $acl.SetOwner($AdminSID)
                $key.SetAccessControl($acl)
                $key.Close()
            }
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($netPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            if ($key) {
                $acl = $key.GetAccessControl()
                $rule = New-Object System.Security.AccessControl.RegistryAccessRule($AdminSID, "FullControl", "ContainerInherit", "None", "Allow")
                $acl.SetAccessRule($rule)
                $key.SetAccessControl($acl)
                $key.Close()
            }
            return $true
        } catch { return $false }
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

    function Get-ShortName {
        param([string]$Name, [int]$Length = 35)
        if ([string]::IsNullOrWhiteSpace($Name)) { return "Desconhecido" }
        if ($Name.Length -gt $Length) { return $Name.Substring(0, $Length) }
        return $Name
    }

    # ==============================================================================
    # FUNÇÃO MODULAR: APLICADOR DE AFINIDADE
    # ==============================================================================
    function Set-DeviceAffinity {
        param (
            [string]$PnpDeviceId,
            [string]$DeviceName
        )

        $RegPath1 = "HKLM:\SYSTEM\CurrentControlSet\Enum\$PnpDeviceId\Device Parameters\Interrupt Management\Affinity Policy"
        $RegPath2 = "HKLM:\SYSTEM\CurrentControlSet\Enum\$PnpDeviceId\Interrupt Management\Affinity Policy"
        
        if (Test-Path $RegPath1) { $AffPath = $RegPath1 }
        elseif (Test-Path $RegPath2) { $AffPath = $RegPath2 }
        else {
            $script:LogTweaks += [PSCustomObject]@{ Feature = "Affinity: $DeviceName"; Acao = "Chave de Afinidade não encontrada"; Status = "N/A" }
            return
        }

        try {
            $unlock = Unlock-RegistryKey -Path $AffPath
            $changed = $false

            if ($unlock) {
                # DevicePolicy 3 = IrqPolicyAllProcessorsInMachine
                $currentPolicy = (Get-ItemProperty -Path $AffPath -Name "DevicePolicy" -ErrorAction SilentlyContinue).DevicePolicy
                if ($currentPolicy -ne 3) {
                    Set-ItemProperty -Path $AffPath -Name "DevicePolicy" -Value 3 -Type DWord -Force -ErrorAction Stop
                    $changed = $true
                }

                # AssignmentSetGuide 0 = Deixa o Windows decidir o grupo de núcleos
                $currentGuide = (Get-ItemProperty -Path $AffPath -Name "AssignmentSetGuide" -ErrorAction SilentlyContinue).AssignmentSetGuide
                if ($null -eq $currentGuide -or $currentGuide -ne 0) {
                    Set-ItemProperty -Path $AffPath -Name "AssignmentSetGuide" -Value 0 -Type DWord -Force -ErrorAction Stop
                    $changed = $true
                }
                
                Restore-RegistryKey -Path $AffPath
            }

            if ($changed) {
                $script:LogTweaks += [PSCustomObject]@{ Feature = "Affinity: $DeviceName"; Acao = "Espalhada por todos os núcleos"; Status = "SUCESSO" }
            } elseif ($unlock) {
                $script:LogTweaks += [PSCustomObject]@{ Feature = "Affinity: $DeviceName"; Acao = "Já estava otimizada"; Status = "OK" }
            } else {
                $script:LogTweaks += [PSCustomObject]@{ Feature = "Affinity: $DeviceName"; Acao = "Falha ao desbloquear registro"; Status = "ERRO" }
            }

        } catch {
            $script:LogTweaks += [PSCustomObject]@{ Feature = "Affinity: $DeviceName"; Acao = "Bloqueado pelo driver de hardware"; Status = "ERRO" }
        }
    }

    # ==============================================================================
    # 1. AFINIDADE EM PLACAS DE REDE FÍSICAS
    # ==============================================================================
    Write-Host "`n[*] Mapeando Adaptadores de Rede..." -ForegroundColor DarkGray
    $NetAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue
    if ($NetAdapters) {
        foreach ($Adapter in $NetAdapters) {
            Set-DeviceAffinity -PnpDeviceId $Adapter.PnpDeviceID -DeviceName "NIC: $($Adapter.Name)"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Affinity: NICs"; Acao = "Nenhum adaptador físico encontrado"; Status = "N/A" } }

    # ==============================================================================
    # 2. AFINIDADE NA PLACA DE VÍDEO DEDICADA
    # ==============================================================================
    Write-Host "[*] Mapeando Placas de Vídeo..." -ForegroundColor DarkGray
    $DedicatedGpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { 
        $_.PNPDeviceID -notmatch "Microsoft Basic Render" -and $_.AdapterRAM -gt 1000000000
    }
    if ($DedicatedGpus) {
        foreach ($Gpu in $DedicatedGpus) {
            $shortName = Get-ShortName -Name $Gpu.Name
            Set-DeviceAffinity -PnpDeviceId $Gpu.PNPDeviceID -DeviceName "GPU: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Affinity: GPUs"; Acao = "Nenhuma GPU dedicada encontrada"; Status = "N/A" } }

    # ==============================================================================
    # 3. AFINIDADE EM CONTROLADORES NVMe
    # ==============================================================================
    Write-Host "[*] Mapeando Controladores NVMe..." -ForegroundColor DarkGray
    $NvmeControllers = Get-CimInstance -ClassName Win32_PnPEntity | Where-Object { $_.PNPDeviceID -match "NVME" -or $_.Name -match "NVM Express" }
    if ($NvmeControllers) {
        foreach ($Nvme in $NvmeControllers) {
            $shortName = Get-ShortName -Name $Nvme.Name
            Set-DeviceAffinity -PnpDeviceId $Nvme.PNPDeviceID -DeviceName "NVMe: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Affinity: NVMe"; Acao = "Nenhum controlador NVMe encontrado"; Status = "N/A" } }

    # ==============================================================================
    # 4. AFINIDADE EM CONTROLADORES DE ÁUDIO HD
    # ==============================================================================
    Write-Host "[*] Mapeando Controladores de Áudio..." -ForegroundColor DarkGray
    $AudioDevices = Get-CimInstance -ClassName Win32_SoundDevice | Where-Object { $_.Status -eq "OK" -and $_.PNPDeviceID -notmatch "BTH" }
    if ($AudioDevices) {
        foreach ($Audio in $AudioDevices) {
            $shortName = Get-ShortName -Name $Audio.Name
            Set-DeviceAffinity -PnpDeviceId $Audio.PNPDeviceID -DeviceName "Audio: $shortName"
        }
    } else { $LogTweaks += [PSCustomObject]@{ Feature = "Affinity: Áudio"; Acao = "Nenhum dispositivo de áudio encontrado"; Status = "N/A" } }

    # ==============================================================================
    # RESULTADO FINAL
    # ==============================================================================
    Clear-Host
    Write-Host "======================================================================" -ForegroundColor Green
    Write-Host "                    RELATÓRIO DE APLICAÇÃO                          " -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Green
    $LogTweaks | Format-Table -AutoSize

    Write-Host "`n[!] NOTAS IMPORTANTES:" -ForegroundColor Yellow
    Write-Host "1. Alguns drivers (especialmente NVIDIA) bloqueiam a alteração da Affinity Policy. Se marcar 'ERRO' para a GPU, é normal e seguro." -ForegroundColor White
    Write-Host "2. As mudanças exigem Reboot para que o Windows renegocie as rotas de interrupção com a placa-mãe.`n" -ForegroundColor White

} catch {
    Write-Host "`n[!!!] ERRO FATAL DURANTE A EXECUÇÃO:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
} finally {
    Stop-Transcript | Out-Null
    Read-Host "Pressione ENTER para fechar"
}