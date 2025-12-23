# Centralized Infrastructure Repository

Environment-first infrastructure management for all projects.

## Repository Structure

```
infra/
├── modules/                 # Shared Bicep modules (Infra team owns)
│   ├── appServicePlan.bicep
│   ├── webApp.bicep
│   └── appInsights.bicep
├── environments/            # Per-environment folders
│   ├── dev/                # Development environment
│   │   ├── gamestore-api/
│   │   │   ├── main.bicep
│   │   │   └── README.md
│   │   └── inventory-service/
│   ├── staging/            # Staging environment
│   │   └── gamestore-api/
│   └── prod/               # Production environment
│       └── gamestore-api/
├── policies/               # Azure Policies
└── README.md
```

## Environment-First Benefits

✅ **Strong isolation** - Dev, staging, prod completely separated  
✅ **Environment-specific policies** - Different rules per environment  
✅ **Access control** - Dev team owns `dev/`, Infra team owns `prod/`  
✅ **Parallel development** - Multiple teams work on different environments  
✅ **Clear promotion path** - dev → staging → prod

## Ownership Model

### Dev Environment (`/environments/dev/`)
- **Owner:** Development teams
- **Access:** Read/Write for devs
- **Approval:** Self-service (with automated validation)
- **Auto-deploy:** On PR merge

### Staging Environment (`/environments/staging/`)
- **Owner:** QA + Infra teams
- **Access:** Read-only for devs, Write for QA/Infra
- **Approval:** QA team required
- **Deploy:** Manual trigger after QA sign-off

### Production Environment (`/environments/prod/`)
- **Owner:** Infrastructure team
- **Access:** Read-only for all, Write for Infra team only
- **Approval:** Infra team + Engineering lead
- **Deploy:** Manual, change window only

## Workflow: Dev Team Deploys to Dev

1. **Make changes** in `environments/dev/gamestore-api/`
2. **Create PR** with changes
3. **CI validates** Bicep + runs what-if
4. **Auto-deploys** to dev on merge

## Workflow: Promote to Staging

1. **Copy changes** from `dev/` to `staging/` folder
2. **Update environment-specific** config (SKU, settings)
3. **Create PR** tagged with `@qa-team @infra-team`
4. **QA approves** after testing in dev
5. **Infra team deploys** to staging

## Workflow: Promote to Production

1. **Copy changes** from `staging/` to `prod/` folder
2. **Create PR** with production checklist
3. **Requires approval** from Infra + Engineering lead
4. **Schedule deployment** during change window
5. **Infra team deploys** with rollback plan

## Adding New Project

```bash
# Infra team creates structure for new project
mkdir -p infra/environments/{dev,staging,prod}/new-project
cp -r infra/environments/dev/gamestore-api/* infra/environments/dev/new-project/
```

## CODEOWNERS Structure

```
/modules/ @infra-team
/environments/dev/ @dev-teams @infra-team
/environments/staging/ @qa-team @infra-team
/environments/prod/ @infra-team
```

## Common Patterns

### Multiple Projects Per Environment

```
environments/dev/
├── gamestore-api/
├── inventory-service/
├── user-management/
└── payment-gateway/
```

### Deploy All Projects in Environment

```bash
# Deploy all dev projects
for project in infra/environments/dev/*/; do
  az deployment group create \
    --resource-group "rg-$(basename $project)-dev" \
    --template-file "$project/main.bicep"
done
```

## Support

- **Slack:** #infrastructure
- **Dev environment issues:** Self-service
- **Staging/Prod issues:** Create ticket
- **Production incidents:** Page on-call
