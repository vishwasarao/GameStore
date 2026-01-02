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

@description('Publisher email for API Management')
param apimPublisherEmail string = 'admin@gamestore.com'

@description('Publisher name for API Management')
param apimPublisherName string = 'GameStore'

@description('JWT issuer URL (e.g., https://login.microsoftonline.com/{tenant-id}/v2.0)')
param jwtIssuer string = ''

@description('JWT audience (e.g., api://gamestore-api)')
param jwtAudience string = ''

@description('JWKS URI for JWT validation (e.g., https://login.microsoftonline.com/{tenant-id}/discovery/v2.0/keys)')
param jwksUri string = ''

// Dev environment specific settings
var environmentName = 'dev'
var appName = 'gamestore'
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

// Key Vault
module keyVault '../../../modules/keyVault.bicep' = {
  name: 'keyVault-deployment'
  params: {
    keyVaultName: 'kv${appName}${environmentName}${take(uniqueSuffix, 8)}'
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

// Log Analytics Workspace
module logAnalytics '../../../modules/logAnalytics.bicep' = {
  name: 'logAnalytics-deployment'
  params: {
    workspaceName: '${resourceNamePrefix}-logs'
    location: location
    tags: commonTags
  }
}

// Container Registry
module containerRegistry '../../../modules/containerRegistry.bicep' = {
  name: 'containerRegistry-deployment'
  params: {
    registryName: 'cr${appName}${environmentName}${take(uniqueSuffix, 8)}'
    location: location
    sku: 'Basic'
    tags: commonTags
  }
}

// Store ACR credentials in Key Vault
module acrUsernameSecret '../../../modules/keyVaultSecret.bicep' = {
  name: 'acrUsernameSecret-deployment'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'acr-username'
    secretValue: containerRegistry.outputs.adminUsername
  }
}

module acrPasswordSecret '../../../modules/keyVaultSecret.bicep' = {
  name: 'acrPasswordSecret-deployment'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'acr-password'
    secretValue: containerRegistry.outputs.adminPassword
  }
}

// Redis Cache
module redisCache '../../../modules/redisCache.bicep' = {
  name: 'redisCache-deployment'
  params: {
    name: '${resourceNamePrefix}-redis'
    location: location
    skuName: 'Basic'
    skuCapacity: 'C0'
    tags: commonTags
  }
}

// Store Redis connection string in Key Vault
module redisConnectionStringSecret '../../../modules/keyVaultSecret.bicep' = {
  name: 'redisConnectionStringSecret-deployment'
  params: {
    keyVaultName: keyVault.outputs.name
    secretName: 'redis-connection-string'
    secretValue: redisCache.outputs.connectionString
  }
}

// Container App Environment
module containerAppEnv '../../../modules/containerAppEnvironment.bicep' = {
  name: 'containerAppEnv-deployment'
  params: {
    containerAppEnvName: '${resourceNamePrefix}-env'
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    logAnalyticsCustomerId: logAnalytics.outputs.customerId
    tags: commonTags
  }
}

// Container App
module containerApp '../../../modules/containerApp.bicep' = {
  name: 'containerApp-deployment'
  params: {
    containerAppName: '${resourceNamePrefix}-api'
    location: location
    environmentId: containerAppEnv.outputs.id
    containerImage: 'mcr.microsoft.com/dotnet/samples:aspnetapp'
    environmentVariables: [
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsights.outputs.connectionString
      }
      {
        name: 'ASPNETCORE_ENVIRONMENT'
        value: 'Development'
      }
      {
        name: 'ConnectionStrings__GameStoreDB'
        value: 'Server=tcp:${sqlServer.outputs.fullyQualifiedDomainName},1433;Initial Catalog=GameStoreDB;Persist Security Info=False;User ID=${sqlAdminUsername};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
      }
      {
        name: 'ConnectionStrings__Redis'
        value: redisCache.outputs.connectionString
      }
    ]
    tags: commonTags
  }
}

// API Management
module apiManagement '../../../modules/apiManagement.bicep' = {
  name: 'apiManagement-deployment'
  params: {
    name: '${resourceNamePrefix}-apim'
    location: location
    skuName: 'Developer'
    skuCapacity: 1
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    appInsightsInstrumentationKey: appInsights.outputs.instrumentationKey
    enableAppInsights: true
    tags: commonTags
  }
}

// API Management - GameStore API Configuration
module gamestoreApi '../../../modules/apiManagementApi.bicep' = {
  name: 'gamestoreApi-deployment'
  params: {
    apimServiceName: apiManagement.outputs.name
    apiName: 'gamestore-api'
    apiDisplayName: 'GameStore API'
    apiDescription: 'API for managing game catalog'
    apiPath: 'api'
    serviceUrl: 'https://${containerApp.outputs.fqdn}'
    enableJwtValidation: !empty(jwtIssuer)
    jwtIssuer: jwtIssuer
    jwtAudience: jwtAudience
    jwtJwksUri: jwksUri
    enableRateLimiting: true
    rateLimitCalls: 1000  // Dev: Higher limit for testing
    rateLimitRenewalPeriod: 60
  }
}

output containerAppUrl string = containerApp.outputs.url
output containerAppFqdn string = containerApp.outputs.fqdn
output appInsightsConnectionString string = appInsights.outputs.connectionString
output sqlServerName string = sqlServer.outputs.name
output sqlDatabaseName string = 'GameStoreDB'
output keyVaultName string = keyVault.outputs.name
output containerRegistryName string = containerRegistry.outputs.name
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer
output redisCacheName string = redisCache.outputs.name
output redisCacheHostName string = redisCache.outputs.hostName
output apimGatewayUrl string = apiManagement.outputs.gatewayUrl
output apimPortalUrl string = apiManagement.outputs.portalUrl
output apimName string = apiManagement.outputs.name
