$global:FQDN = "yourVA.yourDomain.com"
$global:TOKEN = "insertYourOwnAPIKeyHere"
 
$global:HEADER = @{
    "Accept" = "application/json"
    "Authorization" = "Bearer $global:TOKEN"
}

function Build-QueryString {
    param ([hashtable]$Params)
    $queryParts = @()
    foreach ($param in $Params.GetEnumerator()) {
        $queryParts += "$($param.Key)=$($param.Value)"
    }
    return $queryParts -join "&"
}

# Function to get application measurements, average durations, and output results to a CSV file
function Get-ApplicationMeasurementsWithIds {
    param (
        [string[]]$testRunIds  # Accepting an array of test run IDs
    )
    
    try {
        # Initialize results collection
        $allResults = @()

        # API call for applications to map IDs to names once
        $applicationsUrl = "https://$global:FQDN/publicApi/v7-preview/applications"
        $applicationsParams = @{
            "orderBy" = "name"
            "direction" = "asc"
            "count" = 100
            "include" = "none"
        }
        $queryString = Build-QueryString -Params $applicationsParams
        $fullApplicationsUrl = $applicationsUrl + "?" + $queryString
        $applicationsResponse = Invoke-RestMethod -Uri $fullApplicationsUrl -Method Get -Headers $global:HEADER
        $applications = $applicationsResponse.items
        
        # Map application IDs to names
        $appIdToName = @{}
        foreach ($app in $applications) {
            $appIdToName[$app.id] = $app.name
        }

        # Process each test run ID
        foreach ($testRunId in $testRunIds) {
            $measurementsUrl = "https://$global:FQDN/publicApi/v7-preview/test-runs/$testRunId/measurements"
            $measurementsParams = @{
                "direction" = "desc"
                "count" = 100
                "include" = "applicationMeasurements"
            }
            $queryString = Build-QueryString -Params $measurementsParams
            $fullMeasurementsUrl = $measurementsUrl + "?" + $queryString
            $measurementsResponse = Invoke-RestMethod -Uri $fullMeasurementsUrl -Method Get -Headers $global:HEADER
            $measurements = $measurementsResponse.items

            # Collect results for the current test run
            foreach ($measurement in $measurements) {
                if ($measurement.applicationId -and $appIdToName.ContainsKey($measurement.applicationId)) {
                    $appEntry = New-Object PSObject -Property @{
                        appId = $measurement.applicationId
                        appName = $appIdToName[$measurement.applicationId]
                        measurementId = $measurement.measurementId
                        duration = $measurement.duration
                        testRunId = $testRunId
                    }
                    $allResults += $appEntry
                }
            }
        }

        # Output all results to CSV
        if ($allResults.Count -eq 0) {
            Write-Host "No matched results."
        } else {
            $allResults | Export-Csv -Path "allResults.csv" -NoTypeInformation
            Write-Host "All results exported to allResults.csv"
        }

        # Calculate average durations by appId and measurementId
        $groupedResults = $allResults | Group-Object appId, measurementId
        $averagedResults = $groupedResults | ForEach-Object {
            $averageDuration = ($_.Group.duration | Measure-Object -Average).Average
            [PSCustomObject]@{
                appId = $_.Name.Split(',')[0].Trim()
                appName = $appIdToName[$_.Name.Split(',')[0].Trim()]
                measurementId = $_.Name.Split(',')[1].Trim()
                averageDuration = [math]::Round($averageDuration, 2)
            }
        }

        # Output averaged results to CSV
        if ($averagedResults.Count -eq 0) {
            Write-Host "No averaged results found."
        } else {
            $averagedResults | Export-Csv -Path "averagedResults.csv" -NoTypeInformation
            Write-Host "Averaged results exported to averagedResults.csv"
        }

        return $averagedResults
    } catch {
        Write-Host "Error making API Call: $($_.Exception.Message)"
        if ($_.Exception.Response) {
            Write-Host "StatusCode: $($_.Exception.Response.StatusCode.Value__)"
            Write-Host "StatusDescription: $($_.Exception.Response.StatusDescription)"
        }
    }
}

$results = Get-ApplicationMeasurementsWithIds -testRunIds @("bad05020-2b88-45ae-a80e-ad2958ceffaa", "3ef92912-a86c-4356-8745-d77ed3905326")
