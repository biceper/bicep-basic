param location string
param sqlServerName string
param sqlDatabaseName string
//---------
@secure()
param sqlLoginId string
@secure()
param sqlLoginPassword string
//---------
param tags object


resource sqlServer 'Microsoft.Sql/servers@2022-05-01-preview' = {
  name: sqlServerName
  tags: tags
  location: location
  properties: {
    administratorLogin: sqlLoginId
    administratorLoginPassword: sqlLoginPassword
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  name: sqlDatabaseName
  tags: tags
  location: location
  parent: sqlServer
  dependsOn: [
    sqlServer
  ]
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}
