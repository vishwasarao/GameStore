@description('The name of the Web App')
param webAppName string

@description('The location for the resource')
param location string

@description('The App Service Plan ID')
param appServicePlanId string

@description('The .NET runtime version')
param dotnetVersion string = 'DOTNETCORE|10.0'

@description('Application settings')
param appSettings array = []

@description('Tags for the resource')
param tags object = {}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      linuxFxVersion: dotnetVersion
      appSettings: appSettings
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

output id string = webApp.id
output name string = webApp.name
output url string = 'https://${webApp.properties.defaultHostName}'
output defaultHostName string = webApp.properties.defaultHostName
