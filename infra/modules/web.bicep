// web.bicep - App Service plan and web app for the Project Portal
param location string
param appServicePlanName string
param webAppName string
param tags object

// This decides size and price. F1 = Free tier (Windows).
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: 'F1'
    tier: 'Free'
  }
  kind: 'app'
}

// The website itself, running on the plan above
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app'
    identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
    }
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
