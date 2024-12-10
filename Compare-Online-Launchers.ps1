# Define the bearer token (replace with your actual token)
$bearerToken = "Your_token_here"

# Define the API endpoint
$apiUrl = "https://url.domain.com/publicApi/v7-preview/launchers?orderBy=name&direction=asc&count=100&offset=0&includeTotalCount=false&online=true"

# Define paths
$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Definition
$jsonFilePath = Join-Path -Path $scriptDirectory -ChildPath "predefined_launchers.json"
$logFilePath = Join-Path -Path $scriptDirectory -ChildPath "launcher_check.log"

# Function to log messages
function Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logFilePath
}

try {
    # Read predefined launchers JSON
    if (-Not (Test-Path -Path $jsonFilePath)) {
        throw "Predefined launchers file not found at $jsonFilePath"
    }

    $predefinedLaunchers = Get-Content -Path $jsonFilePath | ConvertFrom-Json

    if (-Not $predefinedLaunchers.launchers) {
        throw "Invalid JSON structure in $jsonFilePath. Expected 'launchers' array."
    }

    # Query the API
    $headers = @{ Authorization = "Bearer $bearerToken"; Accept = "application/json" }
    $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get

    if (-Not $response.items) {
        throw "Unexpected API response format. Expected 'items' array."
    }

    # Extract online launcher names
    $onlineLaunchers = $response.items | Where-Object { $_.online -eq $true } | Select-Object -ExpandProperty machineName

    # Compare online launchers with predefined list
    $predefinedLauncherNames = $predefinedLaunchers.launchers

    $missingLaunchers = $predefinedLauncherNames | Where-Object { $_ -notin $onlineLaunchers }
    $unexpectedLaunchers = $onlineLaunchers | Where-Object { $_ -notin $predefinedLauncherNames }

    # Log results
    Log "API query completed successfully."

    if ($missingLaunchers.Count -gt 0) {
        Log "Missing launchers: $($missingLaunchers -join ", ")"
    } else {
        Log "No missing launchers found."
    }

    if ($unexpectedLaunchers.Count -gt 0) {
        Log "Unexpected launchers: $($unexpectedLaunchers -join ", ")"
    } else {
        Log "No unexpected launchers found."
    }

} catch {
    # Log any errors
    Log "Error: $_"
}
