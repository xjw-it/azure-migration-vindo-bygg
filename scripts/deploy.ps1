# deploy.ps1 - deploys the whole Vindö Bygg lab environment with one command
#
# Before you run it:  activate the Contributor role in PIM, then run "az login".
# Usage:
#   .\scripts\deploy.ps1               preview the changes, then deploy after you confirm
#   .\scripts\deploy.ps1 -WhatIfOnly   preview only, nothing is changed
#
# The VM admin password is asked for when the script runs. It is never stored in this file.

param(
    [string]$ResourceGroup = 'RG-XiaojingWang',
    [switch]$WhatIfOnly
)

$root      = Split-Path -Parent $PSScriptRoot
$template  = Join-Path $root 'infra/main.bicep'
$startPage = Join-Path $root 'app/index.html'
$webAppName = 'prod-app-projectportal-swc'

# 1. Check that we are signed in to Azure
Write-Host '1/6 Checking Azure sign-in...' -ForegroundColor Cyan
$subscription = az account show --query name -o tsv
if ($LASTEXITCODE -ne 0) { throw 'Not signed in. Activate the PIM role and run "az login" first.' }
Write-Host "    Subscription: $subscription"

# 2. Read the SQL admin (the signed-in user) from Entra ID
Write-Host '2/6 Reading the SQL admin from Entra ID...' -ForegroundColor Cyan
$upn = az ad signed-in-user show --query userPrincipalName -o tsv
$oid = az ad signed-in-user show --query id -o tsv

# 3. Check the Bicep code for errors before talking to Azure
Write-Host '3/6 Checking the Bicep code...' -ForegroundColor Cyan
az bicep build --file $template --stdout | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Bicep build failed. Fix the errors shown above.' }

# 4. Ask for the VM password once (hidden input) and preview the changes
$securePassword = Read-Host 'VM admin password' -AsSecureString
$vmPassword = [System.Net.NetworkCredential]::new('', $securePassword).Password
$params = @("sqlAdminLogin=$upn", "sqlAdminObjectId=$oid", "alertEmail=$upn", "vmAdminPassword=$vmPassword")

Write-Host '4/6 Preview (what-if)...' -ForegroundColor Cyan
az deployment group what-if --resource-group $ResourceGroup --template-file $template --parameters @params
if ($LASTEXITCODE -ne 0) { throw 'What-if failed.' }

if ($WhatIfOnly) {
    Write-Host 'Preview only - nothing was changed.' -ForegroundColor Yellow
    return
}

$answer = Read-Host 'Deploy these changes? (y/n)'
if ($answer -ne 'y') {
    Write-Host 'Cancelled - nothing was changed.' -ForegroundColor Yellow
    return
}

# 5. Deploy the infrastructure (Bicep)
Write-Host '5/6 Deploying the infrastructure...' -ForegroundColor Cyan
$webAppUrl = az deployment group create --resource-group $ResourceGroup --template-file $template --parameters @params --query properties.outputs.webAppUrl.value -o tsv
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }
$vmPassword = $null

# 6. Upload the start page of the Project Portal
Write-Host '6/6 Uploading the Project Portal start page...' -ForegroundColor Cyan
az webapp deploy --resource-group $ResourceGroup --name $webAppName --src-path $startPage --type static --target-path index.html | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Start page upload failed.' }

Write-Host ''
Write-Host 'Done! The environment is deployed.' -ForegroundColor Green
Write-Host "Project Portal: $webAppUrl"