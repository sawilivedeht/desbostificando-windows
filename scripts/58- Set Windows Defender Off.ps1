# ==============================================================================
# DESATIVAÇÃO COMPLETA DO WINDOWS DEFENDER (HARDENING DE PERFORMANCE EXTREMO)
# Contexto: Remoção total da infraestrutura de antivírus para recuperação máxima 
# de CPU, RAM e eliminação de I/O de disco em segundo plano.
# Requer: Execução como Administrador.
# ==============================================================================

# 0. Verificação de Privilégios de Administrador
 $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Este script requer privilégios de Administrador para matar serviços protegidos."
    exit
}

Write-Host "======================================================================" -ForegroundColor Red
Write-Host "             DESATIVAÇÃO TOTAL DO WINDOWS DEFENDER                  " -ForegroundColor Red
Write-Host "======================================================================" -ForegroundColor Red
Write-Host "ATENÇÃO: Seu computador ficará TOTALMENTE SEM PROTEÇÃO contra vírus, malwares e ransomwares." -ForegroundColor Yellow
Write-Host "Não baixe arquivos nem navegue em sites suspeitos com o Defender desligado." -ForegroundColor Yellow
 $confirm = Read-Host "Digite 'SIM' (maiúsculo) para prosseguir com a desativação"
if ($confirm -ne "SIM") { exit }

 $LogTweaks = @()

# ==============================================================================
# FUNÇÃO: ATIVAR PRIVILÉGIOS OCULTOS DO WINDOWS (TAKE OWNERSHIP)
# ==============================================================================
 $privCode = @'
using System;
using System.Runtime.InteropServices;
public class TokenManipulator {
    [DllImport("kernel32.dll", ExactSpelling = true)]
    internal static extern IntPtr GetCurrentProcess();
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TokPriv1Luid {
        public int Count;
        public long Luid;
        public int Attr;
    }
    internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
    internal const int TOKEN_QUERY = 0x00000008;
    internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
    public static bool AddPrivilege(string privilege) {
        bool retVal;
        TokPriv1Luid tp;
        IntPtr hproc = GetCurrentProcess();
        IntPtr htok = IntPtr.Zero;
        retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
        tp.Count = 1;
        tp.Luid = 0;
        tp.Attr = SE_PRIVILEGE_ENABLED;
        retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
        retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        return retVal;
    }
}
'@
Try { Add-Type -TypeDefinition $privCode -ErrorAction Stop } Catch {}
[TokenManipulator]::AddPrivilege("SeTakeOwnershipPrivilege") | Out-Null
[TokenManipulator]::AddPrivilege("SeRestorePrivilege") | Out-Null

# ==============================================================================
# FUNÇÃO: BYPASS DE TRUSTEDINSTALLER
# ==============================================================================
function Set-ProtectedRegistryValue {
    param (
        [string]$Path,
        [string]$Name,
        [int]$Value
    )

    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        
        # Tenta alterar normalmente primeiro
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ($current -eq $Value) { return @{ Status = "OK"; Acao = "Já estava desativado" } }

        # Se falhou, aplica o bypass de TrustedInstaller via .NET
        $subPath = $Path -replace "^HKLM:\\", ""
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        
        if ($key) {
            $acl = $key.GetAccessControl()
            $admin = New-Object System.Security.Principal.NTAccount("Administrators")
            $acl.SetOwner($admin)
            $key.SetAccessControl($acl)
            $key.Close()

            # Agora concede FullControl para gravar
            $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($subPath, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
            $acl = $key.GetAccessControl()
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule($admin, "FullControl", "Allow")
            $acl.SetAccessRule($rule)
            $key.SetAccessControl($acl)
            $key.Close()
        }

        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord -Force -ErrorAction Stop
        return @{ Status = "SUCESSO"; Acao = "Desativado (Bypass TI)" }
    } catch {
        return @{ Status = "ERRO"; Acao = "Acesso Negado" }
    }
}

# ==============================================================================
# 1. BYPASS DO TAMPER PROTECTION (A ORDEM É CRÍTICA)
# ==============================================================================
Write-Host "`n[*] Bypassando Tamper Protection (Proteção de Adulteração)..." -ForegroundColor DarkGray

 $shs = Get-Service -Name "SecurityHealthService" -ErrorAction SilentlyContinue
if ($shs -and $shs.Status -eq 'Running') { 
    Stop-Service -Name "SecurityHealthService" -Force -ErrorAction SilentlyContinue | Out-Null 
}

 $TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
 $res = Set-ProtectedRegistryValue -Path $TamperPath -Name "TamperProtection" -Value 0
 $LogTweaks += [PSCustomObject]@{ Feature = "Defender: Tamper Protection"; Acao = $res.Acao; Status = $res.Status }

 $SvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\SecurityHealthService"
 $res = Set-ProtectedRegistryValue -Path $SvcRegPath -Name "Start" -Value 4
 $LogTweaks += [PSCustomObject]@{ Feature = "Svc: SecurityHealthService"; Acao = $res.Acao; Status = $res.Status }

# ==============================================================================
# 2. DIRETIVAS DE POLÍTICAS (GPO MIRROR) E TEMPO REAL
# ==============================================================================
Write-Host "[*] Aplicando diretivas de desativação no registro..." -ForegroundColor DarkGray

 $DefenderPolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
 $PolicySettings = @{
    "DisableAntiSpyware" = 1
    "DisableAntiVirus"   = 1
}

foreach ($setting in $PolicySettings.Keys) {
    $res = Set-ProtectedRegistryValue -Path $DefenderPolicyPath -Name $setting -Value $PolicySettings[$setting]
    $LogTweaks += [PSCustomObject]@{ Feature = "Policy: $setting"; Acao = $res.Acao; Status = $res.Status }
}

 $RealTimePath = "$DefenderPolicyPath\Real-Time Protection"
 $RtSettings = @{
    "DisableRealtimeMonitoring" = 1
    "DisableBehaviorMonitoring" = 1
    "DisableOnAccessProtection" = 1
    "DisableScanOnRealtimeEnable" = 1
}

foreach ($setting in $RtSettings.Keys) {
    $res = Set-ProtectedRegistryValue -Path $RealTimePath -Name $setting -Value $RtSettings[$setting]
    $LogTweaks += [PSCustomObject]@{ Feature = "RealTime: $setting"; Acao = $res.Acao; Status = $res.Status }
}

# ==============================================================================
# 3. DESATIVAÇÃO DO CLOUD / SPYNET (NÍVEL DE REGISTRO)
# ==============================================================================
Write-Host "[*] Desativando proteção em nuvem (Spynet)..." -ForegroundColor DarkGray

 $SpynetPath = "$DefenderPolicyPath\Spynet"
 $CloudSettings = @{
    "SpynetReporting" = 0
    "SubmitSamplesConsent" = 2
}

foreach ($setting in $CloudSettings.Keys) {
    $res = Set-ProtectedRegistryValue -Path $SpynetPath -Name $setting -Value $CloudSettings[$setting]
    $LogTweaks += [PSCustomObject]@{ Feature = "Cloud: $setting"; Acao = $res.Acao; Status = $res.Status }
}

# ==============================================================================
# 4. COMANDO MPCONFIG / SET-MPPREFERENCE (FALLBACK)
# ==============================================================================
Write-Host "[*] Aplicando MpPreference (Pode falhar se Tamper Proteção impedir)..." -ForegroundColor DarkGray

try {
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableBlockAtFirstSeen $true -DisableIOAVProtection $true -DisableScriptScanning $true -SubmitSamplesConsent 2 -MAPSReporting 0 -ErrorAction Stop
    $LogTweaks += [PSCustomObject]@{ Feature = "Cmdlet: Set-MpPreference"; Acao = "Aplicado com sucesso"; Status = "SUCESSO" }
} catch {
    $LogTweaks += [PSCustomObject]@{ Feature = "Cmdlet: Set-MpPreference"; Acao = "Falha bloqueada (Apenas Reboot)"; Status = "AVISO" }
}

# ==============================================================================
# 5. INTERRUPÇÃO DOS DAEMONS NO KERNEL (BYPASS DE PPL)
# ==============================================================================
Write-Host "[*] Matando serviços no nível do kernel (Contornando PPL)..." -ForegroundColor DarkGray

 $SecurityServices = @(
    "WinDefend",             # Motor principal
    "WdNisSvc",              # Network Inspection
    "Sense",                 # ATP Service
    "wscsvc"                 # Central de Segurança
)

foreach ($Svc in $SecurityServices) {
    $SvcRegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$Svc"
    if (Test-Path $SvcRegPath) {
        $res = Set-ProtectedRegistryValue -Path $SvcRegPath -Name "Start" -Value 4
        $LogTweaks += [PSCustomObject]@{ Feature = "Svc Kernel: $Svc"; Acao = $res.Acao; Status = $res.Status }
    }
}

# ==============================================================================
# 6. DESATIVAÇÃO DAS TAREFAS AGENDADAS DO DEFENDER
# ==============================================================================
Write-Host "[*] Desativando tarefas agendadas de verificação..." -ForegroundColor DarkGray

 $DefenderTasks = @(
    "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan"
)

foreach ($TaskPath in $DefenderTasks) {
    $TaskName = Split-Path $TaskPath -Leaf
    $TaskFolder = Split-Path $TaskPath
    
    try {
        $task = Get-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop
        if ($task.State -ne 'Disabled') {
            Disable-ScheduledTask -TaskName $TaskName -TaskPath $TaskFolder -ErrorAction Stop | Out-Null
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Desativada"; Status = "SUCESSO" }
        } else {
            $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Já estava desativada"; Status = "OK" }
        }
    } catch {
        $LogTweaks += [PSCustomObject]@{ Feature = "Task: $TaskName"; Acao = "Não encontrada ou erro"; Status = "INFO" }
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

Write-Host "`n[!] PASSO FINAL OBRIGATÓRIO: O Windows Defender é um processo protegido rígido (PPL)." -ForegroundColor Red
Write-Host "[!] Você DEVE REINICIAR O COMPUTADOR agora. As alterações no registro só sobrescreverão a proteção de kernel após o boot.`n" -ForegroundColor Red