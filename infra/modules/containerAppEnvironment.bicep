@description('The name of the Container App Environment')
param containerAppEnvName string

@description('The location for the resource')
param location string

@description('The Log Analytics Workspace ID')
param logAnalyticsWorkspaceId string

@description('The Log Analytics Workspace Customer ID')
param logAnalyticsCustomerId string

@description('Tags for the resource')
param tags object = {}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
  }
}

output id string = containerAppEnv.id
output name string = containerAppEnv.name
output defaultDomain string = containerAppEnv.properties.defaultDomain
