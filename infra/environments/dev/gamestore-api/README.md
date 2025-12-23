# GameStore API - Dev Environment

## Deploy

```bash
az group create --name rg-gamestore-api-dev --location eastus

az deployment group create \
  --resource-group rg-gamestore-api-dev \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Environment Details

- **SKU:** F1 (Free)
- **Purpose:** Development and testing
- **ASPNETCORE_ENVIRONMENT:** Development
- **Feature Flags:** Enabled

## Access

After deployment, get the URL:
```bash
az deployment group show \
  --resource-group rg-gamestore-api-dev \
  --name <deployment-name> \
  --query properties.outputs.webAppUrl.value
```
