// sql.bicep - Azure SQL server and database for the Project Portal

param location string
param sqlServerName string
param sqlDatabaseName string
param sqlAdminLogin string
param sqlAdminObjectId string
param tags object

// Login method and firewall are set here
resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: sqlServerName
  location: location
  tags: tags
  properties: {
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      login: sqlAdminLogin
      sid: sqlAdminObjectId
      tenantId: subscription().tenantId
      azureADOnlyAuthentication: true
    }
  }
}

// The database itself. Basic = cheapest tier.
resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    // Geo: backups are also copied to the paired region (Sweden South, still in the EU)
    requestedBackupStorageRedundancy: 'Geo'
  }
}
