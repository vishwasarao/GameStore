#!/bin/bash
set -e

echo "======================================"
echo "GameStore API - Azure AD Setup & Deployment"
echo "======================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get tenant and subscription info
echo -e "${YELLOW}Getting Azure account information...${NC}"
TENANT_ID=$(az account show --query tenantId -o tsv)
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
USER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv)

echo "Tenant ID: $TENANT_ID"
echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Your Object ID: $USER_OBJECT_ID"
echo ""

# Step 1: Create App Registration for API
echo -e "${YELLOW}Step 1: Creating Azure AD App Registration for GameStore API...${NC}"

# Check if app already exists
EXISTING_APP_ID=$(az ad app list --display-name "GameStore API" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_APP_ID" ]; then
    echo "Creating new app registration..."
    
    # Create app registration (without identifier URI first)
    APP_ID=$(az ad app create \
        --display-name "GameStore API" \
        --sign-in-audience "AzureADMyOrg" \
        --query appId -o tsv)
    
    # Update with proper identifier URI using app ID
    az ad app update --id "$APP_ID" --identifier-uris "api://${APP_ID}" --output none
    
    echo -e "${GREEN}✓ Created app registration: $APP_ID${NC}"
    
    # Expose an API scope
    echo "Configuring API scopes..."
    cat > /tmp/manifest.json <<EOF
{
    "acceptMappedClaims": null,
    "accessTokenAcceptedVersion": 2,
    "api": {
        "requestedAccessTokenVersion": 2,
        "oauth2PermissionScopes": [
            {
                "adminConsentDescription": "Allow the application to access GameStore API on behalf of the signed-in user",
                "adminConsentDisplayName": "Access GameStore API",
                "id": "$(uuidgen)",
                "isEnabled": true,
                "type": "Admin",
                "userConsentDescription": "Allow the application to access GameStore API on your behalf",
                "userConsentDisplayName": "Access GameStore API",
                "value": "api.access"
            }
        ]
    }
}
EOF
    
    az ad app update --id "$APP_ID" --set api=@/tmp/manifest.json 2>/dev/null || echo "Note: API scope configuration may require portal setup"
    rm /tmp/manifest.json
else
    APP_ID="$EXISTING_APP_ID"
    echo -e "${GREEN}✓ Using existing app registration: $APP_ID${NC}"
fi

echo ""

# Step 2: Create Client App Registration (for testing)
echo -e "${YELLOW}Step 2: Creating client app registration for testing...${NC}"

EXISTING_CLIENT_ID=$(az ad app list --display-name "GameStore API Client" --query "[0].appId" -o tsv 2>/dev/null || echo "")

if [ -z "$EXISTING_CLIENT_ID" ]; then
    echo "Creating client app..."
    
    CLIENT_APP_ID=$(az ad app create \
        --display-name "GameStore API Client" \
        --sign-in-audience "AzureADMyOrg" \
        --query appId -o tsv)
    
    echo -e "${GREEN}✓ Created client app: $CLIENT_APP_ID${NC}"
    
    # Create client secret
    echo "Generating client secret..."
    CLIENT_SECRET=$(az ad app credential reset \
        --id "$CLIENT_APP_ID" \
        --append \
        --query password -o tsv)
    
    echo -e "${GREEN}✓ Client secret created${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  SAVE THESE CREDENTIALS - They won't be shown again!${NC}"
    echo "Client ID: $CLIENT_APP_ID"
    echo "Client Secret: $CLIENT_SECRET"
    echo ""
else
    CLIENT_APP_ID="$EXISTING_CLIENT_ID"
    echo -e "${GREEN}✓ Using existing client app: $CLIENT_APP_ID${NC}"
    echo -e "${YELLOW}⚠️  Note: You'll need to create a new client secret if the old one expired${NC}"
    
    # Create new client secret
    read -p "Create new client secret? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CLIENT_SECRET=$(az ad app credential reset \
            --id "$CLIENT_APP_ID" \
            --append \
            --query password -o tsv)
        echo -e "${GREEN}✓ New client secret created: $CLIENT_SECRET${NC}"
    fi
fi

echo ""

# Step 3: Set JWT parameters
echo -e "${YELLOW}Step 3: Configuring OAuth parameters...${NC}"

JWT_ISSUER="https://login.microsoftonline.com/${TENANT_ID}/v2.0"
JWT_AUDIENCE="api://${APP_ID}"
JWKS_URI="https://login.microsoftonline.com/${TENANT_ID}/discovery/v2.0/keys"

echo "JWT Issuer: $JWT_ISSUER"
echo "JWT Audience: $JWT_AUDIENCE"
echo "JWKS URI: $JWKS_URI"
echo ""

# Step 4: Create resource group
echo -e "${YELLOW}Step 4: Creating resource group...${NC}"

RG_NAME="rg-gamestore-dev"
LOCATION="westeurope"

az group create --name "$RG_NAME" --location "$LOCATION" --output none 2>/dev/null || echo "Resource group already exists"
echo -e "${GREEN}✓ Resource group ready: $RG_NAME (${LOCATION})${NC}"
echo ""

# Step 5: Deploy infrastructure
echo -e "${YELLOW}Step 5: Deploying infrastructure to dev...${NC}"
echo -e "${YELLOW}⚠️  This will take ~45 minutes (APIM provisioning is slow)${NC}"
echo ""

echo "Enter SQL admin password (min 12 chars, 1 uppercase, 1 lowercase, 1 number, 1 special char):"
read -s SQL_PASSWORD
echo ""

echo "Enter your email for APIM notifications:"
read APIM_EMAIL

echo ""
echo "Starting deployment..."
cd /Users/vishwasrao/repos/GameStore/infra/environments/dev/gamestore-api

az deployment group create \
    --resource-group "$RG_NAME" \
    --template-file main.bicep \
    --parameters \
        sqlAdminPassword="$SQL_PASSWORD" \
        keyVaultAccessObjectId="$USER_OBJECT_ID" \
        jwtIssuer="$JWT_ISSUER" \
        jwtAudience="$JWT_AUDIENCE" \
        jwksUri="$JWKS_URI" \
        apimPublisherEmail="$APIM_EMAIL" \
        apimPublisherName="GameStore" \
    --output json > /tmp/deployment-output.json

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Deployment succeeded!${NC}"
    echo ""
    
    # Extract outputs
    APIM_GATEWAY_URL=$(jq -r '.properties.outputs.apimGatewayUrl.value' /tmp/deployment-output.json)
    APIM_PORTAL_URL=$(jq -r '.properties.outputs.apimPortalUrl.value' /tmp/deployment-output.json)
    CONTAINER_APP_URL=$(jq -r '.properties.outputs.containerAppUrl.value' /tmp/deployment-output.json)
    
    echo "======================================"
    echo "Deployment Complete!"
    echo "======================================"
    echo ""
    echo "API Gateway URL: $APIM_GATEWAY_URL"
    echo "Developer Portal: $APIM_PORTAL_URL"
    echo "Backend API URL: $CONTAINER_APP_URL"
    echo ""
    echo "OAuth Configuration:"
    echo "  API App ID: $APP_ID"
    echo "  Client App ID: $CLIENT_APP_ID"
    echo "  Tenant ID: $TENANT_ID"
    echo ""
    echo "Next Steps:"
    echo "1. Test OAuth flow - get token with client credentials"
    echo "2. Call API via APIM gateway with JWT token"
    echo "3. Configure developer portal (optional)"
    echo ""
    
    # Create test script
    cat > /tmp/test-api.sh <<EOF
#!/bin/bash
# Get OAuth token
TOKEN_RESPONSE=\$(curl -s -X POST \\
  "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \\
  -H "Content-Type: application/x-www-form-urlencoded" \\
  -d "client_id=${CLIENT_APP_ID}" \\
  -d "client_secret=${CLIENT_SECRET}" \\
  -d "scope=${JWT_AUDIENCE}/.default" \\
  -d "grant_type=client_credentials")

ACCESS_TOKEN=\$(echo \$TOKEN_RESPONSE | jq -r '.access_token')

if [ "\$ACCESS_TOKEN" = "null" ]; then
    echo "Failed to get token:"
    echo \$TOKEN_RESPONSE
    exit 1
fi

echo "Got access token!"
echo ""

# Get subscription key (you'll need to add this manually)
echo "Get your subscription key from Azure Portal:"
echo "APIM → Subscriptions → Built-in all-access subscription"
echo ""
read -p "Enter subscription key: " SUB_KEY

# Call API
echo ""
echo "Calling API..."
curl -X GET "${APIM_GATEWAY_URL}/api/games" \\
  -H "Authorization: Bearer \$ACCESS_TOKEN" \\
  -H "Ocp-Apim-Subscription-Key: \$SUB_KEY" \\
  -H "Accept: application/json"
EOF
    
    chmod +x /tmp/test-api.sh
    echo "Test script created: /tmp/test-api.sh"
    
else
    echo -e "${YELLOW}Deployment failed. Check the error above.${NC}"
    exit 1
fi

# Save credentials to file
cat > ~/gamestore-credentials.txt <<EOF
GameStore Dev Environment - OAuth Credentials
Generated: $(date)

Resource Group: $RG_NAME
Location: $LOCATION

API App Registration:
  App ID: $APP_ID
  Audience: $JWT_AUDIENCE

Client App Registration:
  Client ID: $CLIENT_APP_ID
  Client Secret: $CLIENT_SECRET

OAuth Endpoints:
  Token URL: https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token
  JWKS URI: $JWKS_URI

API URLs:
  APIM Gateway: $APIM_GATEWAY_URL
  Developer Portal: $APIM_PORTAL_URL
  Backend API: $CONTAINER_APP_URL

Test Command:
curl -X POST "https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token" \\
  -d "client_id=${CLIENT_APP_ID}" \\
  -d "client_secret=${CLIENT_SECRET}" \\
  -d "scope=${JWT_AUDIENCE}/.default" \\
  -d "grant_type=client_credentials"
EOF

echo ""
echo -e "${GREEN}✓ Credentials saved to: ~/gamestore-credentials.txt${NC}"
echo ""
