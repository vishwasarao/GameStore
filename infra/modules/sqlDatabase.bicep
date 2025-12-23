@description('The name of the SQL Database')
param databaseName string

@description('The location for the resource')
param location string

@description('The name of the SQL Server')
param sqlServerName string

@description('The SKU for the database')
param sku object = {
  name: 'Basic'
  tier: 'Basic'
}

@description('Tags for the resource')
param tags object = {}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-08-01-preview' = {
  name: '${sqlServerName}/${databaseName}'
  location: location
  tags: tags
  sku: sku
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
  }
}

output id string = sqlDatabase.id
output name string = sqlDatabase.name
