@description('The name of the Redis cache')
param name string

@description('The location for the Redis cache')
param location string = resourceGroup().location

@description('The tags to apply to the Redis cache')
param tags object = {}

@description('The SKU of the Redis cache')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('The size of the Redis cache')
@allowed([
  'C0'
  'C1'
  'C2'
  'C3'
  'C4'
  'C5'
  'C6'
  'P1'
  'P2'
  'P3'
  'P4'
  'P5'
])
param skuCapacity string = 'C0'

@description('Enable non-SSL port (6379)')
param enableNonSslPort bool = false

@description('The minimum TLS version')
@allowed([
  '1.0'
  '1.1'
  '1.2'
])
param minimumTlsVersion string = '1.2'

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Redis configuration')
param redisConfiguration object = {}

resource redisCache 'Microsoft.Cache/redis@2023-08-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: skuName
      family: startsWith(skuCapacity, 'P') ? 'P' : 'C'
      capacity: int(substring(skuCapacity, 1))
    }
    enableNonSslPort: enableNonSslPort
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: publicNetworkAccess
    redisConfiguration: redisConfiguration
    redisVersion: '6'
  }
}

@description('The resource ID of the Redis cache')
output id string = redisCache.id

@description('The name of the Redis cache')
output name string = redisCache.name

@description('The host name of the Redis cache')
output hostName string = redisCache.properties.hostName

@description('The SSL port of the Redis cache')
output sslPort int = redisCache.properties.sslPort

@description('The primary access key')
output primaryKey string = redisCache.listKeys().primaryKey

@description('The connection string for the Redis cache')
output connectionString string = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
