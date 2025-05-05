# SOBR Usage Report w/ Utilization %

# 1) Load module & connect
Import-Module Veeam.Backup.PowerShell -WarningAction SilentlyContinue
$creds = Get-Credential -Message 'Enter Veeam Backup & Replication credentials'
$serverName = Read-Host -Prompt "Enter the Veeam Backup & Replication server name"
Connect-VBRServer -Server $serverName -Port 9392 -Credential $creds

# 2) Helper to extract bytes from a VMemorySize string
function Get-BytesFromVMemorySize {
    param($memSize)
    $s = $memSize.ToString()                           # e.g. "9.09 TB (9999201857536)"
    if ($s -match '\((\d+)\)') { return [int64]$matches[1] }
    return 0
}

# 3) Build report
$report = Get-VBRBackupRepository -ScaleOut | ForEach-Object {
    $s = $_
    $extentObjs = $s | Get-VBRRepositoryExtent

    $totalBytes = 0
    $freeBytes  = 0
    foreach ($e in $extentObjs) {
        $repo      = $e.Repository
        $cont      = $repo.GetContainer()
        $tb        = Get-BytesFromVMemorySize $cont.CachedTotalSpace
        $fb        = Get-BytesFromVMemorySize $cont.CachedFreeSpace
        $totalBytes += $tb
        $freeBytes  += $fb
    }

    $usedBytes = $totalBytes - $freeBytes
    $capacityGB = [math]::Round($totalBytes / 1GB, 2)
    $freeGB     = [math]::Round($freeBytes  / 1GB, 2)
    $usedGB     = [math]::Round($usedBytes  / 1GB, 2)
    $utilPct    = if ($totalBytes -gt 0) {
                      [math]::Round(($usedBytes / $totalBytes) * 100, 1)
                  } else { 0 }

    [PSCustomObject]@{
        SOBRName           = $s.Name
        TotalCapacityGB    = $capacityGB
        TotalFreeGB        = $freeGB
        TotalUsedGB        = $usedGB
        UtilizationPercent = $utilPct
        Extents            = ($extentObjs | Select-Object -ExpandProperty Name) -join '; '
        PolicyType         = $s.PolicyType
    }
}

# 4) Display & export
$report | Format-Table -AutoSize

$csvPath = 'C:\Reports\SOBR-Usage.csv'
$report | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "SOBR usage report (with utilization %) exported to $csvPath" 
