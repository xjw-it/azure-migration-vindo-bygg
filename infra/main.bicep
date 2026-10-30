// main.bicep - entry point for the Vindö Bygg lab environment
targetScope = 'resourceGroup'

@description('Azure region for all resources')
param location string = 'swedencentral'

@description('Environment prefix used in names and tags')
param env string = 'prod'

@description('Owner tag value')
param owner string = 'xiaojing-wang'

@description('Entra ID sign-in name of the SQL admin (given at deployment)')
param sqlAdminLogin string

@description('Entra ID object ID of the SQL admin (given at deployment)')
param sqlAdminObjectId string

@description('Admin password for the finance VM (asked at deployment, never stored in code)')
@secure()
param vmAdminPassword string

@description('Open RDP (port 3389) for my IP address only. Default: closed.')
param enableRdp bool = false

@description('My public IP address, only used when enableRdp is true')
param myIpAddress string = ''
@description('Email address that receives alerts (given at deployment)')
param alertEmail string

var regionSuffix = 'swc'

// Tag keys follow the assignment: owner, env and avdelning (department)

// Tags shared by all Projects department resources
var projectTags = {
  owner: owner
  env: env
  avdelning: 'projects'
}

// Tags for Finance department resources
var financeTags = {
  owner: owner
  env: env
  avdelning: 'finance'
}

// Tags for resources shared by all departments
var sharedTags = {
  owner: owner
  env: env
  avdelning: 'shared'
}

// File storage for drawings (replaces the file server)
module storage 'modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    location: location
    storageAccountName: '${env}stdrawings${regionSuffix}01'
    tags: projectTags
  }
}

// Web app for the Project Portal (replatform from local server)
module web 'modules/web.bicep' = {
  name: 'deploy-web'
  params: {
    location: location
    appServicePlanName: '${env}-asp-projectportal-${regionSuffix}'
    webAppName: '${env}-app-projectportal-${regionSuffix}'
    tags: projectTags
  }
}

// Database for the Project Portal (replatform from SQL Server)
module sql 'modules/sql.bicep' = {
  name: 'deploy-sql'
  params: {
    location: location
    sqlServerName: '${env}-sql-projectportal-${regionSuffix}'
    sqlDatabaseName: '${env}-sqldb-projectportal-${regionSuffix}'
    sqlAdminLogin: sqlAdminLogin
    sqlAdminObjectId: sqlAdminObjectId
    tags: projectTags
  }
}

// Windows VM for the finance system (rehost)
module vm 'modules/vm.bicep' = {
  name: 'deploy-vm'
  params: {
    location: location
    vmName: '${env}-vm-finance-${regionSuffix}'
    computerName: '${env}vmfinance' // Windows computer name: max 15 characters
    vmSize: 'Standard_B2als_v2'
    adminUsername: 'vindoadmin'
    adminPassword: vmAdminPassword
    enableRdp: enableRdp
    myIpAddress: myIpAddress
  
    vnetName: '${env}-vnet-finance-${regionSuffix}'
    nsgName: '${env}-nsg-finance-${regionSuffix}'
    nicName: '${env}-nic-vm-finance-${regionSuffix}'
    publicIpName: '${env}-pip-vm-finance-${regionSuffix}'
    tags: financeTags
  }
}
// Backup for the finance VM (replaces the USB backup)
module backup 'modules/backup.bicep' = {
  name: 'deploy-backup'
  params: {
    location: location
    vaultName: '${env}-rsv-backup-${regionSuffix}'
    policyName: 'bkpol-vm-daily'
    vmName: vm.outputs.vmName
    vmId: vm.outputs.vmId
    tags: sharedTags
  }
}

// Monitoring: email alerts for high CPU and deleted resources
module monitoring 'modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  params: {
    actionGroupName: '${env}-ag-itops-${regionSuffix}'
    alertEmail: alertEmail
    vmId: vm.outputs.vmId
    tags: sharedTags
  }
}
// Show the Project Portal URL after deployment
output webAppUrl string = web.outputs.webAppUrl
