targetScope = 'resourceGroup'

@description('The location for all resources')
param location string = 'uksouth'

@description('SQL Server administrator username')
param sqlAdminUsername string = 'sqladmin'

@description('SQL Server administrator password')
@secure()
param sqlAdminPassword string

@description('The object ID for Key Vault access (your user or service principal)')
param keyVaultAccessObjectId string

// Dev environment specific settings
var environmentName = 'dev'
var appName = 'gamestore'
var appServicePlanSku = 'S1' // Standard tier (Basic/Free tiers have no quota)
var sqlDatabaseSku = {
  name: 'Basic'
  tier: 'Basic'
}

var uniqueSuffix = uniqueString(resourceGroup().id)
var resourceNamePrefix = '${appName}-${environmentName}-${uniqueSuffix}'

var commonTags = {
  environment: environmentName
  application: appName
  managedBy: 'bicep'
  owner: 'dev-team-alpha'
}

// App Service Plan
module appServicePlan '../../../modules/appServicePlan.bicep' = {
  name: 'appServicePlan-deployment'
  params: {
    appServicePlanName: '${resourceNamePrefix}-plan'
    location: location
    sku: appServicePlanSku
    tags: commonTags
  }
}

// Key Vault (name must be 3-24 chars, alphanumeric + hyphens, no consecutive hyphens)
module keyVault '../../../modules/keyVault.bicep' = {
  name: 'keyVault-deployment'
  params: {
    keyVaultName: 'kv${appName}${environmentName}${take(uniqueSuffix, 8)}' // kv + gamestore + dev + 8 chars
    location: location
    principalId: keyVaultAccessObjectId
    tags: commonTags
  }
}

// Store SQL password in Key Vault
module sqlPasswordSecret '../../../modules/keyVaultSecret.bicep' = {
  name: 'sqlPasswordSecret-deployment'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'sql-admin-password'
    secretValue: sqlAdminPassword
  }
}

// Application Insights
module appInsights '../../../modules/appInsights.bicep' = {
  name: 'appInsights-deployment'
  params: {
    appInsightsName: '${resourceNamePrefix}-insights'
    location: location
    tags: commonTags
  }
}

// SQL Server
module sqlServer '../../../modules/sqlServer.bicep' = {
  name: 'sqlServer-deployment'
  params: {
    sqlServerName: '${resourceNamePrefix}-sql'
    location: location
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    tags: commonTags
  }
}

// SQL Database
module sqlDatabase '../../../modules/sqlDatabase.bicep' = {
  name: 'sqlDatabase-deployment'
  params: {
    databaseName: 'GameStoreDB'
    location: location
    sqlServerName: sqlServer.outputs.name
    sku: sqlDatabaseSku
    tags: commonTags
  }
}

// Web App
module webApp '../../../modules/webApp.bicep' = {
  name: 'webApp-deployment'
  params: {
    webAppName: '${resourceNamePrefix}-api'
    location: location
    appServicePlanId: appServicePlan.outputs.id
    dotnetVersion: 'DOTNETCORE|10.0'
    appSettings: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.connectionString
      }
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Development'
      }
      {
        name: 'FEATURE_FLAG_NEWUI'
        value: 'true'
      }
      {
        name: 'ConnectionStrings__GameStoreDB'
        value: 'Server=tcp:${sqlServer.outputs.fullyQualifiedDomainName},1433;Initial Catalog=GameStoreDB;Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
      }
    ]
    tags: commonTags
  }
}

output webAppUrl string = webApp.outputs.url
output webAppName string = webApp.outputs.name
output appInsightsConnectionString string = appInsights.outputs.connectionString
output sqlServerName string = sqlServer.outputs.name
output sqlDatabaseName string = 'GameStoreDB'
output keyVaultName string = keyVault.outputs.name
