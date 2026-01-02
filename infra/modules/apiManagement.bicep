@description('The name of the API Management service')
param name string

@description('The location for the API Management service')
param location string = resourceGroup().location

@description('The tags to apply to the API Management service')
param tags object = {}

@description('The SKU of the API Management service')
@allowed([
  'Consumption'
  'Developer'
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Developer'

@description('The capacity of the API Management service (units)')
param skuCapacity int = 1

@description('The email address for notifications')
param publisherEmail string

@description('The name of the organization')
param publisherName string

@description('Application Insights instrumentation key for logging')
param appInsightsInstrumentationKey string = ''

@description('Enable Application Insights integration')
param enableAppInsights bool = true

resource apiManagement 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    notificationSenderEmail: 'apimgmt-noreply@mail.windowsazure.com'
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Application Insights Logger
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = if (enableAppInsights && !empty(appInsightsInstrumentationKey)) {
  parent: apiManagement
  name: 'applicationinsights'
  properties: {
    loggerType: 'applicationInsights'
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
    isBuffered: true
    resourceId: '' // Optional: Full App Insights resource ID
  }
}

// Global Diagnostic Settings
resource diagnosticSettings 'Microsoft.ApiManagement/service/diagnostics@2023-05-01-preview' = if (enableAppInsights && !empty(appInsightsInstrumentationKey)) {
  parent: apiManagement
  name: 'applicationinsights'
  properties: {
    loggerId: appInsightsLogger.id
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

@description('The resource ID of the API Management service')
output id string = apiManagement.id

@description('The name of the API Management service')
output name string = apiManagement.name

@description('The gateway URL of the API Management service')
output gatewayUrl string = apiManagement.properties.gatewayUrl

@description('The management API URL')
output managementApiUrl string = apiManagement.properties.managementApiUrl

@description('The developer portal URL')
output portalUrl string = apiManagement.properties.developerPortalUrl

@description('The system-assigned managed identity principal ID')
output principalId string = apiManagement.identity.principalId
