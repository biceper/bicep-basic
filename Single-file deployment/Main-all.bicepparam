using './Main-all.bicep'

param ipAddressPrefixHub = [
  '10.0.0.0/16'
]
param ipAddressPrefixSpk = [
  '10.1.0.0/16'
]
param ipAddressPrefixSpk01Subnet01 = '10.1.0.0/24'
param ipAddressPrefixSpk01Subnet02 = '10.1.1.0/24'
param adun = 'adminuser'
param adps = 'P@ssw0rd1234'
param staticIPaddress = [
  '10.1.0.10'
  '10.1.0.11'
  '10.1.0.12'
]

/*
param sqlLoginId = 'adminuser'
param sqlLoginPassword = 'Rduaain08180422'
*/

param ipAddressPrefixBastionSubnet = '10.0.0.0/26'
param tags = {
  environment: 'poc'
  department: 'Infra'
  project: 'Bicep'
}

