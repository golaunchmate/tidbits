# LaunchMate Tidbits Dashboard Updater
# This script scans the tidbits repo and updates the dashboard data

$tidbitsPath = "C:\Users\marga\OneDrive\Documents\GitHub\tidbits"
$dashboardPath = "$tidbitsPath\dashboard"
$outputJson = "$dashboardPath\data.json"

Write-Host "Scanning tidbits repo..."

$allFiles = Get-ChildItem -Path $tidbitsPath -Recurse -Filter "*.html" | Where-Object { $_.FullName -notmatch "dashboard|unsorted" }

$startupData = @{}

foreach ($file in $allFiles) {
    $path = $file.FullName.Replace($tidbitsPath + "\", "")
    $parts = $path -split "\\"
    
    if ($parts.Count -ge 3) {
        $program = $parts[0]
        $startup = $parts[1]
        $founder = $parts[2]
        $filename = $parts[-1]
        
        # Get metadata
        $title = Select-String -Path $file.FullName -Pattern '<title>([^<]+)</title>' | ForEach-Object { $_.Matches.Groups[1].Value }
        $date = Select-String -Path $file.FullName -Pattern 'tidbit-date" content="([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
        $summary = Select-String -Path $file.FullName -Pattern 'tidbit-description" content="([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
        $company = Select-String -Path $file.FullName -Pattern 'tidbit-company" content="([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value }
        
        if (-not $title) { $title = $filename -replace '\.html$', '' }
        if (-not $date) { $date = "2026-01-30" }
        if (-not $summary) { $summary = "Agent-generated tidbit" }

        $status = if ($program -eq "bootcamp-spring-26") { "inactive" } else { "active" }
        
        $key = "$startup"
        if (-not $startupData[$key]) {
            $startupData[$key] = @{
                name = if ($company) { $company } else { $startup }
                founder = $founder
                program = $program
                startup = $startup
                status = $status
                lastUpdate = $date
                count = 0
                files = @()
            }
        }
        
        $startupData[$key].count++
        if ($date -gt $startupData[$key].lastUpdate) {
            $startupData[$key].lastUpdate = $date
        }
        
        $startupData[$key].files += @{
            name = $title
            date = $date
            path = $path
            summary = $summary
        }
    }
}

# Sort files by date within each startup
$startupData.Values | ForEach-Object {
    $_.files = $_.files | Sort-Object date -Descending
}

# Export to JSON
$jsonData = $startupData.Values | Sort-Object { $_.program }, { $_.name } | ForEach-Object {
    [PSCustomObject]@{
        name = $_.name
        founder = $_.founder
        program = $_.program
        startup = $_.startup
        status = $_.status
        lastUpdate = $_.lastUpdate
        count = $_.count
        files = $_.files
    }
} | ConvertTo-Json -Depth 5

$jsonData | Out-File $outputJson -Encoding utf8

Write-Host "Updated $outputJson with $($startupData.Count) startups"
Write-Host "Total files: $(($startupData.Values | ForEach-Object { $_.count } | Measure-Object -Sum).Sum)"
