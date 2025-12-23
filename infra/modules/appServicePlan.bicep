@description('The name of the App Service Plan')
param appServicePlanName string

@description('The location for the resource')
param location string

@description('The SKU for the App Service Plan')
@allowed([
  'F1'
  'B1'
  'S1'
  'P1v2'
  'P2v2'
])
param sku string = 'F1'

@description('Tags for the resource')
param tags object = {}

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    reserved: true
  }
  kind: 'linux'
}

output id string = appServicePlan.id
output name string = appServicePlan.name
