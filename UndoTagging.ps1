<#    
    .NOTES
    ===========================================================================
     Created with:  SAPIEN Technologies, Inc., PowerShell Studio 2023 v5.8.218
     Created on:    3/2/2023 1:17 PM
     Created by:    David Farris
     Organization:  HUB International
     Filename:      
    ===========================================================================
    .DESCRIPTION
        A description of the file.
#>
# Set the name of the Service Principal Name (SPN)
$spnName = "VIU-PROPREADER-TST"

# Set the subscription ID
$subscriptionId = "ca7fda85-95c3-40e0-a882-e8401ee222c8"

# Set the App ID and Secret for the SPN
$appId = "fcf29546-eec4-4df1-86de-7624914ccf99"
$appSecret = ".eI8Q~fzbnHtvc6x4uThn1np-32Y2nMEB4z7PbEl"

# Connect to Azure and set the subscription context
Connect-AzAccount
Set-AzContext -SubscriptionId $subscriptionId

# Get a bearer token for the specified service principal
$tokenResponse = Invoke-RestMethod -Method POST `
                                   -Uri "https://login.microsoftonline.com/f28afbab-f557-4245-9536-71946b3d59f7/oauth2/token" `
                                   -Body @{
    grant_type    = "client_credentials"
    client_id     = $appId
    client_secret = $appSecret
    resource      = "https://management.azure.com/"
}

$accessToken = $tokenResponse.access_token

# Invoke the Azure REST API to get the properties of each resource in your subscription
$resources = Invoke-RestMethod -Uri "https://management.azure.com/subscriptions/$subscriptionId/resources?api-version=2021-04-01&`$expand=createdTime,location" -Headers @{ Authorization = "Bearer $($accessToken)" }

# Format the createdTime property to "yyyy-MM-dd HH:mm"
$output = $resources.value | Select-Object Name,
                                           ResourceType,
                                           Location,
                                           @{ Name = "CreatedDate"; Expression = { $_.createdTime -as [datetime] | Get-Date -Format "yyyy-MM-dd HH:mm" } },
                                           @{ Name = "Tags"; Expression = { $_.Tags | ConvertTo-Json -Depth 1 -Compress } },
                                           @{ Name = "ResourceId"; Expression = { $_.id } }

# Remove the CreatedDate tag from each resource
$output | ForEach-Object {
    $resourceId = $_.ResourceId
    $tags = $_.Tags
    # If tags exist, remove the CreatedDate tag
    if ($tags -ne $null)
    {
        $tags.Remove("CreatedDate")
        # Set the resource tags with the updated tags
        Set-AzResource -ResourceId $resourceId -Tag $tags -Force -Confirm:$false
        # Check if the tag update was successful, and if not, write a warning message to a log file
        if ($? -eq $false)
        {
            $errorMessage = "Error occurred while setting tag for resource $resourceId"
            Write-Warning $errorMessage
            $errorMessage | Out-File -FilePath "C:\temp\tagsError.log" -Append
        }
    }

    