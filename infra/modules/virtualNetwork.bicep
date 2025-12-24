@description('The name of the virtual network')
param vnetName string

@description('The location for the virtual network')
param location string

@description('Address prefix for the virtual network')
param addressPrefix string = '10.0.0.0/16'

@description('Subnet name')
param subnetName string = 'default'

@description('Subnet address prefix')
param subnetPrefix string = '10.0.0.0/24'

@description('Tags to apply to the resource')
param tags object = {}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    dhcpOptions: {
      dnsServers: [
        '168.63.129.16' // Azure DNS
        '8.8.8.8'       // Google DNS (fallback)
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

output id string = virtualNetwork.id
output name string = virtualNetwork.name
output subnetId string = virtualNetwork.properties.subnets[0].id
