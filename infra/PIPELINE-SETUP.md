# Azure DevOps Pipeline Variables Setup Guide

## Required Pipeline Variables

Configure these in Azure DevOps: **Pipelines → Your Pipeline → Edit → Variables**

### Secret Variables (Mark as Secret!)

1. **sqlAdminPassword**
   - Value: Your dev SQL admin password
   - ✅ Keep this value secret

2. **sqlAdminPasswordStaging**
   - Value: Your staging SQL admin password
   - ✅ Keep this value secret

3. **sqlAdminPasswordProd**
   - Value: Your production SQL admin password
   - ✅ Keep this value secret

### Regular Variables

4. **azureServiceConnection**
   - Value: Name of your Azure service connection
   - Default: `Azure-ServiceConnection`

5. **location**
   - Value: Azure region
   - Default: `eastus`

6. **sqlAdminUsername**
   - Value: SQL admin username
   - Default: `sqladmin`

## How to Set Variables in Azure DevOps

### Option 1: UI (Recommended for secrets)

1. Go to your pipeline
2. Click **Edit**
3. Click **Variables** (top right)
4. Click **New variable**
5. Name: `sqlAdminPassword`
6. Value: Your secure password
7. ✅ Check **Keep this value secret**
8. Click **OK**
9. Repeat for other environments

### Option 2: Variable Groups (For sharing across pipelines)

1. Go to **Pipelines → Library**
2. Click **+ Variable group**
3. Name: `GameStore-Secrets`
4. Add variables:
   - `sqlAdminPassword`
   - `sqlAdminPasswordStaging`
   - `sqlAdminPasswordProd`
5. Mark as secret
6. Link to Key Vault (optional for extra security)

Then reference in pipeline:
```yaml
variables:
  - group: GameStore-Secrets
```

### Option 3: Azure Key Vault Integration (Most secure)

1. Create Key Vault in Azure (if not exists)
2. Store secrets in Key Vault
3. In Azure DevOps → Library → Variable Groups
4. Click **+ Variable group**
5. Toggle **Link secrets from an Azure key vault**
6. Select your Key Vault
7. Authorize connection
8. Select secrets to import

## Service Connection Setup

1. Go to **Project Settings → Service connections**
2. Click **New service connection**
3. Select **Azure Resource Manager**
4. Choose **Service principal (automatic)**
5. Select subscription and resource group
6. Name: `Azure-ServiceConnection`
7. Save

## Environments Setup (For approvals)

1. Go to **Pipelines → Environments**
2. Create environments:
   - `dev` (no approval needed)
   - `staging` (optional approval)
   - `production` (✅ require approval)
3. For production:
   - Click environment → Options → Approvals and checks
   - Add **Approvals**
   - Select approvers (infra team)

## Pipeline Execution

1. Commit changes to `main` branch
2. Pipeline triggers automatically
3. Dev deploys automatically
4. Staging deploys after dev succeeds
5. Production requires manual approval
6. Approver gets notification
7. After approval, production deploys

## Security Best Practices

✅ **Do:**
- Use secret variables for passwords
- Enable "Keep this value secret"
- Use separate passwords per environment
- Link to Azure Key Vault for production
- Require approvals for production
- Rotate passwords regularly

❌ **Don't:**
- Commit passwords to Git
- Use same password across environments
- Share pipeline variables publicly
- Skip approvals for production

## Testing the Pipeline

```bash
# Local testing (without secrets)
az login
az account set --subscription "your-subscription"

# Dry run (what-if)
az deployment group what-if \
  --resource-group rg-gamestore-api-dev \
  --template-file infra/environments/dev/gamestore-api/main.bicep \
  --parameters location=eastus \
               sqlAdminUsername=sqladmin \
               sqlAdminPassword='TestP@ssw0rd' \
               keyVaultAccessObjectId='your-object-id'
```
