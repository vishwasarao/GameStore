targetScope = 'resourceGroup'

@description('The location for all resources')
param location string = 'eastus'

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

@description('JWT issuer URL')
param jwtIssuer string

@description('JWT audience')
param jwtAudience string

@description('JWKS URI for JWT validation')
param jwksUri string

// Staging environment specific settings
var environmentName = 'staging'
var appName = 'gamestore-api'
var appServicePlanSku = 'B1' // Basic tier for staging
var sqlDatabaseSku = {
  name: 'S0'
  tier: 'Standard'
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

// Key Vault
module keyVault '../../../modules/keyVault.bicep' = {
  name: 'keyVault-deployment'
  params: {
    keyVaultName: '${resourceNamePrefix}-kv'
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

// Redis Cache
module redisCache '../../../modules/redisCache.bicep' = {
  name: 'redisCache-deployment'
  params: {
    name: '${resourceNamePrefix}-redis'
    location: location
    skuName: 'Standard'
    skuCapacity: 'C1'
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
        value: 'Staging'
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
    skuName: 'Basic'
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
    serviceUrl: 'https://${webApp.outputs.defaultHostName}'
    enableJwtValidation: true
    jwtIssuer: jwtIssuer
    jwtAudience: jwtAudience
    jwtJwksUri: jwksUri
    enableRateLimiting: true
    rateLimitCalls: 100
    rateLimitRenewalPeriod: 60
  }
}

output webAppUrl string = webApp.outputs.url
output webAppName string = webApp.outputs.name
output appInsightsConnectionString string = appInsights.outputs.connectionString
output sqlServerName string = sqlServer.outputs.name
output sqlDatabaseName string = 'GameStoreDB'
output keyVaultName string = keyVault.outputs.name
output redisCacheName string = redisCache.outputs.name
output redisCacheHostName string = redisCache.outputs.hostName
output apimGatewayUrl string = apiManagement.outputs.gatewayUrl
output apimPortalUrl string = apiManagement.outputs.portalUrl
output apimName string = apiManagement.outputs.name
