param location string = resourceGroup().location
param name string = 'grau-webpubsub'
@description('Tags for all resources')
param tags object = {}

resource webPubSub 'Microsoft.SignalRService/webPubSub@2024-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Free_F1'
    capacity: 1
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    
  }
  tags: tags
}

output webPubSubResourceId string = webPubSub.id
@secure()
output webPuSubConnectionString string = webPubSub.listKeys().primaryConnectionString
