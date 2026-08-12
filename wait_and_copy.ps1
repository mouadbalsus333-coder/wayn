param(
    [string]$OutFile,
    [string]$DestFile
)
$max = 300
$elapsed = 0
while ($elapsed -lt $max) {
    $done = $true
    $procs = Get-Process -Name python* -ErrorAction SilentlyContinue |
        Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-5) }
    if ($procs) { $done = $false }
    if (Test-Path $OutFile) {
        $info = Get-Item $OutFile
        if ($info.Length -gt 0) {
            # check if process still writing by comparing size
            Start-Sleep -Seconds 3
            $info2 = Get-Item $OutFile
            if ($info2.Length -eq $info.Length -and -not $procs) { $done = $true }
            if ($info2.Length -ne $info.Length) { $done = $false }
        }
    }
    if ($done -and -not $procs) { break }
    Start-Sleep -Seconds 5
    $elapsed += 5
}
Copy-Item -Path $OutFile -Destination $DestFile -Force
"DONE elapsed=$elapsed" | Out-File -FilePath c:\WAYN\wayn\wait_status.txt -Encoding utf8