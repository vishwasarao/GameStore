@description('The name of the public IP address')
param publicIPName string

@description('The location for the public IP')
param location string

@description('DNS label prefix')
param dnsLabelPrefix string = ''

@description('Tags to apply to the resource')
param tags object = {}

resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: publicIPName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: empty(dnsLabelPrefix) ? null : {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

output id string = publicIP.id
output name string = publicIP.name
output ipAddress string = publicIP.properties.ipAddress
output fqdn string = empty(dnsLabelPrefix) ? '' : publicIP.properties.dnsSettings.fqdn
