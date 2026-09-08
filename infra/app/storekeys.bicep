param keyVaultName string = ''
param storageAccountName string = ''
param azureOpenAIName string = ''
param rgName string = ''
param documentIntelligenceName string = ''
param speechServiceName string = ''
param openAIKeyName string = 'AZURE-OPENAI-API-KEY'
param storageAccountKeyName string = 'AZURE-STORAGE-ACCOUNT-KEY'
param documentIntelligenceKeyName string = 'AZURE-DOCUMENT-INTELLIGENCE-KEY'
param speechKeyName string = 'AZURE-SPEECH-KEY'
param transcriptionStorageKeyName string = 'AZURE-TRANSCRIPTION-STORAGE'


resource storageAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: storageAccountKeyName
  properties: {
    value: listKeys(resourceId(subscription().subscriptionId, rgName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-09-01').keys[0].value
  }
}

resource openAIKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: openAIKeyName
  properties: {
    value: listKeys(resourceId(subscription().subscriptionId, rgName, 'Microsoft.CognitiveServices/accounts', azureOpenAIName), '2023-05-01').key1
  }
}

resource documentIntelligenceKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: documentIntelligenceKeyName
  properties: {
    value: listKeys(resourceId(subscription().subscriptionId, rgName, 'Microsoft.CognitiveServices/accounts', documentIntelligenceName), '2023-05-01').key1
  }
}

resource speechKeySecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: speechKeyName
  properties: {
    value: listKeys(resourceId(subscription().subscriptionId, rgName, 'Microsoft.CognitiveServices/accounts', speechServiceName), '2023-05-01').key1
  }
}

// Azure Speech downloads the call audio over the public internet, so the app has
// to sign a read SAS for each staged blob — which needs the account key, not a
// managed identity. Hence a full connection string rather than an endpoint.
resource transcriptionStorageSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVault
  name: transcriptionStorageKeyName
  properties: {
    value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(resourceId(subscription().subscriptionId, rgName, 'Microsoft.Storage/storageAccounts', storageAccountName), '2021-09-01').keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
  }
}


resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

output OPENAI_KEY_NAME string = openAIKeySecret.name
output OPENAI_KEY_SECRET_URI string = openAIKeySecret.properties.secretUri
output DOCUMENT_INTELLIGENCE_KEY_NAME string = documentIntelligenceKeySecret.name
output DOCUMENT_INTELLIGENCE_KEY_SECRET_URI string = documentIntelligenceKeySecret.properties.secretUri
output SPEECH_KEY_NAME string = speechKeySecret.name
output SPEECH_KEY_SECRET_URI string = speechKeySecret.properties.secretUri
output TRANSCRIPTION_STORAGE_NAME string = transcriptionStorageSecret.name
output TRANSCRIPTION_STORAGE_SECRET_URI string = transcriptionStorageSecret.properties.secretUri
output STORAGE_ACCOUNT_KEY_NAME string = storageAccountKeySecret.name
