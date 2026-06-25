// - - - preconditions - - - 
// - - - - - - - - - - - - -
//All resources will be deployed in resource group "Bicep-fundermental-resourcegroup"
//location will be inherited from the resource group
// - - - - - - - - - - - - -
// - - - - - - - - - - - - -
// - - - Paremeters defination - - - 
@description('Parameter for location')
param location string = resourceGroup().location
// - - - Hub Virtual Network - - - 
@description('Parameters for Hub Virtual Network')
var vnetNameHub = 'poc-Hub-Vnet'
param ipAddressPrefixHub array = ['10.0.0.0/16']
// - - - Peerings - - -
var hubToSpokePeeringName = 'poc-hubtospokepeering'
var spokeToHubPeeringName = 'poc-spoketohubpeering'
// - - - Spoke Virtual Network - - - 
@description('Parameters for Spoke Virtual Network')
var vnetNameSpk = 'poc-Spk-Vnet-01'
param ipAddressPrefixSpk array = ['10.1.0.0/16']
var subnetName1Spk = 'poc-spk01-subnet01'
var subnetName2Spk = 'poc-spk01-subnet02'
param ipAddressPrefixSpk01Subnet01 string = '10.1.0.0/24'
param ipAddressPrefixSpk01Subnet02 string = '10.1.1.0/24'
// - - - Virtual Machine - - -
@description('Parameters for Virtual Machine1')
var vmSize = 'Standard_B2s'
var vmOSVersion = 'win11-22h2-ent'
var vmIndex = [0,1]
var vmName = ['poc-VM-01','poc-VM-02']
var vmComputerName = ['poc-vm-01','poc-vm-02']
param staticIPaddress array = ['10.1.0.10', '10.1.0.11']
@secure()
param adun string
@secure()
param adps string
// - - - Public IP(Bastion) - - -
@description('Parameters for Public IP(Bastion)')
var publicIpName = 'poc-Bastion-PublicIP'
var publicIpAllocationMethod = 'Static'
var publicIpAddressVersion = 'IPv4'
var publicIpSkuName = 'Standard'
var publicIpSkuTier = 'Regional'
// - - - Bastion - - -
@description('Parameters for Bastion')
var bastionSubnetName = 'AzureBastionSubnet'
param ipAddressPrefixBastionSubnet string = '10.0.0.0/26'
var bastionName = 'poc-Bastion-Hub'
// - - - Storage Account - - -
@description('Parameters for Storage Account')
var storageAccountName = 'poc${uniqueString(resourceGroup().id,deployment().name)}'
// - - - tags - - -
@description('Parameters for tags')
param tags object = {
  environment: 'poc'
  department: 'Infra'
  project: 'Bicep'
}
// - - - Log Analytics - - -
// @description('Parameters for Log Analytics')
// param logAnalyticsWorkspace string = 'poc-${uniqueString(resourceGroup().id,deployment().name,location)}'
/*
// - - - SQL Server - - -
@description('Parameters for SQL Server')
var sqlServerName = 'poc${uniqueString(resourceGroup().id,deployment().name)}'
var sqlDatabaseName = 'pocbicepsqldatabase'
@secure()
param sqlLoginId string
@secure()
param sqlLoginPassword string
// @description('Azure AD Administrator for SQL Server (must be different from sqlLoginId)')
//@secure()
//param aadAdminLogin string
*/

//-------
//-------
//------- Program starts here ------
//---------
// 1. Create a hub virtual network
resource hubVNet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetNameHub
  tags: tags
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ipAddressPrefixHub
    }
  }
}

//---------
// 2. Create a spoke virtual network
resource spokeVNet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetNameSpk
  tags: tags
  location: location
  dependsOn: [
    hubVNet
  ]
  properties: {
    addressSpace: {
      addressPrefixes: ipAddressPrefixSpk
    }
  }
}

//---------
// 3. Create a virtual network peering between the hub and spoke virtual networks
// 3-1.Create a virtual network peering from the hub virtual network to the spoke virtual network
resource hubToSpokePeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = {
  name:   hubToSpokePeeringName
  parent: hubVNet
  dependsOn: [
    subnetOfBastion
    subnetspk02
  ]
  properties: {
    remoteVirtualNetwork: {
      id: spokeVNet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

// 3-2.Create a virtual network peering from the spoke virtual network to the hub virtual network
resource spokeToHubPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-05-01' = {
  name:  spokeToHubPeeringName
  parent: spokeVNet
  dependsOn: [
    hubToSpokePeering
    subnetOfBastion
    subnetspk02
  ]
  properties: {
    remoteVirtualNetwork: {
      id: hubVNet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
    useRemoteGateways: false
  }
}

//---------
// 4. Create NSG and subnets
// 4-1. Create NSG first
resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'poc-NSG-${subnetName1Spk}'
  tags: tags
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

// 4-2. Create first subnet with NSG and second subnet
resource subnetspk01 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: subnetName1Spk
  parent: spokeVNet
  dependsOn: []
  properties: {
    addressPrefix: ipAddressPrefixSpk01Subnet01
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource subnetspk02 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: subnetName2Spk
  parent: spokeVNet
  dependsOn: [subnetspk01]
  properties: {
    addressPrefix: ipAddressPrefixSpk01Subnet02
  }
}

// 5. Create a virtual machine in the spoke virtual network
// 5-1. Create a storage account
resource diagstorageAccount 'Microsoft.Storage/storageAccounts@2026-04-01' = [for i in vmIndex:{
  name: '${storageAccountName}${i}'
  tags: tags
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}]

// 5-2. create network interfaces in the subnet (Loop for 3 times)
resource vmWindowsNic 'Microsoft.Network/networkInterfaces@2025-05-01' = [for i in vmIndex:{
  name: 'poc-NIC-${vmName[i]}'
  tags: tags
  location: location
  dependsOn: []
  properties: {
    ipConfigurations: [
      {
        name: 'poc-NIC-${vmComputerName[i]}'
        properties: {
          subnet: {
            id: subnetspk01.id
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: staticIPaddress[i]
        }
      } 
    ]
  }
}]

// 5-3. deploy virtual machines (Loop for 2 times)
resource createVM 'Microsoft.Compute/virtualMachines@2025-11-01' = [for i in vmIndex:{
  name: vmName[i]
  tags: tags
  location: location
  dependsOn: [
    vmWindowsNic[i]
  ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsDesktop'
        offer: 'Windows-11'
        sku: vmOSVersion
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: vmComputerName[i]
      adminUsername: adun
      adminPassword: adps
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmWindowsNic[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: diagstorageAccount[i].properties.primaryEndpoints.blob
      }
    }
  }
}]

/*-
//---------
// 6. create a SQL Server and a SQL Database
// 6-1. create a SQL Server
resource sqlServer 'Microsoft.Sql/servers@2025-01-01' = {
  name: sqlServerName
  tags: tags
  location: location
  properties: {
    administratorLogin: sqlLoginId
    administratorLoginPassword: sqlLoginPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// 6-2. create a SQL Database
resource sqlDatabase 'Microsoft.Sql/servers/databases@2025-01-01' = {
  name: sqlDatabaseName
  tags: tags
  location: location
  parent: sqlServer
  sku: {
    name: 'S0'
    tier: 'Standard'
    capacity: 10
  }
}
*/

//---------
// 6. create a bastion subnet in the hub virtual network
// 6-1. create a bastion subnet in the hub virtual network
resource subnetOfBastion 'Microsoft.Network/virtualNetworks/subnets@2025-05-01' = {
  name: bastionSubnetName
  parent: hubVNet
  properties: {
    addressPrefix: ipAddressPrefixBastionSubnet
  }
}

// 6-2. create a public IP address for the bastion host
resource publicIp 'Microsoft.Network/publicIPAddresses@2025-05-01' = {
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

// 6-3. create a bastion host in the bastion subnet
resource bastionHost 'Microsoft.Network/bastionHosts@2025-05-01' = {
  name: bastionName
  tags: tags
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: true
    enableIpConnect: false
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
//---EOF----
