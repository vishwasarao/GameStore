@description('The name of the virtual machine')
param vmName string

@description('The location for the virtual machine')
param location string

@description('The size of the virtual machine')
@allowed([
  'Standard_B1s'
  'Standard_B1ms'
  'Standard_B2s'
  'Standard_B2ms'
  'Standard_D2s_v3'
])
param vmSize string = 'Standard_B2s'

@description('Admin username')
param adminUsername string = 'azureuser'

@description('Admin password or SSH public key')
@secure()
param adminPasswordOrKey string

@description('Type of authentication (password or sshPublicKey)')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Network interface ID')
param networkInterfaceId string

@description('OS disk type')
@allowed([
  'Standard_LRS'
  'Premium_LRS'
  'StandardSSD_LRS'
])
param osDiskType string = 'StandardSSD_LRS'

@description('Ubuntu version')
@allowed([
  '20.04-LTS'
  '22.04-LTS'
  '24.04-LTS'
])
param ubuntuVersion string = '22.04-LTS'

@description('Custom data script (cloud-init)')
param customData string = ''

@description('Tags to apply to the resource')
param tags object = {}

var linuxConfiguration = {
  disablePasswordAuthentication: authenticationType == 'sshPublicKey'
  ssh: authenticationType == 'sshPublicKey' ? {
    publicKeys: [
      {
        path: '/home/${adminUsername}/.ssh/authorized_keys'
        keyData: adminPasswordOrKey
      }
    ]
  } : null
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
        diskSizeGB: 30
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: authenticationType == 'password' ? adminPasswordOrKey : null
      customData: empty(customData) ? null : base64(customData)
      linuxConfiguration: authenticationType == 'sshPublicKey' ? linuxConfiguration : null
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterfaceId
        }
      ]
    }
  }
}

output id string = virtualMachine.id
output name string = virtualMachine.name
