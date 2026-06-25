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
var vmName = ['poc-VM-01','poc-VM-02','poc-VM-03']
var vmSize = 'Standard_B2s'
@secure()
param adun string = 'adminuser'
@secure()
param adps string = 'P@ssw0rd1234'

var vmComputerName = ['poc-vm-01','poc-vm-02','poc-vm-03']
var vmOSVersion = 'Windows-10-N-x64'
var vmIndex = [0,1,2]
param staticIPaddress array = ['10.1.0.10', '10.1.0.11', '10.1.0.12']
// - - - SQL Server - - -
@description('Parameters for SQL Server')
var sqlServerName = 'poc${uniqueString(resourceGroup().id,deployment().name)}'
var sqlDatabaseName = 'pocbicepsqldatabase'

@secure()
param sqlLoginId string = 'adminuser'
@secure()
param sqlLoginPassword string = 'Rduaain08180422'
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
// - - - Log Analytics - - -
// @description('Parameters for Log Analytics')
// param logAnalyticsWorkspace string = 'poc-${uniqueString(resourceGroup().id,deployment().name,location)}'
// - - - Tags - - -
@description('Parameters for tags')
param tags object = {
  environment: 'poc'
  department: 'Infra'
  project: 'Bicep'
}

// - - - Boolean for engaging deployment - - -
// - - - true: engage / false; not engage - - -
@description('Booleans for engaging deployment')
param ExistHubVnet bool = false
param ExistSpokeVnet bool = true
param ExistVnetPeering bool = true
param ExistNSG bool = true
param ExistVM bool = true
param ExistSQLServer bool = true
param ExistBastion bool = true
//-------
//-------
//------- Program starts here -------

// 1. Create a hub virtual network
module createHubVNet './modules/1.hub-vnet.bicep' = if (ExistHubVnet) {
  name: 'createHubVnet'
  params: {
    tags: tags
    location: location
    vnetName: vnetNameHub
    ipAddressPrefixes: ipAddressPrefixHub
  }
}

// 2. Create a spoke virtual network
module createSpokeVNet './modules/2.spoke-vnet.bicep' = if(ExistSpokeVnet) {
  name: 'createSpokeVnet'
  params: {
    tags: tags
    location: location
    vnetName: vnetNameSpk
    ipAddressPrefix: ipAddressPrefixSpk
    subnetName1: subnetName1Spk
    subnetName2: subnetName2Spk
    subnetPrefix1: ipAddressPrefixSpk01Subnet01
    subnetPrefix2: ipAddressPrefixSpk01Subnet02
  }
}

// 3. Create a virtual network peering between the hub and spoke virtual networks
module createVNetPeering './modules/3.vnetPeering.bicep' = if(ExistVnetPeering) {
  name: 'createVnetPeering'
  dependsOn: [
    createHubVNet
    createSpokeVNet
  ]
  params: {
    vnetNameHub: createHubVNet.outputs.ophubVnetName
    vnetNameSpk: createSpokeVNet.outputs.opSpkVnetName
    vnetHubVnetID:createHubVNet.outputs.ophubVnetId
    vnetSpkVnetID:createSpokeVNet.outputs.opSpkVnetId
    hubToSpokePeeringName: hubToSpokePeeringName
    spokeToHubPeeringName: spokeToHubPeeringName
  }
}

// 4. create a NSG and attach it to the subnet in the spoke virtual network
module createNSG './modules/4.nsg.bicep' = if(ExistNSG) {
  name : 'createNSG'
  dependsOn: [
    createSpokeVNet
  ]
  params: {
    tags: tags
    location: location
    nsgName: 'poc-nsg-${createSpokeVNet.outputs.opSpkSubnetName0}'
    spkvnetName: createSpokeVNet.outputs.opSpkVnetName
    spksubnetName: createSpokeVNet.outputs.opSpkSubnetName0
    spksubnetipaddress: createSpokeVNet.outputs.opSpkSubnetPrefix0
  }
}

// 5. create a virtual machine in the spoke virtual network
module createVM './modules/5.virtualMachine.bicep' = [for i in vmIndex: if(ExistVM) {
  name: 'create${vmName[i]}'
  dependsOn: [
    createSpokeVNet
  ]
  params: {
    tag: tags
    location: location
    vnetName: vnetNameSpk
    subnetName: subnetName1Spk
    vmName: vmName[i]
    vmSize: vmSize
    adminUsername: adun
    adminPassword: adps
    vmComputerName: vmComputerName[i]
    vmOSVersion: vmOSVersion
    staticIPaddress: staticIPaddress[i]
    storageAccountName: '${storageAccountName}${i}'
  }
}]

/*
// 6. create a SQL Server and a SQL Database
module createSQLServer './modules/6.sqlServer&Database.bicep' = if(ExistSQLServer) {
name: 'createSQLServer'
params: {
  tags: tags
  location: location
  sqlServerName: sqlServerName
  sqlDatabaseName: sqlDatabaseName
  sqlLoginId: sqlLoginId
  sqlLoginPassword:sqlLoginPassword
}
}
*/

// 7. create a bastion subnet in the hub virtual network
module createBastion './modules/6.bastion.bicep' = if(ExistBastion) {
  name: 'createBastion'
  dependsOn: [
    createHubVNet
    createSpokeVNet
    createVNetPeering
  ]
  params: {
    tags: tags
    location: location
    vnetName: createHubVNet.outputs.ophubVnetName
    subnetName: bastionSubnetName
    ipAddressPrefix:ipAddressPrefixBastionSubnet
    publicIpAllocationMethod: publicIpAllocationMethod
    publicIpAddressVersion: publicIpAddressVersion
    publicIpSkuName: publicIpSkuName
    publicIpSkuTier: publicIpSkuTier
    publicIpName: publicIpName
    bastionName: bastionName
  }
}

//---EOF----
