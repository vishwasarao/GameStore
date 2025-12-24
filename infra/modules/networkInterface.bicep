@description('The name of the network interface')
param nicName string

@description('The location for the network interface')
param location string

@description('The subnet ID to attach to')
param subnetId string

@description('The public IP address ID (optional)')
param publicIPId string = ''

@description('The network security group ID (optional)')
param nsgId string = ''

@description('Enable IP forwarding')
param enableIPForwarding bool = false

@description('Tags to apply to the resource')
param tags object = {}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: empty(publicIPId) ? null : {
            id: publicIPId
          }
        }
      }
    ]
    networkSecurityGroup: empty(nsgId) ? null : {
      id: nsgId
    }
    enableIPForwarding: enableIPForwarding
  }
}

output id string = networkInterface.id
output name string = networkInterface.name
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
