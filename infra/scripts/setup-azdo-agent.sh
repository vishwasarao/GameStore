#!/bin/bash
set -e

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y \
    curl \
    wget \
    git \
    jq \
    libicu-dev \
    apt-transport-https \
    ca-certificates \
    software-properties-common

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker azureuser

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install .NET SDK (for building .NET projects)
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb
apt-get update
apt-get install -y dotnet-sdk-9.0

# Create directory for Azure DevOps agent
mkdir -p /opt/azdo-agent
cd /opt/azdo-agent

# Download and extract Azure DevOps agent
AGENT_VERSION=$(curl -s https://api.github.com/repos/microsoft/azure-pipelines-agent/releases/latest | jq -r .tag_name | sed 's/v//')
wget https://vstsagentpackage.azureedge.net/agent/${AGENT_VERSION}/vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz
tar zxvf vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz
rm vsts-agent-linux-x64-${AGENT_VERSION}.tar.gz

# Set ownership
chown -R azureuser:azureuser /opt/azdo-agent

# Create service configuration script for manual setup
cat > /opt/azdo-agent/configure-agent.sh << 'EOF'
#!/bin/bash
# Azure DevOps Agent Configuration Script
# 
# Usage: sudo -u azureuser ./configure-agent.sh
#
# You will need:
# - Azure DevOps Organization URL (e.g., https://dev.azure.com/yourorg)
# - Personal Access Token (PAT) with Agent Pools (read, manage) scope
# - Agent Pool Name (default: Default)

cd /opt/azdo-agent

echo "Configuring Azure DevOps Agent..."
echo "Please provide the following information:"

./config.sh

echo ""
echo "Installing and starting the agent service..."
sudo ./svc.sh install
sudo ./svc.sh start

echo ""
echo "Azure DevOps Agent configured and started successfully!"
echo "Check status: sudo ./svc.sh status"
EOF

chmod +x /opt/azdo-agent/configure-agent.sh

# Create README
cat > /opt/azdo-agent/README.md << 'EOF'
# Azure DevOps Self-Hosted Agent

This VM is configured with an Azure DevOps agent.

## Complete Setup

1. SSH into the VM:
   ```bash
   ssh azureuser@<VM-IP>
   ```

2. Run the configuration script:
   ```bash
   cd /opt/azdo-agent
   sudo -u azureuser ./configure-agent.sh
   ```

3. Provide when prompted:
   - Azure DevOps URL: https://dev.azure.com/YOUR_ORG
   - PAT (Personal Access Token): Create at https://dev.azure.com/YOUR_ORG/_usersSettings/tokens
     - Scopes needed: Agent Pools (Read & Manage)
   - Agent Pool: Default (or your pool name)
   - Agent Name: (default is hostname)
   - Work folder: (press enter for default)

## Agent Management

```bash
# Check status
sudo /opt/azdo-agent/svc.sh status

# Stop agent
sudo /opt/azdo-agent/svc.sh stop

# Start agent
sudo /opt/azdo-agent/svc.sh start

# View logs
sudo journalctl -u vsts.agent.*
```

## Pre-installed Software

- Docker & Docker Compose
- .NET SDK 9.0
- Git
- curl, wget, jq

## Remove Agent

```bash
cd /opt/azdo-agent
sudo ./svc.sh stop
sudo ./svc.sh uninstall
./config.sh remove
```
EOF

echo "Azure DevOps agent VM setup complete!"
echo "Next: SSH to VM and run: sudo -u azureuser /opt/azdo-agent/configure-agent.sh"
