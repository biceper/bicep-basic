param location string
param vnetName string
//---------
param subnetName string
param ipAddressPrefix string
//---------
param publicIpAllocationMethod string
param publicIpAddressVersion string
param publicIpSkuName string
param publicIpSkuTier string
param publicIpName string
//---------
param bastionName string
param tags object

//========= Get existing resources =========
resource hubVnet 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: vnetName
}

/*
resource bastionSubnetHubVnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: subnetName
  parent: hubVnet
}
*/

//========= Deploy resources =========
//create a bastion subnet in the Hub virtual network
resource subnetOfBastion 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: subnetName
//  dependsOn: [
//    hubVnet
//  ]
  parent:hubVnet
  properties: {
    addressPrefix: ipAddressPrefix
  }
}

// Create a public IP address for the bastion host
resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: publicIpName
  tags: tags
  location: location
  properties: {
    publicIPAllocationMethod: publicIpAllocationMethod
    publicIPAddressVersion: publicIpAddressVersion
  }
  sku: {
    name: publicIpSkuName
    tier: publicIpSkuTier
  }
}

//create a bastion host in the bastion subnet
resource bastionHost 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: bastionName
  tags: tags
  location: location
  dependsOn: [
    subnetOfBastion
    publicIp
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: false
    enableKerberos: false
    enableShareableLink: false
    enableTunneling: false
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: subnetOfBastion.id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output bastionName string = bastionHost.name
output bastionId string = bastionHost.id

