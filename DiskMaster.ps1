if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
$disks = Get-PhysicalDisk

Write-Host "`n=== Drive Health & Usage Report ===`n"

foreach ($disk in $disks) {
    $diskNumber = ($disk | Get-Disk).Number
    $diskObj = Get-Disk -Number $diskNumber
    $sizeGB = [math]::Round(($disk.Size / 1GB), 2)
    
    $serial = (Get-WmiObject Win32_DiskDrive | Where-Object { $_.Index -eq $diskNumber }).SerialNumber

    Write-Host "Drive #$diskNumber"
    Write-Host "Model             : $($diskObj.Model)"
    Write-Host "Serial Number     : $serial"
    Write-Host "Size              : $sizeGB GB"
    Write-Host "Bus Type          : $($disk.BusType)"
    Write-Host "Media Type        : $($disk.MediaType)"
    Write-Host "Health Status     : $($disk.HealthStatus)"
    Write-Host "Operational Status: $($disk.OperationalStatus)"

    try {
        $smart = Get-StorageReliabilityCounter -PhysicalDisk $disk

        if ($smart) {
            $wear = $smart.WearPercentage
            $lifeRemaining = 100 - $wear
            Write-Host "Life Remaining    : $lifeRemaining %"

            $yearsEst = [math]::Round((5 * $lifeRemaining / 100), 2)
            Write-Host "Est. Life Left    : $yearsEst years"
        } else {
            Write-Host "SMART data not available for this disk."
        }
    } catch {
        Write-Host "Could not retrieve SMART data."
    }
    try {
        $partitions = Get-Partition -DiskNumber $diskNumber | Where-Object { $_.AccessPaths -ne $null }
        $volumeDates = @()

        foreach ($partition in $partitions) {
            foreach ($path in $partition.AccessPaths) {
                try {
                    $volumeInfo = Get-Item $path
                    $volumeDates += $volumeInfo.CreationTime
                } catch {}
            }
        }

        if ($volumeDates.Count -gt 0) {
            $firstUsed = ($volumeDates | Sort-Object)[0]
            Write-Host "Estimated First Use: $firstUsed"
        } else {
            Write-Host "Estimated First Use: Not available"
        }
    } catch {
        Write-Host "Estimated First Use: Error retrieving"
    }

    Write-Host "------------------------------------------`n"
}
Write-Host "`nScript complete. Press any key to exit..."
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

