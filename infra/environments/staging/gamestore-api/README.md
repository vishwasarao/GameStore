# GameStore API - Staging Environment

## Deploy

```bash
az group create --name rg-gamestore-api-staging --location eastus

az deployment group create \
  --resource-group rg-gamestore-api-staging \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Environment Details

- **SKU:** B1 (Basic)
- **Purpose:** Pre-production testing
- **ASPNETCORE_ENVIRONMENT:** Staging
- **Approval Required:** Yes (QA team)
