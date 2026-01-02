# Quick Deployment Guide - Redis Infrastructure

## Prerequisites

```bash
# Install Azure CLI (if not already installed)
brew install azure-cli

# Login to Azure
az login

# Set subscription
az account set --subscription "Your-Subscription-ID"
```

---

## Step 1: Create Resource Group

```bash
# Dev environment
az group create \
  --name rg-gamestore-dev \
  --location uksouth

# Staging environment
az group create \
  --name rg-gamestore-staging \
  --location eastus

# Production environment
az group create \
  --name rg-gamestore-prod \
  --location eastus
```

---

## Step 2: Deploy Infrastructure

### Development Environment

```bash
cd infra/environments/dev/gamestore-api

# Get your Azure AD Object ID (for Key Vault access)
OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

# Deploy
az deployment group create \
  --resource-group rg-gamestore-dev \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourSecurePassword123!' \
               keyVaultAccessObjectId=$OBJECT_ID
```

### Staging Environment

```bash
cd ../../../staging/gamestore-api

az deployment group create \
  --resource-group rg-gamestore-staging \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourSecurePassword123!' \
               keyVaultAccessObjectId=$OBJECT_ID
```

### Production Environment

```bash
cd ../../../prod/gamestore-api

az deployment group create \
  --resource-group rg-gamestore-prod \
  --template-file main.bicep \
  --parameters sqlAdminPassword='YourSecurePassword123!' \
               keyVaultAccessObjectId=$OBJECT_ID
```

---

## Step 3: Verify Deployment

```bash
# Check Redis Cache was created
az redis list --resource-group rg-gamestore-dev --output table

# Get Redis connection details
az redis show \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis \
  --query "{hostName:hostName,sslPort:sslPort}" \
  --output table

# Get Redis access keys
az redis list-keys \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis
```

---

## Step 4: Retrieve Connection Strings

```bash
# Get Redis connection string from Key Vault
az keyvault secret show \
  --vault-name kvgamestoredevxxxxxxxx \
  --name redis-connection-string \
  --query value \
  --output tsv

# Get SQL connection string (for reference)
az keyvault secret show \
  --vault-name kvgamestoredevxxxxxxxx \
  --name sql-admin-password \
  --query value \
  --output tsv
```

---

## Step 5: View All Outputs

```bash
# View all deployment outputs
az deployment group show \
  --resource-group rg-gamestore-dev \
  --name containerApp-deployment \
  --query properties.outputs \
  --output table

# Get Container App URL
az deployment group show \
  --resource-group rg-gamestore-dev \
  --name containerApp-deployment \
  --query properties.outputs.containerAppUrl.value \
  --output tsv
```

---

## Step 6: Test the Deployment

```bash
# Get the Container App URL
APP_URL=$(az deployment group show \
  --resource-group rg-gamestore-dev \
  --name containerApp-deployment \
  --query properties.outputs.containerAppUrl.value \
  --output tsv)

# Test the API
curl -X GET "${APP_URL}/games" \
  -H "Accept: application/json"

# Test with timing to see cache performance
time curl -X GET "${APP_URL}/games" -H "Accept: application/json"  # First request (cache miss)
time curl -X GET "${APP_URL}/games" -H "Accept: application/json"  # Second request (cache hit)
```

---

## Monitor Redis Performance

### Via Azure Portal

1. Navigate to: **Azure Portal → Redis Cache → Metrics**
2. Monitor:
   - Cache Hits vs Misses
   - Connected Clients
   - Memory Usage
   - Operations per Second

### Via Azure CLI

```bash
# Get cache statistics
az redis show \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis \
  --query "{provisioningState:provisioningState,redisVersion:redisVersion,sku:sku}" \
  --output table

# View metrics
az monitor metrics list \
  --resource-group rg-gamestore-dev \
  --resource gamestore-dev-xxxxx-redis \
  --resource-type Microsoft.Cache/redis \
  --metric "cacheHits,cacheMisses" \
  --interval PT1M
```

---

## Cleanup (Optional)

```bash
# Delete dev environment
az group delete --name rg-gamestore-dev --yes --no-wait

# Delete staging environment
az group delete --name rg-gamestore-staging --yes --no-wait

# Delete production environment
az group delete --name rg-gamestore-prod --yes --no-wait
```

---

## Troubleshooting

### Issue: Deployment Failed

```bash
# Check deployment errors
az deployment group show \
  --resource-group rg-gamestore-dev \
  --name containerApp-deployment \
  --query properties.error

# View deployment operations
az deployment operation group list \
  --resource-group rg-gamestore-dev \
  --name containerApp-deployment
```

### Issue: Can't Connect to Redis

```bash
# Check Redis status
az redis show \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis \
  --query provisioningState

# Test Redis connectivity
az redis force-reboot \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis \
  --reboot-type AllNodes
```

### Issue: Container App Not Starting

```bash
# View container app logs
az containerapp logs show \
  --name gamestore-dev-xxxxx-api \
  --resource-group rg-gamestore-dev \
  --follow

# Check environment variables
az containerapp show \
  --name gamestore-dev-xxxxx-api \
  --resource-group rg-gamestore-dev \
  --query properties.template.containers[0].env
```

---

## Cost Estimation

| Resource              | Dev (Monthly) | Staging (Monthly) | Prod (Monthly) |
|-----------------------|---------------|-------------------|----------------|
| Redis Cache           | ~$17          | ~$55              | ~$110          |
| SQL Database          | ~$5           | ~$15              | ~$30           |
| Container App         | ~$0-10        | ~$20              | ~$50+          |
| Key Vault             | ~$0-5         | ~$0-5             | ~$0-5          |
| Application Insights  | ~$0-5         | ~$5-10            | ~$20-50        |
| **Total**             | **~$27-42**   | **~$95-105**      | **~$210-245**  |

*Prices are approximate and subject to change based on usage*

---

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Verify Redis is running
3. 🔄 Set up CI/CD pipeline (see [azure-pipelines.yml](../../../azure-pipelines.yml))
4. 🔄 Configure monitoring alerts
5. 🔄 Set up backup policies
6. 🔄 Implement disaster recovery plan

---

## Useful Commands Cheat Sheet

```bash
# List all Redis caches in subscription
az redis list --output table

# Scale Redis cache
az redis update \
  --resource-group rg-gamestore-dev \
  --name gamestore-dev-xxxxx-redis \
  --sku Standard \
  --vm-size C1

# Export ARM template
az group export \
  --resource-group rg-gamestore-dev \
  --output json > exported-template.json

# Test connection from local machine
redis-cli -h gamestore-dev-xxxxx.redis.cache.windows.net \
  -p 6380 \
  -a "your-access-key" \
  --tls
```
