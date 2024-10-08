﻿param (
    [string]$Path = $(Read-Host -Prompt 'Path'),
    [string]$Filter = "",
    [switch]$Recurse = $false,
    [int]$KeepLast = 4,
    [int]$KeepHourly = 24,
    [int]$KeepDaily = 7,
    [int]$KeepWeekly = 4,
    [int]$KeepMonthly = 12,
    [int]$KeepYearly = 10,
    [switch]$WhatIf
)

function Main {
    $Files = Get-ChildItem -File -Path $Path -Filter $Filter -Recurse:$Recurse
    $Size = Format-FileSize ($Files | Measure-Object -Property Length -Sum).Sum
    Log "Starting, Path: $Path, Filter: $Filter, Recurse: $Recurse, Total files: $($Files.Length), Size: $Size, Keep: L$KeepLast H$KeepHourly D$KeepDaily W$KeepWeekly M$KeepMonthly Y$KeepYearly, WhatIf: $WhatIf"
    $Files = $Files | Sort-Object -Property LastWriteTime
    $List = [System.Collections.ArrayList]@()
    foreach ($File in $Files) {
        $Object = @{}
        $Object.Why = [System.Collections.ArrayList]@()
        $Object.File = $File
        $Object.Delete = $true
        $List.Add($Object) | Out-Null
    }

    # Keep last x files
    for ($x = - $KeepLast; $x -lt 0; $x++) {
        if ($List[$x]) {
            $List[$x].Delete = $false
            $List[$x].Why.Add("Last") | Out-Null
        }
    }

    # Keep last x hourly files
    for ($x = 0; $x -gt - $KeepHourly; $x--) {
        $now = Get-Date
        $from = (Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour $now.Hour -Minute 0 -Second 0).AddHours($x)
        $to = $from.AddHours(1)
        foreach ($Object in $List) {
            if ($from -le $Object.File.LastWriteTime -and $Object.File.LastWriteTime -lt $to) {
                $Object.Delete = $false
                $Object.Why.Add("Hourly") | Out-Null
                break
            }
        }
    }

    # Keep last x daily files
    for ($x = 0; $x -gt - $KeepDaily; $x--) {
        $now = Get-Date
        $from = (Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour 0 -Minute 0 -Second 0).AddDays($x)
        $to = $from.AddDays(1)
        foreach ($Object in $List) {
            if ($from -le $Object.File.LastWriteTime -and $Object.File.LastWriteTime -lt $to) {
                $Object.Delete = $false
                $Object.Why.Add("Daily") | Out-Null
                break
            }
        }
    }

    # Keep last x weekly files
    for ($x = 0; $x -gt - $KeepWeekly; $x--) {
        $now = Get-Date
        $from = (Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour 0 -Minute 0 -Second 0).AddDays(-$now.DayOfWeek.value__ + 1).AddDays($x * 7)
        $to = $from.AddDays(7)
        foreach ($Object in $List) {
            if ($from -le $Object.File.LastWriteTime -and $Object.File.LastWriteTime -lt $to) {
                $Object.Delete = $false
                $Object.Why.Add("Weekly") | Out-Null
                break
            }
        }
    }

    # Keep last x monthly files
    for ($x = 0; $x -gt - $KeepMonthly; $x--) {
        $now = Get-Date
        $from = (Get-Date -Year $now.Year -Month $now.Month -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths($x)
        $to = $from.AddMonths(1)
        foreach ($Object in $List) {
            if ($from -le $Object.File.LastWriteTime -and $Object.File.LastWriteTime -lt $to) {
                $Object.Delete = $false
                $Object.Why.Add("Monthly") | Out-Null
                break
            }
        }
    }

    # Keep last x yearly files
    for ($x = 0; $x -gt - $KeepYearly; $x--) {
        $now = Get-Date
        $from = (Get-Date -Year $now.Year -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddYears($x)
        $to = $from.AddYears(1)
        foreach ($Object in $List) {
            if ($from -le $Object.File.LastWriteTime -and $Object.File.LastWriteTime -lt $to) {
                $Object.Delete = $false
                $Object.Why.Add("Yearly") | Out-Null
                break
            }
        }
    }

    # What if
    $deleted = 0
    if ($WhatIf) {
        foreach ($Object in $List) {
            if ($Object.Why) { $why = "[$($Object.Why -join ", ")]" } else { $why = "" }
            if ($Object.Delete) { $action = "Delete" } else { $action = "Keep $why" }
            "$($Object.File.Name) @ $(DTFormat $Object.File.LastWriteTime) -> $action"
        }
    }

    # Delete files
    else {
        foreach ($Object in $List) {
            if ($Object.Delete) {
                Log "Deleting '$($Object.File.Name)' ($(Format-FileSize $Object.File.Length)) last modified at $(DTFormat $Object.File.LastWriteTime)" Yellow
                Remove-Item -Path $Object.File.FullName
                $deleted++
            }
        }
    }

    $Files = Get-ChildItem -File -Path $Path -Filter $Filter -Recurse:$Recurse
    $Size = Format-FileSize ($Files | Measure-Object -Property Length -Sum).Sum
    Log "Finished, Deleted $deleted files, $($Files.Length) files ($Size) left"
}

function Log ($Message, [System.ConsoleColor]$ForegroundColor = 7 ) {
    Write-Host $Message -ForegroundColor $ForegroundColor
    "$(DTFormat) $Message" | Out-File $PSCommandPath.Replace(".ps1", ".log") -Append
}

function DTFormat ([datetime]$datetime = $(Get-Date)) {
    Get-Date -Date $datetime -Format "yyyy-MM-dd HH:mm"
}

function Format-FileSize ([int64]$Size) {
    if ($Size -gt 1TB) { [string]::Format("{0:0.00} TB", $Size / 1TB) }
    elseif ($Size -gt 1GB) { [string]::Format("{0:0.00} GB", $Size / 1GB) }
    elseif ($Size -gt 1MB) { [string]::Format("{0:0.00} MB", $Size / 1MB) }
    elseif ($Size -gt 1KB) { [string]::Format("{0:0.00} kB", $Size / 1KB) }
    elseif ($Size -gt 0) { [string]::Format("{0:0.00} B", $Size) }
    else { "" }
}

Main
