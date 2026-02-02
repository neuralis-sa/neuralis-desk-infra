param name string
param location string = ''
param storageAccountName string = ''
param tags object = {}
param runtimeName string = 'node'
param runtimeVersion string = 'Node|20'
param keyVaultName string = ''
param authType string = 'system'

@secure()
param appSettings object = {}

// Consumption Plan (Serverless)
resource consumptionPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  sku: {
   name: 'Y1'  // Code de SKU pour le plan Consumption (Y1)
    //tier: 'Dynamic'
  }
  properties: {
    reserved: runtimeName == 'python' || runtimeName == 'node' ? true : false  // Nécessaire pour Linux
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${name}-loganalytics'
  location: location
  tags: tags
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

// Application Insights (facultatif mais recommandé)
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' =  {
  name: '${name}-appinsights'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id 
  }
}

// Function App
resource function 'Microsoft.Web/sites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  kind: runtimeName == 'python' || runtimeName == 'node' ? 'functionapp,linux' : 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: consumptionPlan.id
    siteConfig: {
      linuxFxVersion: runtimeVersion
      appSettings: concat([
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: 1
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(name)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: runtimeName
        }
        {
          name: 'APPINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: applicationInsights.properties.InstrumentationKey
        }
        // Ajouter d'autres paramètres d'application si nécessaire
      ],// Convert the appSettings object to an array of name-value pairs
      items(appSettings) == {} ? [] : map(items(appSettings), item => {
        name: item.key
        value: item.value
      }))
      //alwaysOn: true
      
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// resource waitFunctionDeploymentSection 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
//   kind: 'AzurePowerShell'
//   name: 'WaitFunctionDeploymentSection'
//   location: location
//   properties: {
//     azPowerShellVersion: '3.0'
//     scriptContent: 'start-sleep -Seconds 15'
//     cleanupPreference: 'Always'
//     retentionInterval: 'PT1H'
//   }
//   dependsOn: [
//     function
//   ]
// }


module functionaccess '../core/security/keyvault-rbac.bicep' = {
  name: 'keyvault-secrets-access'
  params: {
    keyVaultName: keyVaultName
    principalId: function.identity.principalId
    roleLevel: 'secrets-user'
    principalType: 'ServicePrincipal'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
}



output FUNCTION_IDENTITY_PRINCIPAL_ID string = function.identity.principalId
output functionName string = function.name
output functionId string = function.id
