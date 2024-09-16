// Parameters

param dnsPrefix string = 'ClusterDnsprefix'
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0
@minValue(1)
@maxValue(50)
param agentCount int = 3
param agentVMSize string = 'standard_d2s_v3'
param linuxAdminUsername string = 'Gt-test'
param location string = resourceGroup().location
param clusterName string = 'myAKSCluster'
param appGatewayPublicIpName string = 'myAppGatewayPublicIP'
param vnetName string = 'myVNet'
param vnetAddressPrefix string = '10.0.0.0/16'
param aksSubnetName string = 'aksSubnet'
param aksSubnetPrefix string = '10.0.1.0/24'
param wafSubnetName string = 'wafSubnet'
param wafSubnetPrefix string = '10.0.0.0/26'
param keyVaultName string = 'myKeyVault${uniqueString(resourceGroup().id)}'
param acrName string = 'myACR${uniqueString(resourceGroup().id)}'

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
  }
}

// AKS Subnet
resource aksSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: aksSubnetName
  properties: {
    addressPrefix: aksSubnetPrefix
    privateEndpointNetworkPolicies: 'Disabled'
  }
}

// WAF Subnet
resource wafSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = {
  parent: vnet
  name: wafSubnetName
  properties: {
    addressPrefix: wafSubnetPrefix
  }
}

//public-ip
resource appGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: appGatewayPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// AKS Cluster
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
      }
    ]
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {
            keyData: 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDAmqbEgzAyN++nCUrIKJfbxoeZ8ea4YLebY4CPPPEvOlc5THBPDAE2DzbZnAHRuF2+HTGNYbcsDJEwyUgyg2OPQVXsNxb5fcd/i/4odxu5zDrcT4qtYZ56ABiLfQxr3lJghpUN1CN5I7rWLNGj6sxDt01wS+rbn7TX+X7q3zOq1Y4iP77RtFg0/tLTHgiKdCCaA/WzR98SHSb92LMsWY0TzqmcIqYClxUog+AOVaAoGiiB5Ip409ZMwdYp5b8a4nq/pOSG2uVgr6vnghryiRrMHXazJqJQc3bKzYirdVgiSv2g1c1RBk7zNg4uiuwRB0C18FGTll2U1tuXz5ILRUGd0nG8YqhweXHY7qwdDndqGuGJDZAoipEgmMjm74hDI6TfuJIkQsiu39vCiQKjqEN6O1Nv8Ai+wASvY5wRV6wyddTtjif+sNbGNWaUA/IVRv+bV1GUv7AsY8ymKT+NoCRntSthakTV4htbg3G3C0i1hloVCxk7f/fjibR2T8c5092m21GNUENMnqIQuM6vJmkqy2N64dQTIzuxaFWOGCQkSWFOtaGxAGwQ569PyM5m0u1Ipcffg3CAMlOblAfJosof8GHlTHAioaDwnGjO0erzrfvPNVEOlzNIc0wtVZVS2F3YBSbHYulI2hpjOdfqsiBlxbN5O1IOaKjfwgKP7Dbr/Q== olukorede fawemimo@Anommynous'
          }
        ]
      }
    }
  }
}

// Application Gateway (WAF)
resource myAppGateway 'Microsoft.Network/applicationGateways@2024-01-01' = {
  name: 'WAFGateway'
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: wafSubnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: appGatewayPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'myBackendPool'
        properties: {}
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          firewallPolicy: {
            id: Webappfirewallpolicy.id
          }
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', 'WAFGateway', 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', 'WAFGateway', 'port_80')
          }
          protocol: 'Http'
          requireServerNameIndication: false
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', 'WAFGateway', 'myListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', 'WAFGateway', 'myBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', 'WAFGateway', 'myHTTPSetting')
          }
        }
      }
    ]
    enableHttp2: false
    firewallPolicy: {
      id: Webappfirewallpolicy.id
    }
  }
  dependsOn: [
  ]
}

resource Webappfirewallpolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-01-01' = {
  name: 'webFirewall'
  location: location
  properties: {
    customRules: [
      {
        name: 'CustRule01'
        priority: 100
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RemoteAddr'
              }
            ]
            operator: 'IPMatch'
            negationConditon: true
            matchValues: [
              '10.10.10.0/24'
            ]
          }
        ]
      }
    ]
    policySettings: {
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
      state: 'Enabled'
      mode: 'Prevention'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
        }
      ]
    }
  }
}


// Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2024-04-01-preview' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: true
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: aks.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// Azure Container Registry
resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
  }
}

// Grant AKS pull access to ACR
resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, aks.id, 'acrpull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
  scope: acr
}

// Private DNS Zone for ACR
resource acrPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
}

// Private Endpoint for ACR
resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${acrName}-pe'
  location: location
  properties: {
    subnet: {
      id: aksSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: '${acrName}-connection'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [
            'registry'
          ]
        }
      }
    ]
  }
}

// Private DNS Zone Group for ACR
resource acrPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-01-01' = {
  parent: acrPrivateEndpoint
  name: 'acrPrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config'
        properties: {
          privateDnsZoneId: acrPrivateDnsZone.id
        }
      }
    ]
  }
}

// Outputs
output aksName string = aks.name
output acrLoginServer string = acr.properties.loginServer
output keyVaultName string = keyVault.name
output vnetName string = vnet.name
output aksSubnetName string = aksSubnet.name
output wafSubnetName string = wafSubnet.name
output controlPlaneFQDN string = aks.properties.fqdn
