targetScope = 'resourceGroup'

@description('The location for all resources')
param location string = 'westus2'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@description('Admin password for the VM')
@secure()
param adminPassword string

// Dev environment specific settings
var environmentName = 'dev'
var appName = 'gamestore'
var uniqueSuffix = uniqueString(resourceGroup().id)
var resourceNamePrefix = '${appName}-${environmentName}-${uniqueSuffix}'

var commonTags = {
  environment: environmentName
  application: appName
  managedBy: 'bicep'
  owner: 'dev-team-alpha'
  purpose: 'azure-devops-agent'
}

// Virtual Network
module vnet '../../../modules/virtualNetwork.bicep' = {
  name: 'vnet-deployment'
  params: {
    vnetName: '${resourceNamePrefix}-vnet'
    location: location
    addressPrefix: '10.0.0.0/16'
    subnetName: 'agent-subnet'
    subnetPrefix: '10.0.1.0/24'
    tags: commonTags
  }
}

// Public IP
module publicIP '../../../modules/publicIP.bicep' = {
  name: 'publicIP-deployment'
  params: {
    publicIPName: '${resourceNamePrefix}-pip'
    location: location
    dnsLabelPrefix: '${resourceNamePrefix}-agent'
    tags: commonTags
  }
}

// Network Security Group
module nsg '../../../modules/networkSecurityGroup.bicep' = {
  name: 'nsg-deployment'
  params: {
    nsgName: '${resourceNamePrefix}-nsg'
    location: location
    tags: commonTags
  }
}

// Network Interface
module nic '../../../modules/networkInterface.bicep' = {
  name: 'nic-deployment'
  params: {
    nicName: '${resourceNamePrefix}-nic'
    location: location
    subnetId: vnet.outputs.subnetId
    publicIPId: publicIP.outputs.id
    nsgId: nsg.outputs.id
    tags: commonTags
  }
}

// Load setup script
var setupScript = loadTextContent('../../../scripts/setup-azdo-agent.sh')

// Virtual Machine
module vm '../../../modules/virtualMachine.bicep' = {
  name: 'vm-deployment'
  params: {
    vmName: '${resourceNamePrefix}-agent'
    location: location
    vmSize: 'Standard_D2s_v3' // 2 vCPU, 8GB RAM - reliable availability
    adminUsername: adminUsername
    adminPasswordOrKey: adminPassword
    authenticationType: 'password'
    networkInterfaceId: nic.outputs.id
    osDiskType: 'StandardSSD_LRS'
    ubuntuVersion: '22.04-LTS'
    customData: setupScript
    tags: commonTags
  }
}

output vmName string = vm.outputs.name
output publicIPAddress string = publicIP.outputs.ipAddress
output fqdn string = publicIP.outputs.fqdn
output sshCommand string = 'ssh ${adminUsername}@${publicIP.outputs.ipAddress}'
output setupInstructions string = 'After VM is ready, SSH in and run: sudo -u ${adminUsername} /opt/azdo-agent/configure-agent.sh'
