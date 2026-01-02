# Azure API Management (APIM) Implementation

## Overview

Azure API Management sits as a gateway in front of your GameStore API, providing enterprise-grade features:

- ✅ **OAuth 2.0 / JWT Validation** (Client Credentials flow)
- ✅ **Rate Limiting** (per-subscription key)
- ✅ **Geo-blocking** (allow/block countries)
- ✅ **Caching** (built-in response cache)
- ✅ **Monitoring** (Application Insights integration)
- ✅ **Developer Portal** (API documentation & testing)

---

## Architecture

```
┌──────────┐
│  Client  │
│ (OAuth)  │
└────┬─────┘
     │ JWT Token
     ▼
┌─────────────────────────────────┐
│   Azure API Management          │
│                                 │
│  1. Validate JWT ✓              │
│  2. Check Rate Limit ✓          │
│  3. Check Geo-location ✓        │
│  4. Check Response Cache ✓      │
│                                 │
└────┬────────────────────────────┘
     │ (if allowed)
     ▼
┌─────────────────────────────────┐
│   Container App / Web App       │
│   (GameStore API)               │
│                                 │
│   - Redis Caching               │
│   - SQL Database                │
└─────────────────────────────────┘
```

**Flow:**
1. Client obtains JWT token via OAuth 2.0 Client Credentials
2. Client calls APIM with `Authorization: Bearer {token}`
3. APIM validates JWT, rate limit, geo-location
4. APIM forwards to backend API
5. Backend processes + returns response
6. APIM returns to client

---

## Infrastructure Deployed

### APIM Service Tiers

| Environment | SKU | Capacity | Cost/Month | SLA | Features |
|-------------|-----|----------|------------|-----|----------|
| **Dev** | Developer | 1 | ~$50 | None | Full features, no SLA |
| **Staging** | Basic | 1 | ~$150 | 99.95% | 2 units max, 100M API calls |
| **Production** | Standard | 1 | ~$680 | 99.95% | 4 units max, multi-region |

**Note:** Developer tier is for non-production only (no SLA).

### Files Created

1. **[infra/modules/apiManagement.bicep](infra/modules/apiManagement.bicep)**
   - APIM service resource
   - Application Insights integration
   - System-assigned managed identity

2. **[infra/modules/apiManagementApi.bicep](infra/modules/apiManagementApi.bicep)**
   - API definition (GameStore API)
   - Operations (GET, POST, PUT, DELETE)
   - Policies (JWT, rate limit, geo-blocking)

3. **Environment Configurations Updated:**
   - [infra/environments/dev/gamestore-api/main.bicep](infra/environments/dev/gamestore-api/main.bicep)
   - [infra/environments/staging/gamestore-api/main.bicep](infra/environments/staging/gamestore-api/main.bicep)
   - [infra/environments/prod/gamestore-api/main.bicep](infra/environments/prod/gamestore-api/main.bicep)

---

## Configuration

### Required Parameters

```bash
# JWT Configuration (Azure AD / Entra ID)
jwtIssuer="https://login.microsoftonline.com/{tenant-id}/v2.0"
jwtAudience="api://gamestore-api"
jwksUri="https://login.microsoftonline.com/{tenant-id}/discovery/v2.0/keys"

# APIM Publisher Info
apimPublisherEmail="admin@yourdomain.com"
apimPublisherName="Your Company Name"
```

### Optional: Geo-blocking (Production)

```bash
# Allow only specific countries (ISO 3166-1 alpha-2)
allowedCountries='["US","GB","CA","AU"]'

# Or block specific countries
blockedCountries='["CN","RU","KP"]'
```

**Common Country Codes:**
- `US` - United States
- `GB` - United Kingdom
- `CA` - Canada
- `AU` - Australia
- `DE` - Germany
- `FR` - France
- `CN` - China
- `RU` - Russia
- `IN` - India

---

## Deployment

### Step 1: Set Up Azure AD App Registration

```bash
# Create App Registration for API
az ad app create \
  --display-name "GameStore API" \
  --identifier-uris "api://gamestore-api" \
  --app-roles @app-roles.json

# Get App ID (Client ID)
APP_ID=$(az ad app list --display-name "GameStore API" --query "[0].appId" -o tsv)

# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)

# Set variables
JWT_ISSUER="https://login.microsoftonline.com/${TENANT_ID}/v2.0"
JWT_AUDIENCE="api://${APP_ID}"
JWKS_URI="https://login.microsoftonline.com/${TENANT_ID}/discovery/v2.0/keys"
```

### Step 2: Deploy Infrastructure

#### Development
```bash
cd infra/environments/dev/gamestore-api

az deployment group create \
  --resource-group rg-gamestore-dev \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourPassword123!' \
               keyVaultAccessObjectId=$(az ad signed-in-user show --query id -o tsv) \
               jwtIssuer="$JWT_ISSUER" \
               jwtAudience="$JWT_AUDIENCE" \
               jwksUri="$JWKS_URI" \
               apimPublisherEmail="admin@yourdomain.com" \
               apimPublisherName="GameStore"
```

#### Staging
```bash
cd ../../../staging/gamestore-api

az deployment group create \
  --resource-group rg-gamestore-staging \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourPassword123!' \
               keyVaultAccessObjectId=$(az ad signed-in-user show --query id -o tsv) \
               jwtIssuer="$JWT_ISSUER" \
               jwtAudience="$JWT_AUDIENCE" \
               jwksUri="$JWKS_URI" \
               apimPublisherEmail="admin@yourdomain.com" \
               apimPublisherName="GameStore"
```

#### Production (with geo-blocking)
```bash
cd ../../../prod/gamestore-api

az deployment group create \
  --resource-group rg-gamestore-prod \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourPassword123!' \
               keyVaultAccessObjectId=$(az ad signed-in-user show --query id -o tsv) \
               jwtIssuer="$JWT_ISSUER" \
               jwtAudience="$JWT_AUDIENCE" \
               jwksUri="$JWKS_URI" \
               apimPublisherEmail="admin@yourdomain.com" \
               apimPublisherName="GameStore" \
               allowedCountries='["US","GB","CA"]'
```

### Step 3: Get APIM Gateway URL

```bash
# Get APIM Gateway URL
APIM_URL=$(az deployment group show \
  --resource-group rg-gamestore-dev \
  --name apiManagement-deployment \
  --query properties.outputs.gatewayUrl.value \
  --output tsv)

echo "APIM Gateway URL: $APIM_URL"
# Output: https://gamestore-dev-xxxxx-apim.azure-api.net
```

---

## Testing with OAuth Client Credentials

### 1. Create Client App for Testing

```bash
# Create client app registration
az ad app create \
  --display-name "GameStore Test Client" \
  --app-roles @app-roles.json

CLIENT_APP_ID=$(az ad app list --display-name "GameStore Test Client" --query "[0].appId" -o tsv)

# Create client secret
CLIENT_SECRET=$(az ad app credential reset \
  --id $CLIENT_APP_ID \
  --query password -o tsv)

# Grant API permissions
az ad app permission add \
  --id $CLIENT_APP_ID \
  --api $APP_ID \
  --api-permissions {permission-id}=Role

# Admin consent
az ad app permission admin-consent --id $CLIENT_APP_ID
```

### 2. Get Access Token

```bash
# Get OAuth token using client credentials
TOKEN_RESPONSE=$(curl -X POST \
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${CLIENT_APP_ID}" \
  -d "client_secret=${CLIENT_SECRET}" \
  -d "scope=${JWT_AUDIENCE}/.default" \
  -d "grant_type=client_credentials")

ACCESS_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.access_token')
```

### 3. Call API via APIM

```bash
# Get all games
curl -X GET "${APIM_URL}/api/games" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Ocp-Apim-Subscription-Key: {subscription-key}"

# Get specific game
curl -X GET "${APIM_URL}/api/games/1" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Ocp-Apim-Subscription-Key: {subscription-key}"

# Create game
curl -X POST "${APIM_URL}/api/games" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Ocp-Apim-Subscription-Key: {subscription-key}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Game",
    "genre": "Action",
    "description": "Testing APIM",
    "releaseDate": "2025-12-29"
  }'
```

---

## APIM Policies Explained

### 1. JWT Validation Policy

```xml
<validate-jwt header-name="Authorization" 
              failed-validation-httpcode="401" 
              failed-validation-error-message="Unauthorized">
  <openid-config url="{jwksUri}" />
  <audiences>
    <audience>{jwtAudience}</audience>
  </audiences>
  <issuers>
    <issuer>{jwtIssuer}</issuer>
  </issuers>
  <required-claims>
    <claim name="scope" match="any">
      <value>api.read</value>
      <value>api.write</value>
    </claim>
  </required-claims>
</validate-jwt>
```

**What it does:**
- Extracts JWT from `Authorization: Bearer {token}` header
- Validates signature using JWKS endpoint
- Checks issuer matches Azure AD
- Checks audience matches your API
- Verifies required scopes/claims
- Returns 401 if invalid

### 2. Rate Limiting Policy

```xml
<rate-limit calls="100" renewal-period="60" />
<rate-limit-by-key calls="100" 
                    renewal-period="60" 
                    counter-key="@(context.Request.IpAddress)" />
```

**What it does:**
- Global limit: 100 calls per 60 seconds per subscription
- Per-IP limit: 100 calls per 60 seconds per IP address
- Returns 429 when limit exceeded
- Adds `X-RateLimit-*` headers

### 3. Geo-blocking Policy

```xml
<choose>
  <when condition="@{
    var country = context.Request.Headers.GetValueOrDefault('X-Forwarded-For-Country', '');
    return new[] { 'CN', 'RU' }.Contains(country);
  }">
    <return-response>
      <set-status code="403" reason="Forbidden" />
      <set-body>{"error": "Access denied from your location"}</set-body>
    </return-response>
  </when>
</choose>
```

**What it does:**
- Checks `X-Forwarded-For-Country` header
- Blocks requests from specified countries
- Returns 403 Forbidden
- Customizable allowed/blocked lists

---

## Subscription Keys

APIM requires subscription keys for API access. Each subscription has a primary and secondary key.

### Get Subscription Keys

```bash
# List subscriptions
az apim subscription list \
  --resource-group rg-gamestore-dev \
  --service-name gamestore-dev-xxxxx-apim

# Get built-in "Built-in all-access subscription"
az apim subscription show \
  --resource-group rg-gamestore-dev \
  --service-name gamestore-dev-xxxxx-apim \
  --sid master
```

### Use in Requests

```http
GET https://gamestore-dev-xxxxx-apim.azure-api.net/api/games
Authorization: Bearer {jwt-token}
Ocp-Apim-Subscription-Key: {subscription-key}
```

---

## Rate Limiting Configuration

| Environment | Calls/Min | Use Case |
|-------------|-----------|----------|
| **Dev** | 1000 | Testing, no restrictions |
| **Staging** | 100 | Realistic production simulation |
| **Production** | 60 | Strict, prevents abuse |

### Customize Rate Limits

Edit [apiManagementApi.bicep](infra/modules/apiManagementApi.bicep):

```bicep
rateLimiting: {
  enabled: true
  calls: 100          // Change this
  renewalPeriod: 60   // Change this (seconds)
}
```

---

## Monitoring

### Application Insights Queries

```kusto
// APIM requests
requests
| where cloud_RoleName == "API Management"
| summarize count() by resultCode, bin(timestamp, 5m)

// JWT validation failures
requests
| where resultCode == 401
| extend reason = tostring(customDimensions["error"])
| summarize count() by reason

// Rate limited requests
requests
| where resultCode == 429
| summarize count() by client_IP, bin(timestamp, 1m)

// Geo-blocked requests
requests
| where resultCode == 403
| extend country = tostring(customDimensions["country"])
| summarize count() by country
```

### APIM Analytics (Azure Portal)

1. Navigate to: **APIM → Analytics**
2. View:
   - Requests over time
   - Response times (P50, P95, P99)
   - Top APIs / Operations
   - Top products / Subscriptions
   - Error rates

---

## Developer Portal

APIM includes a developer portal for API documentation and testing.

### Access Portal

```bash
# Get portal URL
az apim show \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-apim \
  --query portalUrl -o tsv
```

### Publish Portal

```bash
# Publish changes (after customization)
az apim api publish \
  --resource-group rg-gamestore-dev \
  --service-name gamestore-dev-xxxxx-apim
```

**Features:**
- Interactive API documentation
- Try-it-out functionality
- Subscription key management
- OAuth 2.0 authorization flow
- Code samples (cURL, C#, Python, etc.)

---

## Cost Optimization

### Reduce Costs

1. **Use Developer SKU for non-prod** (~$50/month vs $150+)
2. **Use Consumption tier** (pay-per-call, but limited features)
3. **Enable caching** (reduce backend calls)
4. **Monitor unused subscriptions**

### Cost Breakdown

```
Monthly Cost (Standard tier):
- APIM Standard: ~$680/month
- Redis Cache: ~$110/month (Standard C2)
- SQL Database: ~$30/month (S1)
- App Insights: ~$20-50/month
- Container App/Web App: ~$50-100/month
-------------------------------------------
Total: ~$890-970/month
```

**Alternative (Budget-friendly):**
```
- APIM Developer: ~$50/month (non-prod only)
- Redis Basic: ~$17/month
- SQL Basic: ~$5/month
-------------------------------------------
Total: ~$72-100/month (dev/staging)
```

---

## Troubleshooting

### 401 Unauthorized

**Problem:** JWT validation failing

**Solution:**
```bash
# Verify token
echo $ACCESS_TOKEN | jq -R 'split(".") | .[1] | @base64d | fromjson'

# Check issuer, audience, expiry
```

### 429 Too Many Requests

**Problem:** Rate limit exceeded

**Solution:**
- Wait for renewal period (60 seconds)
- Increase limit in Bicep file
- Use different subscription key

### 403 Forbidden (Geo-blocking)

**Problem:** Request from blocked country

**Solution:**
- Check `X-Forwarded-For-Country` header
- Update `allowedCountries` or `blockedCountries` in Bicep
- Redeploy infrastructure

### 500 Internal Server Error

**Problem:** Backend API error

**Solution:**
```bash
# Check backend API logs
az containerapp logs show \
  --name gamestore-dev-xxxxx-api \
  --resource-group rg-gamestore-dev \
  --follow
```

---

## Best Practices

1. ✅ **Use separate APIM instances** per environment (dev/staging/prod)
2. ✅ **Enable Application Insights** for monitoring
3. ✅ **Rotate subscription keys** regularly
4. ✅ **Use managed identities** for backend auth
5. ✅ **Enable response caching** for GET operations
6. ✅ **Set appropriate rate limits** per subscription tier
7. ✅ **Use developer portal** for external developers
8. ✅ **Enable CORS** for web applications
9. ✅ **Version your APIs** (/v1, /v2)
10. ✅ **Monitor costs** with Azure Cost Management

---

## Summary

✅ **Implemented:**
- APIM service (Developer/Basic/Standard tiers)
- JWT validation (OAuth 2.0 Client Credentials)
- Rate limiting (per-subscription + per-IP)
- Geo-blocking (allow/block countries)
- Application Insights integration
- Developer portal

🎯 **Benefits:**
- Enterprise-grade API gateway
- Centralized authentication & authorization
- Protection from abuse (rate limit + geo-block)
- Built-in caching & monitoring
- Developer portal for external consumers

💰 **Cost:**
- Dev: ~$50/month (no SLA)
- Staging: ~$150/month (99.95% SLA)
- Production: ~$680/month (99.95% SLA, multi-region)

🚀 **Next Steps:**
1. Set up Azure AD app registrations
2. Deploy infrastructure with JWT parameters
3. Test with OAuth client credentials
4. Configure geo-blocking (production)
5. Customize developer portal
6. Set up alerts & monitoring
