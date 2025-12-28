# Export-AzArgToJsonPerType

This repository contains a PowerShell script `Export-AzArgToJsonPerType.ps1` that queries Azure Resource Graph for specified resource types and writes each resource type's results to a separate JSON file.

Prerequisites
- PowerShell 7+ (recommended) or Windows PowerShell 5.1
- Az PowerShell modules installed (the script will attempt to install `Az.ResourceGraph` and `Az.Accounts` if missing)
- You must be able to authenticate to Azure (e.g., `Connect-AzAccount`).

Usage

Open PowerShell in this folder and run:

```powershell
.
Export-AzArgToJsonPerType.ps1 -ResourceTypes Microsoft.Compute/virtualMachines,Microsoft.Storage/storageAccounts -OutputFolder C:\tmp\arg
```

Options
- `-ResourceTypes`: Comma-separated list of resource types to export (required). Example: `Microsoft.Compute/virtualMachines`
- `-OutputFolder`: Directory for output JSON files. Defaults to `./arg-output/<timestamp>`
- `-SubscriptionId`: Optional subscription id to scope results.

Behavior
- For each resource type, the script runs an Azure Resource Graph query and writes a JSON file named `<resource-type-with-slash-replaced-by-dash>.json`.
- The script uses `ConvertTo-Json -Depth 10`. If your resources have deeper nested objects, increase the `-Depth` value in the script.

Notes
- The script pages results with chunks (default 1000) to handle large result sets. Adjust `$first` in the script if you need a different page size.
- Consider running from an account with Reader access to the subscriptions you need.
