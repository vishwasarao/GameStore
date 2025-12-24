# Azure DevOps Agent - Capacity Issues

## Problem
Your Azure subscription has capacity restrictions preventing VM deployment in multiple regions and SKUs:
- ❌ Standard_B1ms (East US, UK South)
- ❌ Standard_B2s (UK South)  
- ❌ Standard_D2s_v3 (East US)

This is common with free/student/trial subscriptions.

## Alternative Solutions

### Option 1: Use Azure Container Instances (Recommended ✅)
**Pros:**
- No capacity restrictions
- Pay per second (cheaper for occasional use)
- Faster startup
- ~$10-15/month vs $30-50/month for VMs

**Cons:**
- No persistent storage between restarts
- Must reconfigure agent each time

### Option 2: Use Existing Container App
Your GameStore Container App can run builds:
- Already deployed
- Has Docker
- No additional cost

### Option 3: Use GitHub-hosted Agents
- Free for public repos
- 2000 minutes/month for private repos
- No infrastructure management

### Option 4: Request Quota Increase
Submit support ticket: https://aka.ms/azureskunotavailable

### Option 5: Different Region
Try regions with more capacity:
- West US 2
- Central US
- North Europe

## Recommendation

**For GameStore project:** Use GitHub-hosted agents (free, no hassle)
**For learning:** Try Azure Container Instances
**For production:** Request quota increase or use different subscription

Would you like me to:
1. Set up Azure Container Instance agent
2. Configure GitHub Actions instead
3. Try a different region
