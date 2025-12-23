@description('The name of the Key Vault')
param keyVaultName string

@description('The name of the secret')
param secretName string

@description('The secret value')
@secure()
param secretValue string

resource secret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: '${keyVaultName}/${secretName}'
  properties: {
    value: secretValue
  }
}

output secretUri string = secret.properties.secretUri
