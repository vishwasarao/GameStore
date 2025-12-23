# GameStore API - Production Environment

## Deploy

⚠️ **PRODUCTION DEPLOYMENT - REQUIRES APPROVAL**

```bash
az group create --name rg-gamestore-api-prod --location eastus

az deployment group create \
  --resource-group rg-gamestore-api-prod \
  --template-file main.bicep \
  --parameters main.parameters.json
```

## Environment Details

- **SKU:** P1v2 (Premium)
- **Purpose:** Production workloads
- **ASPNETCORE_ENVIRONMENT:** Production
- **Approval Required:** Yes (Infra team + Engineering lead)
- **Change Window:** Tuesdays/Thursdays only

## Monitoring

- Application Insights enabled
- Alerts configured for errors/performance
- On-call: #oncall-gamestore
