<#
.SYNOPSIS
Exports Azure Resource Graph query results to JSON files, one per resource type.

.DESCRIPTION
This script queries Azure Resource Graph for specified resource types and writes
the results into separate JSON files (one file per resource type). It uses
Azure PowerShell (Az module) and the `Search-AzGraph` cmdlet.

.PARAMETER ResourceTypes
An array of resource types to query (e.g. Microsoft.Compute/virtualMachines).

.PARAMETER OutputFolder
Directory where JSON files will be written. Defaults to .\arg-output\<timestamp>.

.PARAMETER SubscriptionId
Optional subscription id to scope the query via `where subscriptionId == '<id>'`.

.EXAMPLE
.
.\Export-AzArgToJsonPerType.ps1 -ResourceTypes Microsoft.Compute/virtualMachines,Microsoft.Storage/storageAccounts -OutputFolder C:\tmp\arg

Requirements:
- Az.ResourceGraph module (Install-Module -Name Az.ResourceGraph)
- Az.Accounts (for Connect-AzAccount)

#>

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string[]]$ResourceTypes,

    [Parameter(Mandatory=$false)]
    [string]$OutputFolder,

    [Parameter(Mandatory=$false)]
    [string]$SubscriptionId
)

function Ensure-AzModule {
    param([string]$ModuleName)
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Module $ModuleName not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber
    }
}

Ensure-AzModule -ModuleName Az.ResourceGraph
Ensure-AzModule -ModuleName Az.Accounts

if (-not (Get-AzContext)) {
    Write-Host "Not logged in. Running Connect-AzAccount..." -ForegroundColor Yellow
    Connect-AzAccount | Out-Null
}

if (-not $OutputFolder) {
    $timestamp = Get-Date -Format yyyyMMdd-HHmmss
    $OutputFolder = Join-Path -Path (Get-Location) -ChildPath ("arg-output\$timestamp")
}

if (-not (Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

foreach ($rt in $ResourceTypes) {
    Write-Host "Querying resource type: $rt" -ForegroundColor Cyan

    # Build the query. Filter by type and optionally by subscriptionId
    $typeFilter = "where type =~ '$rt'"
    $subFilter = ''
    if ($SubscriptionId) {
        $subFilter = "| where subscriptionId =~ '$SubscriptionId'"
    }

    $query = "Resources | where type =~ '$rt' $subFilter"

    # Show the actual query that will be executed
    Write-Host "Executing Azure Resource Graph query: $($query)" -ForegroundColor Yellow

    # Retrieve results in pages because Search-AzGraph limits -First/-Top to 1000
    $allResults = @()
    $first = 1000
    $skip = 0
    $iteration = 0
    $maxIterations = 1000
    while ($true) {
        $iteration++
        if ($iteration -gt $maxIterations) {
            Write-Warning "Paging loop exceeded max iterations ($maxIterations) for $($rt); aborting to avoid infinite loop. Collected $($allResults.Count) items so far."
            break
        }

        try {
            Write-Host "Executing page (skip=$skip, first=$first)" -ForegroundColor DarkYellow
            if ($skip -gt 0) {
                $page = Search-AzGraph -Query $query -First $first -Skip $skip -ErrorAction Stop
            }
            else {
                $page = Search-AzGraph -Query $query -First $first -ErrorAction Stop
            }
        }
        catch {
            $err = $_
            Write-Warning "Query failed for $($rt) at skip=$($skip): $($err.Exception.Message)"
            break
        }

        if ($null -eq $page -or $page.Count -eq 0) {
            break
        }

        $allResults += $page
        if ($page.Count -lt $first) {
            break
        }

        $skip += $first
    }

    if (-not $allResults -or $allResults.Count -eq 0) {
        Write-Host "No resources found for type $rt" -ForegroundColor DarkGray
        continue
    }

    # Prepare file name safe string (replace / with -)
    $safeName = $rt -replace '/','-'
    $outFile = Join-Path -Path $OutputFolder -ChildPath ("$safeName.json")

    # Convert to JSON with indentation and write
    try {
        $json = $allResults | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $outFile -Encoding UTF8
        Write-Host "Wrote $($allResults.Count) items to $outFile" -ForegroundColor Green
    }
    catch {
        $err = $_
        Write-Warning "Failed to write JSON for $($rt): $($err.Exception.Message)"
    }
}

Write-Host "Done. Output folder: $OutputFolder" -ForegroundColor Magenta
