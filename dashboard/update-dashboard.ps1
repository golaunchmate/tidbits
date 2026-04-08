# LaunchMate Tidbits Dashboard Updater
# This script scans the tidbits repo and updates the dashboard data
# Each founder gets their own card (separate by startup|founder)

$tidbitsPath = "C:\Users\marga\ dashboard data
# Each founder gets their own card (separate by startup|founder)

$tidbitsPath = "C:\Users\marga\OneDrive\Documents\GitHub\tidbits"
$dashboardPath = "$tidbitsPath\dashboard"
$outputJson = "$dashboardPath\data.json"

Write-Host "Scanning tidbits repo..."

$allFiles = Get-ChildItem -Path $tidbitsPath -Recurse -Filter "*.html" | Where-Object { 
    $_.FullName -notmatch "dashboard|unsorted" 
}

# Group by startup|founder to keep each person separate
$founderData = @{}

foreach ($file in $allFiles) {
    $path = $file.FullName.Replace($tidbitsPath + "\", "").Replace("\", "/")
    $parts = $path -split "/"
    
    if ($parts.Count -ge 3) {
        $program = $parts[0]
        $startup = $parts[1]
        $founder = $parts[2]
        $filename = $parts[-1]
        
        # Get metadata from file content
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        
        $title = if ($content -match '<title>([^<]+)</title>') { $matches[1] } else { $filename -replace '\.html$', '' }
        $date = if ($content -match 'tidbit-date" content="([^"]+)"') { $matches[1] } elseif ($content -match '(\d{4}-\d{2}-\d{2})') { $matches[1] } else { "2026-01-30" }
        $summary = if ($content -match 'tidbit-description" content="([^"]+)"') { $matches[1] } else { "Agent-generated tidbit" }
        $company = if ($content -match 'tidbit-company" content="([^"]+)"') { $matches[1] } else { "" }
        
        $status = if ($program -eq "bootcamp-spring-26") { "inactive" } else { "active" }
        
        # Key by startup|founder to keep each person separate
        $key = "$startup|$founder"
        if (-not $founderData[$key]) {
            $founderData[$key] = @{
                name = if ($company) { $company } else { $startup -replace '-', ' ' }
                founder = $founder -replace '-', ' '
                program = $program
                startup = $startup
                status = $status
                lastUpdate = $date
                count = 0
                files = @()
            }
        }
        
        $founderData[$key].count++
        if ($date -gt $founderData[$key].lastUpdate) {
            $founderData[$key].lastUpdate = $date
        }
        
        $founderData[$key].files += @{
            name = $title
            date = $date
            path = $path
            summary = $summary
        }
    }
}

# Sort files by date within each founder and capitalize founder name
$founderData.Values | ForEach-Object {
    $_.files = $_.files | Sort-Object date -Descending
    $_.founder = (Get-Culture).TextInfo.ToTitleCase($_.founder)
}

# Export to JSON
$jsonData = $founderData.Values | Sort-Object { $_.program }, { $_.name } | ForEach-Object {
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

Write-Host "Updated $outputJson"
Write-Host "Total founders: $($founderData.Count)"
Write-Host "Total files: $(($founderData.Values | ForEach-Object { $_.count } | Measure-Object -Sum).Sum)"
