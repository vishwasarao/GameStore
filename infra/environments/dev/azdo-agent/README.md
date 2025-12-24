# Azure DevOps Self-Hosted Agent VM

Infrastructure for Azure DevOps self-hosted build agent.

## What's Included

- Ubuntu 22.04 LTS VM (Standard_B2s: 2 vCPU, 4GB RAM)
- Pre-installed: Docker, Docker Compose, .NET SDK 9.0, Git
- Azure DevOps agent binaries ready to configure
- Public IP with SSH access

## Deploy

```bash
# Create resource group
az group create --name rg-gamestore-azdo-agent-dev --location uksouth

# Deploy
az deployment group create \
  --resource-group rg-gamestore-azdo-agent-dev \
  --template-file main.bicep \
  --parameters adminUsername=azureuser adminPassword='YourSecureP@ssw0rd123!'
```

## Configure Agent

1. **Get VM connection info:**
```bash
az deployment group show \
  --resource-group rg-gamestore-azdo-agent-dev \
  --name azdo-agent-deployment \
  --query properties.outputs
```

2. **SSH to VM:**
```bash
ssh azureuser@<PUBLIC-IP>
```

3. **Configure Azure DevOps agent:**
```bash
cd /opt/azdo-agent
sudo -u azureuser ./configure-agent.sh
```

You'll need:
- **Azure DevOps URL:** `https://dev.azure.com/YOUR_ORG`
- **PAT Token:** Create at https://dev.azure.com/YOUR_ORG/_usersSettings/tokens
  - Scopes: Agent Pools (Read & Manage)
- **Agent Pool:** Default (or create custom pool)

## Manage Agent

```bash
# Check status
sudo /opt/azdo-agent/svc.sh status

# Stop/Start
sudo /opt/azdo-agent/svc.sh stop
sudo /opt/azdo-agent/svc.sh start

# View logs
sudo journalctl -u vsts.agent.* -f
```

## Cost Estimation

**Standard_B2s VM:**
- UK South: ~$30-40/month (running 24/7)
- Recommended: Stop when not in use

**Stop/Start VM:**
```bash
# Stop (only pay for storage)
az vm stop --resource-group rg-gamestore-azdo-agent-dev --name <VM-NAME>
az vm deallocate --resource-group rg-gamestore-azdo-agent-dev --name <VM-NAME>

# Start
az vm start --resource-group rg-gamestore-azdo-agent-dev --name <VM-NAME>
```

## Security

- Change default password after deployment
- Consider using SSH keys instead of password
- Configure NSG to restrict SSH access to your IP
- Keep agent and OS updated

## Cleanup

```bash
az group delete --name rg-gamestore-azdo-agent-dev --yes
```
