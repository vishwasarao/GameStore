@description('The name of the API Management service')
param apimServiceName string

@description('The name of the API')
param apiName string

@description('The display name of the API')
param apiDisplayName string

@description('The description of the API')
param apiDescription string

@description('The path of the API')
param apiPath string

@description('The backend service URL')
param serviceUrl string

@description('Enable JWT validation')
param enableJwtValidation bool = false

@description('JWT issuer')
param jwtIssuer string = ''

@description('JWT audience')
param jwtAudience string = ''

@description('JWT JWKS URI for validation')
param jwtJwksUri string = ''

@description('Enable rate limiting')
param enableRateLimiting bool = true

@description('Rate limit - calls per renewal period')
param rateLimitCalls int = 100

@description('Rate limit - renewal period in seconds')
param rateLimitRenewalPeriod int = 60

resource apimService 'Microsoft.ApiManagement/service@2023-05-01-preview' existing = {
  name: apimServiceName
}

resource api 'Microsoft.ApiManagement/service/apis@2023-05-01-preview' = {
  parent: apimService
  name: apiName
  properties: {
    displayName: apiDisplayName
    description: apiDescription
    path: apiPath
    protocols: [
      'https'
    ]
    subscriptionRequired: true
    serviceUrl: serviceUrl
    type: 'http'
  }
}

// Global API Policy
resource apiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-05-01-preview' = {
  parent: api
  name: 'policy'
  properties: {
    value: '<policies><inbound><base />${enableRateLimiting ? '<rate-limit calls="${rateLimitCalls}" renewal-period="${rateLimitRenewalPeriod}" /><rate-limit-by-key calls="${rateLimitCalls}" renewal-period="${rateLimitRenewalPeriod}" counter-key="@(context.Request.IpAddress)" />' : ''}${enableJwtValidation ? '<validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized"><openid-config url="${jwtJwksUri}" /><audiences><audience>${jwtAudience}</audience></audiences><issuers><issuer>${jwtIssuer}</issuer></issuers></validate-jwt>' : ''}<cors allow-credentials="true"><allowed-origins><origin>*</origin></allowed-origins><allowed-methods><method>GET</method><method>POST</method><method>PUT</method><method>DELETE</method><method>OPTIONS</method></allowed-methods><allowed-headers><header>*</header></allowed-headers></cors></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
    format: 'rawxml'
  }
}

// GET /games operation
resource getGamesOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'get-games'
  properties: {
    displayName: 'Get all games'
    method: 'GET'
    urlTemplate: '/games'
    description: 'Retrieve all games from the catalog'
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

// GET /games/{id} operation
resource getGameByIdOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'get-game-by-id'
  properties: {
    displayName: 'Get game by ID'
    method: 'GET'
    urlTemplate: '/games/{id}'
    description: 'Retrieve a specific game by ID'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
      }
    ]
    responses: [
      {
        statusCode: 200
        description: 'Success'
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

// POST /games operation
resource createGameOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'create-game'
  properties: {
    displayName: 'Create a new game'
    method: 'POST'
    urlTemplate: '/games'
    description: 'Add a new game to the catalog'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 201
        description: 'Created'
      }
    ]
  }
}

// PUT /games/{id} operation
resource updateGameOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'update-game'
  properties: {
    displayName: 'Update a game'
    method: 'PUT'
    urlTemplate: '/games/{id}'
    description: 'Update an existing game'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
      }
    ]
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 204
        description: 'No Content'
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

// DELETE /games/{id} operation
resource deleteGameOperation 'Microsoft.ApiManagement/service/apis/operations@2023-05-01-preview' = {
  parent: api
  name: 'delete-game'
  properties: {
    displayName: 'Delete a game'
    method: 'DELETE'
    urlTemplate: '/games/{id}'
    description: 'Remove a game from the catalog'
    templateParameters: [
      {
        name: 'id'
        type: 'integer'
        required: true
      }
    ]
    responses: [
      {
        statusCode: 204
        description: 'No Content'
      }
      {
        statusCode: 404
        description: 'Not Found'
      }
    ]
  }
}

@description('The resource ID of the API')
output apiId string = api.id

@description('The name of the API')
output apiName string = api.name

@description('The API path')
output apiPath string = api.properties.path
